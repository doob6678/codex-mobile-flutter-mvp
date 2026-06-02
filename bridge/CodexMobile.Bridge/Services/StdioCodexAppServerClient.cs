using System.Diagnostics;
using System.Collections.Concurrent;
using System.Text;
using System.Text.Json;

namespace CodexMobile.Bridge.Services;

public sealed class StdioCodexAppServerClient : ICodexAppServerClient, IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly TimeSpan RpcTimeout = TimeSpan.FromSeconds(90);
    private static readonly Encoding Utf8NoBom = new UTF8Encoding(encoderShouldEmitUTF8Identifier: false);
    private readonly string executable;
    private readonly SyncStateService? sync;
    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly StringBuilder stderr = new();
    private readonly ConcurrentDictionary<int, TaskCompletionSource<JsonElement>> pendingResponses = new();
    private Process? process;
    private CancellationTokenSource? readerCancellation;
    private Task? readerTask;
    private int nextId;
    private bool initialized;
    private string? activeThreadId;

    public StdioCodexAppServerClient(IConfiguration configuration, SyncStateService? sync = null)
    {
        executable = configuration["CodexAppServer:Executable"] ?? "codex";
        this.sync = sync;
    }

    public async Task<JsonElement> CallAsync(string method, object? parameters, CancellationToken cancellationToken)
    {
        await gate.WaitAsync(cancellationToken);
        try
        {
            var activeProcess = EnsureProcess();

            if (!initialized && !string.Equals(method, "initialize", StringComparison.Ordinal))
            {
                Log($"auto-initialize before {method}");
                await InitializeLockedAsync(activeProcess, cancellationToken);
            }

            if (string.Equals(method, "turn/start", StringComparison.Ordinal))
            {
                var threadId = CodexNotificationMapper.ReadThreadId(parameters);
                if (!string.IsNullOrWhiteSpace(threadId))
                {
                    activeThreadId = threadId;
                }
            }

            var result = await SendRequestLockedAsync(activeProcess, method, parameters, cancellationToken);
            if (string.Equals(method, "initialize", StringComparison.Ordinal))
            {
                await SendNotificationLockedAsync(activeProcess, "initialized", new Dictionary<string, object?>(), cancellationToken);
                initialized = true;
            }

            return result;
        }
        finally
        {
            gate.Release();
        }
    }

    public void Dispose()
    {
        ResetProcess();
        gate.Dispose();
    }

    private Process EnsureProcess()
    {
        if (process is { HasExited: false } active)
        {
            return active;
        }

        ResetProcess();
        stderr.Clear();
        Log($"starting '{executable} app-server --listen stdio://'");
        var startInfo = new ProcessStartInfo(executable, "app-server --listen stdio://")
        {
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardInputEncoding = Utf8NoBom,
            StandardOutputEncoding = Utf8NoBom,
            StandardErrorEncoding = Utf8NoBom,
        };

        process = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to start codex app-server.");
        process.ErrorDataReceived += (_, args) =>
        {
            if (!string.IsNullOrWhiteSpace(args.Data))
            {
                stderr.AppendLine(args.Data);
            }
        };
        process.BeginErrorReadLine();
        Log($"started app-server pid={process.Id}");
        readerCancellation = new CancellationTokenSource();
        readerTask = Task.Run(() => ReadStdoutLoopAsync(process, readerCancellation.Token));
        return process;
    }

    private async Task InitializeLockedAsync(Process activeProcess, CancellationToken cancellationToken)
    {
        Log("initialize begin");
        await SendRequestLockedAsync(
            activeProcess,
            "initialize",
            new Dictionary<string, object?>
            {
                ["clientInfo"] = new Dictionary<string, object?>
                {
                    ["name"] = "codex-mobile-bridge",
                    ["title"] = "Codex Mobile Bridge",
                    ["version"] = "0.1.0",
                },
                ["capabilities"] = new Dictionary<string, object?>
                {
                    ["experimentalApi"] = true,
                    ["requestAttestation"] = false,
                    ["optOutNotificationMethods"] = Array.Empty<string>(),
                },
            },
            cancellationToken);
        Log("initialize response received; sending initialized notification");
        await SendNotificationLockedAsync(activeProcess, "initialized", new Dictionary<string, object?>(), cancellationToken);
        initialized = true;
        Log("initialize complete");
    }

    private async Task<JsonElement> SendRequestLockedAsync(
        Process activeProcess,
        string method,
        object? parameters,
        CancellationToken cancellationToken)
    {
        var id = Interlocked.Increment(ref nextId);
        Log($"request #{id} {method} sending");
        var request = new Dictionary<string, object?>
        {
            ["jsonrpc"] = "2.0",
            ["id"] = id,
            ["method"] = method,
            ["params"] = parameters,
        };

        var response = new TaskCompletionSource<JsonElement>(TaskCreationOptions.RunContinuationsAsynchronously);
        pendingResponses[id] = response;

        try
        {
            await activeProcess.StandardInput.WriteLineAsync(JsonSerializer.Serialize(request, JsonOptions));
            await activeProcess.StandardInput.FlushAsync(cancellationToken);
        }
        catch
        {
            Log($"request #{id} {method} write failed; resetting app-server");
            pendingResponses.TryRemove(id, out _);
            ResetProcess();
            throw;
        }

        using var timeout = new CancellationTokenSource(RpcTimeout);
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeout.Token);
        try
        {
            var result = await response.Task.WaitAsync(linked.Token);
            Log($"request #{id} {method} response received");
            return result;
        }
        catch (OperationCanceledException) when (!timeout.IsCancellationRequested)
        {
            Log($"request #{id} {method} cancelled; resetting app-server");
            pendingResponses.TryRemove(id, out _);
            ResetProcess();
            throw;
        }
        catch (OperationCanceledException) when (timeout.IsCancellationRequested)
        {
            Log($"request #{id} {method} timed out after {RpcTimeout.TotalSeconds:0}s; resetting app-server");
            pendingResponses.TryRemove(id, out _);
            ResetProcess();
            throw new InvalidOperationException($"codex app-server timed out waiting for '{method}'. {ReadStderr()}");
        }
    }

    private async Task ReadStdoutLoopAsync(Process activeProcess, CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var line = await activeProcess.StandardOutput.ReadLineAsync(cancellationToken);
                if (line is null)
                {
                    Log("stdout closed");
                    CompletePendingResponses(new InvalidOperationException($"codex app-server stdout closed. {ReadStderr()}"));
                    return;
                }

                if (string.IsNullOrWhiteSpace(line))
                {
                    continue;
                }

                RouteStdoutMessage(line);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception ex)
        {
            Log($"stdout reader failed: {ex.Message}");
            CompletePendingResponses(new InvalidOperationException($"codex app-server stdout reader failed. {ReadStderr()}", ex));
        }
    }

    private void RouteStdoutMessage(string line)
    {
        JsonElement root;
        try
        {
            using var document = JsonDocument.Parse(line);
            root = document.RootElement.Clone();
        }
        catch (JsonException ex)
        {
            stderr.AppendLine($"Non-JSON stdout from codex app-server: {ex.Message}");
            Log($"stdout non-json ignored: {ex.Message}");
            return;
        }

        if (!TryReadResponseId(root, out var id))
        {
            LogNotification(root);
            RecordNotification(root);
            return;
        }

        if (!pendingResponses.TryRemove(id, out var response))
        {
            Log($"response #{id} ignored because no pending request exists");
            return;
        }

        if (root.TryGetProperty("error", out var error))
        {
            Log($"response #{id} error: {error}");
            response.TrySetException(new InvalidOperationException(error.ToString()));
            return;
        }

        if (root.TryGetProperty("result", out var result))
        {
            response.TrySetResult(result.Clone());
            return;
        }

        response.TrySetResult(root.Clone());
    }

    private void RecordNotification(JsonElement root)
    {
        if (!root.TryGetProperty("method", out var methodElement))
        {
            return;
        }

        var method = methodElement.GetString() ?? "notification";
        var mapped = CodexNotificationMapper.Map(root, activeThreadId);
        sync?.RecordEvent(
            "codex.appserver.notification",
            mapped.EntityId,
            mapped.Payload);
        if (mapped.ClearsActiveThread)
        {
            activeThreadId = null;
        }
    }

    private static void LogNotification(JsonElement root)
    {
        if (!root.TryGetProperty("method", out var methodElement))
        {
            return;
        }

        var method = methodElement.GetString() ?? "";
        if (method.Contains("delta", StringComparison.OrdinalIgnoreCase))
        {
            if (method.Contains("agentMessage", StringComparison.OrdinalIgnoreCase))
            {
                Log($"notification {method}");
            }

            return;
        }

        Log($"notification {method}");
    }

    private static bool TryReadResponseId(JsonElement root, out int id)
    {
        id = 0;
        return root.TryGetProperty("id", out var responseId)
            && responseId.ValueKind == JsonValueKind.Number
            && responseId.TryGetInt32(out id);
    }

    private static async Task SendNotificationLockedAsync(
        Process activeProcess,
        string method,
        object? parameters,
        CancellationToken cancellationToken)
    {
        var notification = new Dictionary<string, object?>
        {
            ["jsonrpc"] = "2.0",
            ["method"] = method,
            ["params"] = parameters,
        };

        await activeProcess.StandardInput.WriteLineAsync(JsonSerializer.Serialize(notification, JsonOptions));
        await activeProcess.StandardInput.FlushAsync(cancellationToken);
    }

    private void ResetProcess()
    {
        var oldProcess = process;
        var oldReaderCancellation = readerCancellation;
        if (oldProcess is not null)
        {
            Log($"resetting app-server pid={oldProcess.Id} exited={oldProcess.HasExited}");
        }
        process = null;
        readerCancellation = null;
        readerTask = null;
        initialized = false;
        activeThreadId = null;
        oldReaderCancellation?.Cancel();
        CompletePendingResponses(new InvalidOperationException($"codex app-server process was reset. {ReadStderr()}"));
        if (oldProcess is null)
        {
            oldReaderCancellation?.Dispose();
            return;
        }

        try
        {
            if (!oldProcess.HasExited)
            {
                oldProcess.Kill(entireProcessTree: true);
                Log($"killed app-server pid={oldProcess.Id}");
            }
        }
        catch
        {
        }
        finally
        {
            oldProcess.Dispose();
            oldReaderCancellation?.Dispose();
        }
    }

    private void CompletePendingResponses(Exception exception)
    {
        foreach (var pending in pendingResponses)
        {
            if (pendingResponses.TryRemove(pending.Key, out var response))
            {
                response.TrySetException(exception);
            }
        }
    }

    private string ReadStderr()
    {
        var value = stderr.ToString().Trim();
        return string.IsNullOrWhiteSpace(value) ? "stderr was empty." : value;
    }

    private static void Log(string message)
    {
        Console.WriteLine($"[{DateTimeOffset.Now:O}] [codex-stdio] {message}");
    }
}
