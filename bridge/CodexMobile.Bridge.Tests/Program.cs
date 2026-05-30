using CodexMobile.Bridge.Models;
using CodexMobile.Bridge.Services;
using System.Text.Json;
using System.Text;

var tests = new BridgeServiceTests();
var cases = new (string Name, Action Test)[]
{
    ("project whitelist canonicalizes roots and rejects path escape", tests.ProjectWhitelistRejectsPathEscape),
    ("file service reads text and hashes content", tests.FileServiceReadsAndHashesText),
    ("file patch rejects stale hashes and applies matching content", tests.FilePatchUsesExpectedHash),
    ("pairing token expires and cannot be reused", tests.PairingTokenExpiresAndCannotBeReused),
    ("command service rejects commands outside allowlist", tests.CommandServiceRejectsUnsafeCommands),
    ("audit log redacts secret values", tests.AuditLogRedactsSecrets),
    ("conversation service stores messages and approvals", tests.ConversationServiceStoresMessagesAndApprovals),
    ("protocol summary detects generated codex schema assets", tests.ProtocolSummaryDetectsGeneratedAssets),
    ("codex app-server gateway only allows mobile-safe methods", tests.CodexGatewayRejectsUnsafeMethods),
    ("codex app-server gateway maps config account and thread calls", tests.CodexGatewayMapsCoreCalls),
    ("codex app-server gateway reports unavailable status safely", tests.CodexGatewayReportsUnavailableStatusSafely),
    ("device token store validates expiry and revocation", tests.DeviceTokenStoreValidatesExpiryAndRevocation),
};

var failures = new List<string>();
foreach (var test in cases)
{
    try
    {
        test.Test();
        Console.WriteLine($"PASS {test.Name}");
    }
    catch (Exception ex)
    {
        failures.Add($"{test.Name}: {ex.Message}");
        Console.WriteLine($"FAIL {test.Name}: {ex.Message}");
    }
}

if (failures.Count > 0)
{
    Console.WriteLine();
    Console.WriteLine($"{failures.Count} test(s) failed.");
    foreach (var failure in failures)
    {
        Console.WriteLine(failure);
    }

    return 1;
}

Console.WriteLine();
Console.WriteLine($"All {cases.Length} bridge service tests passed.");
return 0;

internal sealed class BridgeServiceTests
{
    public void ProjectWhitelistRejectsPathEscape()
    {
        using var workspace = new TempWorkspace();
        var root = workspace.CreateDirectory("project");
        var outside = workspace.CreateDirectory("outside");
        File.WriteAllText(Path.Combine(outside, "secret.txt"), "hidden");

        var store = new ProjectStore();
        var project = store.AddProject("demo", root);

        var safePath = store.ResolveProjectPath(project.Id, ".");
        AssertEqual(root, safePath, "project root should canonicalize");

        AssertThrows<UnauthorizedAccessException>(
            () => store.ResolveProjectPath(project.Id, "..\\outside\\secret.txt"),
            "path escape must be rejected");
    }

    public void FileServiceReadsAndHashesText()
    {
        using var workspace = new TempWorkspace();
        var root = workspace.CreateDirectory("project");
        File.WriteAllText(Path.Combine(root, "notes.md"), "# hello", Encoding.UTF8);

        var store = new ProjectStore();
        var project = store.AddProject("demo", root);
        var files = new FileWorkspaceService(store);

        var read = files.ReadText(project.Id, "notes.md");
        AssertEqual("# hello", read.Content, "text content");
        AssertTrue(read.Hash.Length == 64, "sha256 hash length");
        AssertTrue(files.List(project.Id, ".").Any(file => file.Name == "notes.md"), "list includes file");
    }

    public void FilePatchUsesExpectedHash()
    {
        using var workspace = new TempWorkspace();
        var root = workspace.CreateDirectory("project");
        var path = Path.Combine(root, "notes.md");
        File.WriteAllText(path, "old", Encoding.UTF8);

        var store = new ProjectStore();
        var project = store.AddProject("demo", root);
        var files = new FileWorkspaceService(store);
        var hash = files.Hash(project.Id, "notes.md").Hash;

        AssertThrows<InvalidOperationException>(
            () => files.ApplyPatch(new FilePatchRequest(project.Id, "notes.md", "bad-hash", "new")),
            "stale hash should fail");

        var result = files.ApplyPatch(new FilePatchRequest(project.Id, "notes.md", hash, "new"));
        AssertTrue(result.Applied, "patch applied");
        AssertEqual("new", File.ReadAllText(path, Encoding.UTF8), "replacement text");
    }

