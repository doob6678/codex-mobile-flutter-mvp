using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed record CodexAppServerCall(string Method, object? Parameters);

public interface ICodexAppServerClient
{
    Task<JsonElement> CallAsync(string method, object? parameters, CancellationToken cancellationToken);
}

public sealed class CodexAppServerGateway
{
    private static readonly HashSet<string> AllowedMethods = new(StringComparer.Ordinal)
    {
        "initialize",
        "config/read",
        "account/read",
        "account/rateLimits/read",
        "thread/list",
        "thread/read",
        "thread/start",
        "thread/resume",
        "thread/turns/list",
        "thread/turns/items/list",
        "turn/start",
        "turn/steer",
        "turn/interrupt",
        "fs/readDirectory",
        "fs/readFile",
        "fs/getMetadata",
        "model/list",
        "collaborationMode/list",
        "item/commandExecution/requestApproval",
        "item/fileChange/requestApproval",
        "item/permissions/requestApproval",
        "item/tool/requestUserInput",
        "applyPatchApproval",
        "execCommandApproval",
        "serverRequest/resolved",
    };

    private static readonly Regex ApiKeyAssignment = new(@"OPENAI_API_KEY\s*=\s*\S+", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex SecretToken = new(@"sk-[A-Za-z0-9_\-]+", RegexOptions.Compiled);

    private readonly ICodexAppServerClient client;
    private readonly LocalCodexHistoryService localHistory;
    private readonly SyncStateService? sync;
    private readonly ProjectStore? projects;
    private readonly bool enforceProjectRoots;

    public CodexAppServerGateway(
        ICodexAppServerClient client,
        LocalCodexHistoryService? localHistory = null,
        SyncStateService? sync = null,
        ProjectStore? projects = null,
        bool enforceProjectRoots = false)
    {
        this.client = client;
        this.localHistory = localHistory ?? new LocalCodexHistoryService();
        this.sync = sync;
        this.projects = projects;
        this.enforceProjectRoots = enforceProjectRoots;
    }

    public IReadOnlyCollection<string> AllowedMethodNames => AllowedMethods;

    public Task<CodexAppServerStatus> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        var message = localHistory.IsAvailable
            ? "Windows Codex 本机历史可用；发送会由 Bridge 后台投递到 live app-server。"
            : "Windows Codex 本机历史暂不可用；发送仍会尝试启动 live app-server。";
        return Task.FromResult(new CodexAppServerStatus(localHistory.IsAvailable, message, DateTimeOffset.UtcNow));
    }

    public Task<CodexAppServerJsonResponse> ReadConfigAsync(CancellationToken cancellationToken = default)
    {
        return CallAsync("config/read", new Dictionary<string, object?>(), cancellationToken);
    }

    public Task<CodexAppServerJsonResponse> ReadAccountAsync(CancellationToken cancellationToken = default)
    {
        return CallAsync("account/read", new Dictionary<string, object?>(), cancellationToken);
    }

    public Task<CodexAppServerJsonResponse> ListThreadsAsync(CancellationToken cancellationToken = default)
    {
        return localHistory.IsAvailable
            ? Task.FromResult(new CodexAppServerJsonResponse("thread/list", localHistory.ListThreads()))
            : CallAsync("thread/list", new Dictionary<string, object?>(), cancellationToken);
    }

    public async Task<CodexAppServerJsonResponse> ReadThreadAsync(string threadId, CancellationToken cancellationToken = default)
    {
        var response = localHistory.IsAvailable
            ? new CodexAppServerJsonResponse("thread/read", localHistory.ReadThread(threadId))
            : await CallAsync(
                "thread/read",
                new Dictionary<string, object?>
                {
                    ["threadId"] = threadId,
                    ["includeTurns"] = true,
                },
                cancellationToken);
        return OverlayMobileUserMessages(response, threadId);
    }

    public Task<CodexAppServerJsonResponse> StartThreadAsync(StartCodexThreadRequest request, CancellationToken cancellationToken = default)
    {
        var workingDirectory = ResolveAuthorizedWorkingDirectory(request.WorkingDirectory);
        var parameters = new Dictionary<string, object?>
        {
            ["cwd"] = workingDirectory,
            ["input"] = CreateTextInput(request.Prompt),
            ["model"] = request.Model,
            ["approvalPolicy"] = request.ApprovalPolicy,
            ["sandbox"] = request.SandboxMode,
            ["experimentalRawEvents"] = false,
            ["persistExtendedHistory"] = true,
        };
        return CallAsync("thread/start", parameters, cancellationToken);
    }

