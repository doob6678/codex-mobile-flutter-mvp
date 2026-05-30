using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace CodexMobile.Bridge.Services;

public sealed class StdioCodexAppServerClient : ICodexAppServerClient
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly string executable;
    private int nextId;

    public StdioCodexAppServerClient(IConfiguration configuration)
    {
        executable = configuration["CodexAppServer:Executable"] ?? "codex";
    }

    public async Task<JsonElement> CallAsync(string method, object? parameters, CancellationToken cancellationToken)
    {
        var id = Interlocked.Increment(ref nextId);
        var request = new Dictionary<string, object?>
        {
            ["jsonrpc"] = "2.0",
            ["id"] = id,
            ["method"] = method,
            ["params"] = parameters,
        };

        var startInfo = new ProcessStartInfo(executable, "app-server --listen stdio://")
        {
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardInputEncoding = Encoding.UTF8,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to start codex app-server.");
        await process.StandardInput.WriteLineAsync(JsonSerializer.Serialize(request, JsonOptions));
        await process.StandardInput.FlushAsync(cancellationToken);

        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeout.Token);
        var line = await process.StandardOutput.ReadLineAsync(linked.Token);
        if (string.IsNullOrWhiteSpace(line))
        {
            var stderr = await process.StandardError.ReadToEndAsync(linked.Token);
            throw new InvalidOperationException($"codex app-server returned no JSON-RPC response. {stderr}");
        }

        using var document = JsonDocument.Parse(line);
        var root = document.RootElement;
        if (root.TryGetProperty("error", out var error))
        {
            throw new InvalidOperationException(error.ToString());
        }

        if (root.TryGetProperty("result", out var result))
        {
            return result.Clone();
        }

        return root.Clone();
    }
}