    public void PairingTokenExpiresAndCannotBeReused()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 5, 31, 8, 0, 0, TimeSpan.Zero));
        var tokenStore = new DeviceTokenStore(clock);
        var service = new PairingService(clock, tokenStore);
        var challenge = service.Start(TimeSpan.FromSeconds(5));

        clock.Advance(TimeSpan.FromSeconds(6));
        AssertThrows<InvalidOperationException>(
            () => service.Complete(challenge.Code),
            "expired challenge should fail");

        var fresh = service.Start(TimeSpan.FromMinutes(1));
        var token = service.Complete(fresh.Code);
        AssertTrue(token.AccessToken.Length >= 32, "access token length");
        AssertTrue(tokenStore.Validate(token.AccessToken), "token store validates issued token");
        AssertThrows<InvalidOperationException>(
            () => service.Complete(fresh.Code),
            "challenge cannot be reused");
    }

    public void CommandServiceRejectsUnsafeCommands()
    {
        var audit = new AuditLog(new ManualClock(DateTimeOffset.UtcNow));
        var service = new CommandService(audit);

        var safe = service.Preview(new CommandRequest("git status", Environment.CurrentDirectory));
        AssertEqual(RiskLevel.ReadOnly, safe.RiskLevel, "git status risk");

        AssertThrows<InvalidOperationException>(
            () => service.Preview(new CommandRequest("Remove-Item -Recurse C:\\temp", Environment.CurrentDirectory)),
            "unsafe command should be rejected");
    }

    public void AuditLogRedactsSecrets()
    {
        var audit = new AuditLog(new ManualClock(DateTimeOffset.UtcNow));
        audit.Record("command", "OPENAI_API_KEY=sk-test-123 OPENAI_BASE_URL=https://example.test");

        var line = audit.List().Single().Message;
        AssertFalse(line.Contains("sk-test-123", StringComparison.Ordinal), "secret value redacted");
        AssertTrue(line.Contains("OPENAI_API_KEY=[REDACTED]", StringComparison.Ordinal), "redaction marker");
    }

    public void ConversationServiceStoresMessagesAndApprovals()
    {
        var clock = new ManualClock(DateTimeOffset.UtcNow);
        var service = new ConversationService(clock);
        var conversation = service.Create("demo", "project-1", "C:\\repo");

        var message = service.AddMessage(conversation.Id, "user", "run tests");
        var approval = service.RequestApproval(conversation.Id, ApprovalKind.Command, "dotnet test");
        service.ResolveApproval(approval.Id, ApprovalDecision.Approved);

        var snapshot = service.Get(conversation.Id);
        AssertEqual(message.Content, snapshot.Messages.Single().Content, "message stored");
        AssertEqual(ApprovalDecision.Approved, snapshot.Approvals.Single().Decision, "approval resolved");
    }

    public void ProtocolSummaryDetectsGeneratedAssets()
    {
        var root = FindRepositoryRoot();
        var summary = new ProtocolAssetService(root).ReadSummary();

        AssertTrue(summary.SchemaAssets.Any(path => path.EndsWith("codex_app_server_protocol.v2.schemas.json", StringComparison.Ordinal)), "schema asset detected");
        AssertTrue(summary.TypeScriptAssets.Any(path => path.EndsWith("ClientRequest.ts", StringComparison.Ordinal)), "client request asset detected");
        AssertTrue(summary.SupportedMethods.Contains("thread/start"), "thread/start mapped");
        AssertTrue(summary.SupportedMethods.Contains("fs/readFile"), "fs/readFile mapped");
    }

    public void CodexGatewayRejectsUnsafeMethods()
    {
        var client = new FakeCodexAppServerClient();
        var gateway = new CodexAppServerGateway(client);

        AssertThrows<InvalidOperationException>(
            () => gateway.CallAsync("fs/writeFile", new Dictionary<string, object?>()).GetAwaiter().GetResult(),
            "unsafe app-server method should be rejected");
    }

    public void CodexGatewayMapsCoreCalls()
    {
        var client = new FakeCodexAppServerClient();
        client.Enqueue("config/read", new Dictionary<string, object?> { ["model"] = "gpt-5.5" });
        client.Enqueue("account/read", new Dictionary<string, object?> { ["authMode"] = "chatgpt" });
        client.Enqueue("thread/list", new Dictionary<string, object?> { ["items"] = Array.Empty<object>() });
        var gateway = new CodexAppServerGateway(client);

        var config = gateway.ReadConfigAsync().GetAwaiter().GetResult();
        var account = gateway.ReadAccountAsync().GetAwaiter().GetResult();
        var threads = gateway.ListThreadsAsync().GetAwaiter().GetResult();

        AssertEqual("config/read", client.Calls[0].Method, "config method");
        AssertEqual("account/read", client.Calls[1].Method, "account method");
        AssertEqual("thread/list", client.Calls[2].Method, "thread list method");
        AssertTrue(config.Json.GetProperty("model").GetString() == "gpt-5.5", "config payload preserved");
        AssertTrue(account.Json.GetProperty("authMode").GetString() == "chatgpt", "account payload preserved");
        AssertTrue(threads.Json.TryGetProperty("items", out _), "thread payload preserved");
    }

    public void CodexGatewayReportsUnavailableStatusSafely()
    {
        var client = new FakeCodexAppServerClient { Failure = new InvalidOperationException("OPENAI_API_KEY=sk-secret crashed") };
        var gateway = new CodexAppServerGateway(client);

        var status = gateway.GetStatusAsync().GetAwaiter().GetResult();

        AssertFalse(status.Available, "status unavailable");
        AssertTrue(status.Message.Contains("[REDACTED]", StringComparison.Ordinal), "secret redacted");
        AssertFalse(status.Message.Contains("sk-secret", StringComparison.Ordinal), "secret removed");
    }

    public void DeviceTokenStoreValidatesExpiryAndRevocation()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 5, 31, 9, 0, 0, TimeSpan.Zero));
        var store = new DeviceTokenStore(clock);
        var token = store.Issue("phone", TimeSpan.FromMinutes(5));

        AssertTrue(store.Validate(token.AccessToken), "fresh token validates");
        clock.Advance(TimeSpan.FromMinutes(6));
        AssertFalse(store.Validate(token.AccessToken), "expired token rejected");

        var revoked = store.Issue("tablet", TimeSpan.FromMinutes(5));
        store.Revoke(revoked.AccessToken);
        AssertFalse(store.Validate(revoked.AccessToken), "revoked token rejected");
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "generated")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new DirectoryNotFoundException("generated directory was not found above test output");
    }

    private static void AssertTrue(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
    }

    private static void AssertFalse(bool condition, string message) => AssertTrue(!condition, message);

    private static void AssertEqual<T>(T expected, T actual, string message)
    {
        if (!EqualityComparer<T>.Default.Equals(expected, actual))
        {
            throw new InvalidOperationException($"{message}: expected '{expected}', got '{actual}'");
        }
    }

    private static void AssertThrows<TException>(Action action, string message)
        where TException : Exception
    {
        try
        {
            action();
        }
        catch (TException)
        {
            return;
        }

        throw new InvalidOperationException(message);
    }
}

