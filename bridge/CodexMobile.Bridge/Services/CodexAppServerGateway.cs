using System.Text.Json;
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

    public CodexAppServerGateway(ICodexAppServerClient client)
    {
        this.client = client;
    }

    public IReadOnlyCollection<string> AllowedMethodNames => AllowedMethods;

    public async Task<CodexAppServerStatus> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            await client.CallAsync("config/read", new Dictionary<string, object?>(), cancellationToken);
            return new CodexAppServerStatus(true, "codex app-server reachable", DateTimeOffset.UtcNow);
        }
        catch (Exception ex)
        {
            return new CodexAppServerStatus(false, Redact(ex.Message), DateTimeOffset.UtcNow);
        }
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
        return CallAsync("thread/list", new Dictionary<string, object?>(), cancellationToken);
    }

    public Task<CodexAppServerJsonResponse> ReadThreadAsync(string threadId, CancellationToken cancellationToken = default)
    {
        return CallAsync("thread/read", new Dictionary<string, object?> { ["threadId"] = threadId }, cancellationToken);
    }

    public Task<CodexAppServerJsonResponse> StartThreadAsync(StartCodexThreadRequest request, CancellationToken cancellationToken = default)
    {
        var parameters = new Dictionary<string, object?>
        {
            ["cwd"] = request.WorkingDirectory,
            ["prompt"] = request.Prompt,
            ["model"] = request.Model,
            ["approvalPolicy"] = request.ApprovalPolicy,
            ["sandboxMode"] = request.SandboxMode,
        };
        return CallAsync("thread/start", parameters, cancellationToken);
    }

    public Task<CodexAppServerJsonResponse> StartTurnAsync(StartCodexTurnRequest request, CancellationToken cancellationToken = default)
    {
        var parameters = new Dictionary<string, object?>
        {
            ["threadId"] = request.ThreadId,
            ["prompt"] = request.Prompt,
        };
        return CallAsync("turn/start", parameters, cancellationToken);
    }

    public async Task<CodexAppServerJsonResponse> CallAsync(string method, object? parameters, CancellationToken cancellationToken = default)
    {
        if (!AllowedMethods.Contains(method))
        {
            throw new InvalidOperationException($"Codex app-server method '{method}' is not exposed through the mobile bridge.");
        }

        var json = await client.CallAsync(method, parameters, cancellationToken);
        return new CodexAppServerJsonResponse(method, json);
    }

    private static string Redact(string message)
    {
        var redacted = ApiKeyAssignment.Replace(message, "OPENAI_API_KEY=[REDACTED]");
        return SecretToken.Replace(redacted, "[REDACTED]");
    }
}
