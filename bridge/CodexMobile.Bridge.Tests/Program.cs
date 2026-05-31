using CodexMobile.Bridge.Models;
using CodexMobile.Bridge.Services;
using System.Text.Json;
using System.Text;
using System.Net;

var tests = new BridgeServiceTests();
var cases = new (string Name, Action Test)[]
{
    ("project whitelist canonicalizes roots and rejects path escape", tests.ProjectWhitelistRejectsPathEscape),
    ("file service reads text and hashes content", tests.FileServiceReadsAndHashesText),
    ("file service marks markdown files for mobile reading", tests.FileServiceMarksMarkdownFilesForMobileReading),
    ("project store loads default knowledge projects from environment format", tests.ProjectStoreLoadsDefaultKnowledgeProjectsFromEnvironmentFormat),
    ("project store loads trusted Codex projects from config", tests.ProjectStoreLoadsTrustedCodexProjectsFromConfig),
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
    ("network interface service reports private mobile bridge URLs", tests.NetworkInterfaceServiceReportsPrivateMobileBridgeUrls),
    ("network interface service hides public hosts unless explicitly allowed", tests.NetworkInterfaceServiceHidesPublicHostsUnlessExplicitlyAllowed),
    ("network interface service accepts temporary host override", tests.NetworkInterfaceServiceAcceptsTemporaryHostOverride),
    ("sync service updates goal and records mobile-visible event", tests.SyncServiceUpdatesGoalAndRecordsMobileVisibleEvent),
    ("sync service tracks task progress through completion", tests.SyncServiceTracksTaskProgressThroughCompletion),
    ("bridge hosting defaults to all interfaces for phone access", tests.BridgeHostingDefaultsToAllInterfacesForPhoneAccess),
    ("bridge hosting accepts explicit bind urls", tests.BridgeHostingAcceptsExplicitBindUrls),
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

    public void FileServiceMarksMarkdownFilesForMobileReading()
    {
        using var workspace = new TempWorkspace();
        var root = workspace.CreateDirectory("knowledge");
        File.WriteAllText(Path.Combine(root, "00-总目录.md"), "# 总目录\n\n- 快速开始", Encoding.UTF8);

        var store = new ProjectStore();
        var project = store.AddProject("AgentScope Java Harness 知识库", root);
        var files = new FileWorkspaceService(store);

        var read = files.ReadText(project.Id, "00-总目录.md");

        AssertEqual("markdown", read.Language, "markdown language detected");
        AssertTrue(read.Content.Contains("快速开始", StringComparison.Ordinal), "markdown content preserved");
    }

    public void ProjectStoreLoadsDefaultKnowledgeProjectsFromEnvironmentFormat()
    {
        using var workspace = new TempWorkspace();
        var root = workspace.CreateDirectory("AgentScope-Java-Harness-知识库");
        var missing = Path.Combine(root, "missing");
        var store = new ProjectStore();

        var added = store.AddConfiguredProjects($"AgentScope Java Harness 知识库={root};Missing={missing}");

        AssertEqual(1, added, "only existing roots are loaded");
        var project = store.ListProjects().Single();
        AssertEqual("AgentScope Java Harness 知识库", project.Name, "configured name preserved");
        AssertEqual(root, project.RootPath, "configured root canonicalized");
    }

    public void ProjectStoreLoadsTrustedCodexProjectsFromConfig()
    {
        using var workspace = new TempWorkspace();
        var trusted = workspace.CreateDirectory("trusted-project");
        var untrusted = workspace.CreateDirectory("untrusted-project");
        var sensitive = workspace.CreateDirectory(".codex");
        var config = Path.Combine(workspace.RootPath, "config.toml");
        File.WriteAllText(
            config,
            $"""
            [projects.'{trusted}']
            trust_level = "trusted"

            [projects.'{untrusted}']
            trust_level = "untrusted"

            [projects.'{sensitive}']
            trust_level = "trusted"
            """,
            Encoding.UTF8);

        var store = new ProjectStore();

        var added = store.AddTrustedProjectsFromCodexConfig(config);

        AssertEqual(1, added, "only trusted project roots are loaded");
        var project = store.ListProjects().Single();
        AssertEqual(Path.GetFileName(trusted), project.Name, "project name from folder");
        AssertEqual(trusted, project.RootPath, "trusted project path");
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
        client.Enqueue("thread/read", new Dictionary<string, object?> { ["thread"] = new Dictionary<string, object?>() });
        var gateway = new CodexAppServerGateway(client);

        var config = gateway.ReadConfigAsync().GetAwaiter().GetResult();
        var account = gateway.ReadAccountAsync().GetAwaiter().GetResult();
        var threads = gateway.ListThreadsAsync().GetAwaiter().GetResult();
        _ = gateway.ReadThreadAsync("thread-1").GetAwaiter().GetResult();

        AssertEqual("config/read", client.Calls[0].Method, "config method");
        AssertEqual("account/read", client.Calls[1].Method, "account method");
        AssertEqual("thread/list", client.Calls[2].Method, "thread list method");
        AssertEqual("thread/read", client.Calls[3].Method, "thread read method");
        var readParams = (Dictionary<string, object?>)client.Calls[3].Parameters!;
        AssertTrue(readParams.TryGetValue("includeTurns", out var includeTurns) && includeTurns is true, "thread read includes turns");
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

    public void NetworkInterfaceServiceReportsPrivateMobileBridgeUrls()
    {
        var service = new NetworkInterfaceService(
            () =>
            [
                IPAddress.Parse("127.0.0.1"),
                IPAddress.Parse("192.168.31.25"),
                IPAddress.Parse("10.8.0.4"),
                IPAddress.Parse("100.72.10.9"),
            ],
            allowPublicBridgeHosts: false);

        var summary = service.ReadSummary("http", 51870);

        AssertFalse(summary.PublicExposureAllowed, "public exposure should be disabled");
        AssertTrue(summary.Endpoints.Any(endpoint => endpoint.Url == "http://127.0.0.1:51870"), "loopback URL included");
        AssertTrue(summary.Endpoints.Any(endpoint => endpoint.Url == "http://192.168.31.25:51870" && endpoint.Scope == "private-lan"), "LAN URL included");
        AssertTrue(summary.Endpoints.Any(endpoint => endpoint.Url == "http://10.8.0.4:51870" && endpoint.Scope == "private-lan"), "VPN private URL included");
        AssertTrue(summary.Endpoints.Any(endpoint => endpoint.Url == "http://100.72.10.9:51870" && endpoint.Scope == "mesh-vpn"), "mesh URL included");
        AssertTrue(summary.Endpoints.All(endpoint => endpoint.RequiresPairing), "every network URL requires pairing");
    }

    public void NetworkInterfaceServiceHidesPublicHostsUnlessExplicitlyAllowed()
    {
        var lockedDown = new NetworkInterfaceService(
            () => [IPAddress.Parse("8.8.8.8"), IPAddress.Parse("192.168.1.50")],
            allowPublicBridgeHosts: false);

        var lockedSummary = lockedDown.ReadSummary("http", 5010);
        AssertFalse(lockedSummary.Endpoints.Any(endpoint => endpoint.Host == "8.8.8.8"), "public host hidden by default");
        AssertTrue(lockedSummary.Warnings.Any(warning => warning.Contains("public", StringComparison.OrdinalIgnoreCase)), "public host warning present");

        var explicitlyAllowed = new NetworkInterfaceService(
            () => [IPAddress.Parse("8.8.8.8")],
            allowPublicBridgeHosts: true);

        var publicSummary = explicitlyAllowed.ReadSummary("https", 9443);
        AssertTrue(publicSummary.Endpoints.Any(endpoint => endpoint.Url == "https://8.8.8.8:9443"), "explicit public URL included");
        AssertTrue(publicSummary.PublicExposureAllowed, "public exposure flag recorded");
    }

    public void NetworkInterfaceServiceAcceptsTemporaryHostOverride()
    {
        var previous = Environment.GetEnvironmentVariable("CODEX_MOBILE_BRIDGE_HOSTS");
        try
        {
            Environment.SetEnvironmentVariable("CODEX_MOBILE_BRIDGE_HOSTS", "127.0.0.1,192.168.55.44,not-an-ip");

            var hosts = NetworkInterfaceService.GetLocalIPv4Addresses();

            AssertTrue(hosts.Any(host => host.ToString() == "127.0.0.1"), "loopback override parsed");
            AssertTrue(hosts.Any(host => host.ToString() == "192.168.55.44"), "private override parsed");
            AssertFalse(hosts.Any(host => host.ToString() == "not-an-ip"), "invalid override ignored");
        }
        finally
        {
            Environment.SetEnvironmentVariable("CODEX_MOBILE_BRIDGE_HOSTS", previous);
        }
    }

    public void SyncServiceUpdatesGoalAndRecordsMobileVisibleEvent()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 5, 31, 11, 0, 0, TimeSpan.Zero));
        var service = new SyncStateService(clock);

        var goal = service.UpdateGoal(new UpdateGoalRequest(
            "实现手机端查看 Codex 进度并设置 /goal",
            GoalStatus.Active,
            "mobile"));
        var snapshot = service.GetSnapshot();

        AssertEqual(goal.Objective, snapshot.Goal?.Objective, "goal appears in snapshot");
        AssertEqual("mobile", goal.Source, "goal source preserved");
        AssertTrue(snapshot.Events.Any(evt => evt.Type == "goal.updated"), "goal event recorded");
    }

    public void SyncServiceTracksTaskProgressThroughCompletion()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 5, 31, 11, 30, 0, TimeSpan.Zero));
        var service = new SyncStateService(clock);

        var task = service.CreateTask(new CreateCodexTaskRequest(
            "Bridge real-time sync",
            "Wire goal and progress endpoints",
            "conv-1"));

        clock.Advance(TimeSpan.FromMinutes(3));
        var running = service.UpdateTaskProgress(
            task.Id,
            new UpdateCodexTaskProgressRequest(CodexTaskStatus.Running, 55, "Backend endpoints running"));

        AssertEqual(CodexTaskStatus.Running, running.Status, "task running");
        AssertEqual(55, running.ProgressPercent, "progress updated");

        clock.Advance(TimeSpan.FromMinutes(4));
        var completed = service.UpdateTaskProgress(
            task.Id,
            new UpdateCodexTaskProgressRequest(CodexTaskStatus.Completed, 100, "Verified from mobile"));
        var snapshot = service.GetSnapshot();

        AssertEqual(CodexTaskStatus.Completed, completed.Status, "task completed");
        AssertTrue(completed.CompletedAt is not null, "completed timestamp recorded");
        AssertTrue(snapshot.Tasks.Single(item => item.Id == task.Id).Summary.Contains("Verified", StringComparison.Ordinal), "snapshot has latest summary");
        AssertTrue(snapshot.Events.Count(evt => evt.Type == "task.updated") >= 2, "task update events recorded");
    }

    public void BridgeHostingDefaultsToAllInterfacesForPhoneAccess()
    {
        WithTemporaryEnvironment("ASPNETCORE_URLS", null, () =>
            WithTemporaryEnvironment("CODEX_MOBILE_BIND_URLS", null, () =>
            {
                var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();

                var urls = BridgeHosting.ResolveUrls(configuration);

                AssertEqual("http://0.0.0.0:5010", urls.Single(), "default bind url");
            }));
    }

    public void BridgeHostingAcceptsExplicitBindUrls()
    {
        WithTemporaryEnvironment("ASPNETCORE_URLS", null, () =>
            WithTemporaryEnvironment("CODEX_MOBILE_BIND_URLS", "http://127.0.0.1:5011;http://0.0.0.0:5011", () =>
            {
                var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();

                var urls = BridgeHosting.ResolveUrls(configuration);

                AssertEqual(2, urls.Length, "explicit url count");
                AssertTrue(urls.Contains("http://0.0.0.0:5011"), "explicit all-interface url");
            }));
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

    private static void WithTemporaryEnvironment(string name, string? value, Action action)
    {
        var previous = Environment.GetEnvironmentVariable(name);
        try
        {
            Environment.SetEnvironmentVariable(name, value);
            action();
        }
        finally
        {
            Environment.SetEnvironmentVariable(name, previous);
        }
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

    public string RootPath => root;

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