    public async Task<CodexAppServerJsonResponse> StartTurnAsync(StartCodexTurnRequest request, CancellationToken cancellationToken = default)
    {
        var prompt = request.Prompt ?? "";
        Log($"turn request prepared threadId={request.ThreadId} promptChars={prompt.Length}");
        sync?.RecordEvent(
            "codex.turn.starting",
            request.ThreadId,
            new Dictionary<string, object?>
            {
                ["threadId"] = request.ThreadId,
                ["promptChars"] = prompt.Length,
                ["message"] = "Windows Codex 开始接收手机发送的消息",
            });
        var parameters = new Dictionary<string, object?>
        {
            ["threadId"] = request.ThreadId,
            ["input"] = CreateTextInput(prompt),
        };
        try
        {
            var response = await StartTurnWithResumeAsync(request.ThreadId, parameters, cancellationToken);
            sync?.RecordEvent(
                "codex.turn.dispatched",
                request.ThreadId,
                new Dictionary<string, object?>
                {
                    ["threadId"] = request.ThreadId,
                    ["message"] = "消息已投递到 Windows Codex，等待 app-server 通知和历史写入",
                });
            return response;
        }
        catch (Exception ex)
        {
            sync?.RecordEvent(
                "codex.turn.failed",
                request.ThreadId,
                new Dictionary<string, object?>
                {
                    ["threadId"] = request.ThreadId,
                    ["error"] = Redact(ex.Message),
                });
            throw;
        }
    }

    public static string? TryReadThreadId(JsonElement json)
    {
        if (json.TryGetProperty("threadId", out var direct) && direct.ValueKind == JsonValueKind.String)
        {
            return direct.GetString();
        }

        if (json.TryGetProperty("thread", out var thread)
            && thread.TryGetProperty("id", out var id)
            && id.ValueKind == JsonValueKind.String)
        {
            return id.GetString();
        }

        return null;
    }

    public async Task<CodexAppServerJsonResponse> CallAsync(string method, object? parameters, CancellationToken cancellationToken = default)
    {
        if (!AllowedMethods.Contains(method))
        {
            throw new InvalidOperationException($"Codex app-server method '{method}' is not exposed through the mobile bridge.");
        }

        Log($"calling {method}");
        var json = await client.CallAsync(method, parameters, cancellationToken);
        Log($"completed {method}");
        return new CodexAppServerJsonResponse(method, json);
    }