internal sealed class FakeCodexAppServerClient : ICodexAppServerClient
{
    private readonly Queue<(string Method, object? Response)> responses = new();

    public List<CodexAppServerCall> Calls { get; } = new();

    public Exception? Failure { get; set; }

    public void Enqueue(string method, object? response)
    {
        responses.Enqueue((method, response));
    }

    public Task<JsonElement> CallAsync(string method, object? parameters, CancellationToken cancellationToken)
    {
        Calls.Add(new CodexAppServerCall(method, parameters));
        if (Failure is not null)
        {
            throw Failure;
        }

        if (responses.Count == 0)
        {
            return Task.FromResult(JsonSerializer.SerializeToElement(new Dictionary<string, object?>()));
        }

        var response = responses.Dequeue();
        if (!string.Equals(response.Method, method, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Expected {response.Method}, got {method}");
        }

        return Task.FromResult(JsonSerializer.SerializeToElement(response.Response));
    }
}

internal sealed class TempWorkspace : IDisposable
{
    private readonly string root = Path.Combine(Path.GetTempPath(), "codex-mobile-bridge-tests", Guid.NewGuid().ToString("N"));

    public string CreateDirectory(string name)
    {
        var path = Path.Combine(root, name);
        Directory.CreateDirectory(path);
        return Path.GetFullPath(path);
    }

    public void Dispose()
    {
        if (Directory.Exists(root))
        {
            Directory.Delete(root, recursive: true);
        }
    }
}