    private async Task<CodexAppServerJsonResponse> StartTurnWithResumeAsync(
        string threadId,
        Dictionary<string, object?> parameters,
        CancellationToken cancellationToken)
    {
        try
        {
            Log($"turn/start begin threadId={threadId}");
            return await CallAsync("turn/start", parameters, cancellationToken);
        }
        catch (Exception ex) when (LooksLikeUnloadedThread(ex))
        {
            Log($"turn/start needs resume threadId={threadId}: {Redact(ex.Message)}");
            sync?.RecordEvent(
                "codex.turn.resuming",
                threadId,
                new Dictionary<string, object?>
                {
                    ["threadId"] = threadId,
                    ["message"] = "历史线程未加载，Bridge 正在恢复 Windows Codex 线程",
                });
            await CallAsync(
                "thread/resume",
                new Dictionary<string, object?>
                {
                    ["threadId"] = threadId,
                    ["excludeTurns"] = false,
                    ["persistExtendedHistory"] = true,
                },
                cancellationToken);

            Log($"turn/start retry after resume threadId={threadId}");
            return await CallAsync("turn/start", parameters, cancellationToken);
        }
        catch (Exception ex) when (LooksLikeNotInitialized(ex))
        {
            Log($"turn/start needs initialize threadId={threadId}: {Redact(ex.Message)}");
            sync?.RecordEvent(
                "codex.appserver.initializing",
                threadId,
                new Dictionary<string, object?>
                {
                    ["threadId"] = threadId,
                    ["message"] = "app-server 未初始化，Bridge 正在初始化连接",
                });
            await CallAsync(
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

            Log($"turn/start retry after initialize threadId={threadId}");
            return await CallAsync("turn/start", parameters, cancellationToken);
        }
    }

    private static bool LooksLikeUnloadedThread(Exception ex)
    {
        var message = ex.Message.ToLowerInvariant();
        return message.Contains("not loaded", StringComparison.Ordinal)
            || message.Contains("not found", StringComparison.Ordinal)
            || message.Contains("unknown thread", StringComparison.Ordinal)
            || message.Contains("missing thread", StringComparison.Ordinal);
    }

    private static bool LooksLikeNotInitialized(Exception ex)
    {
        return ex.Message.Contains("not initialized", StringComparison.OrdinalIgnoreCase);
    }

    private static string Redact(string message)
    {
        var redacted = ApiKeyAssignment.Replace(message, "OPENAI_API_KEY=[REDACTED]");
        return SecretToken.Replace(redacted, "[REDACTED]");
    }

    private string ResolveAuthorizedWorkingDirectory(string workingDirectory)
    {
        var fullPath = Path.GetFullPath(string.IsNullOrWhiteSpace(workingDirectory) ? "." : workingDirectory);
        if (!enforceProjectRoots)
        {
            return fullPath;
        }

        if (projects is null)
        {
            throw new InvalidOperationException("Project store is required when Codex cwd enforcement is enabled.");
        }

        if (projects.ListProjects().Any(project => IsSameOrChildPath(fullPath, project.RootPath)))
        {
            return fullPath;
        }

        throw new UnauthorizedAccessException("Codex thread working directory is not inside an authorized project root.");
    }

    private static bool IsSameOrChildPath(string candidate, string rootPath)
    {
        var root = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var fullCandidate = Path.GetFullPath(candidate).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (string.Equals(fullCandidate, root, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return fullCandidate.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
    }

    private static object[] CreateTextInput(string prompt)
    {
        return
        [
            new Dictionary<string, object?>
            {
                ["type"] = "text",
                ["text"] = prompt,
                ["text_elements"] = Array.Empty<object>(),
            },
        ];
    }

    private CodexAppServerJsonResponse OverlayMobileUserMessages(CodexAppServerJsonResponse response, string threadId)
    {
        var overlays = sync?.ListMobileUserMessages(threadId);
        if (overlays is null || overlays.Count == 0)
        {
            return response;
        }

        var root = JsonNode.Parse(response.Json.GetRawText());
        if (root is null)
        {
            return response;
        }

        var thread = root["thread"] as JsonObject ?? root["json"]?["thread"] as JsonObject;
        if (thread is null)
        {
            return response;
        }

        var turns = thread["turns"] as JsonArray;
        if (turns is null)
        {
            turns = new JsonArray();
            thread["turns"] = turns;
        }

        if (turns.Count == 0 || turns[0] is not JsonObject firstTurn)
        {
            firstTurn = new JsonObject
            {
                ["id"] = $"turn_{threadId}",
                ["items"] = new JsonArray(),
                ["itemsView"] = "full",
                ["status"] = "idle",
                ["error"] = null,
            };
            turns.Add(firstTurn);
        }

        var items = firstTurn["items"] as JsonArray;
        if (items is null)
        {
            items = new JsonArray();
            firstTurn["items"] = items;
        }

        var seen = items
            .OfType<JsonObject>()
            .Select(MessageKey)
            .Where(key => !string.IsNullOrWhiteSpace(key))
            .ToHashSet(StringComparer.Ordinal);

        foreach (var overlay in overlays)
        {
            var key = $"user\n{overlay.Text.Trim()}";
            if (!seen.Add(key))
            {
                continue;
            }

            items.Add(new JsonObject
            {
                ["type"] = "userMessage",
                ["id"] = overlay.Id,
                ["source"] = overlay.Source,
                ["createdAt"] = overlay.CreatedAt,
                ["content"] = new JsonArray
                {
                    new JsonObject
                    {
                        ["type"] = "text",
                        ["text"] = overlay.Text,
                        ["text_elements"] = new JsonArray(),
                    },
                },
            });
        }

        return new CodexAppServerJsonResponse(
            response.Method,
            JsonSerializer.SerializeToElement(root, new JsonSerializerOptions(JsonSerializerDefaults.Web)));
    }

    private static string MessageKey(JsonObject item)
    {
        var type = item["type"]?.GetValue<string>() ?? "";
        if (string.Equals(type, "userMessage", StringComparison.OrdinalIgnoreCase))
        {
            var content = item["content"] as JsonArray;
            var text = content is null
                ? ""
                : string.Join(
                    "\n",
                    content.OfType<JsonObject>()
                        .Select(part => part["text"]?.GetValue<string>() ?? "")
                        .Where(part => !string.IsNullOrWhiteSpace(part)));
            return $"user\n{text.Trim()}";
        }

        if (string.Equals(type, "agentMessage", StringComparison.OrdinalIgnoreCase))
        {
            return $"assistant\n{(item["text"]?.GetValue<string>() ?? "").Trim()}";
        }

        var role = item["role"]?.GetValue<string>() ?? "";
        var fallbackText = item["text"]?.GetValue<string>()
            ?? item["message"]?.GetValue<string>()
            ?? item["content"]?.ToString()
            ?? "";
        return string.IsNullOrWhiteSpace(role)
            ? ""
            : $"{role.Trim().ToLowerInvariant()}\n{fallbackText.Trim()}";
    }

    private static void Log(string message)
    {
        Console.WriteLine($"[{DateTimeOffset.Now:O}] [codex-gateway] {message}");
    }
}
