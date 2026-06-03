using CodexMobile.Bridge.Models;
using CodexMobile.Bridge.Services;
using Microsoft.AspNetCore.Http;
using System.Text.Json;
using System.Text;
using System.Net;

var tests = new BridgeServiceTests();
var cases = new (string Name, Action Test)[]
{
    ("project whitelist canonicalizes roots and rejects path escape", tests.ProjectWhitelistRejectsPathEscape),
    ("file service reads text and hashes content", tests.FileServiceReadsAndHashesText),
    ("file service returns empty list for missing directory", tests.FileServiceReturnsEmptyListForMissingDirectory),
    ("file endpoint safety wrapper returns bad request for escaped paths", tests.FileEndpointSafetyWrapperReturnsBadRequestForEscapedPaths),
    ("file service marks markdown files for mobile reading", tests.FileServiceMarksMarkdownFilesForMobileReading),
    ("file service downloads html files as utf8 html", tests.FileServiceDownloadsHtmlFilesAsUtf8Html),
    ("file service downloads binary files with content type", tests.FileServiceDownloadsBinaryFilesWithContentType),
    ("project store loads default knowledge projects from environment format", tests.ProjectStoreLoadsDefaultKnowledgeProjectsFromEnvironmentFormat),
    ("project store loads trusted Codex projects from config", tests.ProjectStoreLoadsTrustedCodexProjectsFromConfig),
    ("file patch rejects stale hashes and applies matching content", tests.FilePatchUsesExpectedHash),
    ("pairing token expires and cannot be reused", tests.PairingTokenExpiresAndCannotBeReused),
    ("command service rejects commands outside allowlist", tests.CommandServiceRejectsUnsafeCommands),
    ("audit log redacts secret values", tests.AuditLogRedactsSecrets),
    ("conversation service stores messages and approvals", tests.ConversationServiceStoresMessagesAndApprovals),
    ("conversation service binds codex thread ids to conversations", tests.ConversationServiceBindsCodexThreadIds),
    ("protocol summary detects generated codex schema assets", tests.ProtocolSummaryDetectsGeneratedAssets),
    ("codex app-server gateway only allows mobile-safe methods", tests.CodexGatewayRejectsUnsafeMethods),
    ("codex app-server gateway maps config account and thread calls", tests.CodexGatewayMapsCoreCalls),
    ("codex app-server gateway prefers local history for fast mobile thread loading", tests.CodexGatewayPrefersLocalHistoryForFastMobileThreadLoading),
    ("codex app-server gateway serializes thread start and turn input payloads", tests.CodexGatewaySerializesThreadStartAndTurnInputPayloads),
    ("codex app-server gateway resumes unloaded history before starting turn", tests.CodexGatewayResumesUnloadedHistoryBeforeStartingTurn),
    ("codex app-server gateway retries start turn after app-server initialization failure", tests.CodexGatewayRetriesStartTurnAfterInitializationFailure),
    ("codex app-server gateway reports local history status without app-server probe", tests.CodexGatewayReportsLocalHistoryStatusWithoutAppServerProbe),
    ("connect page prefers reachable non-loopback bridge URL", tests.ConnectPagePrefersReachableNonLoopbackBridgeUrl),
    ("connection page creates QR pairing payload", tests.ConnectionPageCreatesQrPairingPayload),
    ("connect page is Windows-local only", tests.ConnectPageIsWindowsLocalOnly),
    ("ipad web runtime files are not long cached", tests.IpadWebRuntimeFilesAreNotLongCached),
    ("startup guide prints real phone URLs and local QR page", tests.StartupGuidePrintsRealPhoneUrlsAndLocalQrPage),
    ("pairing challenge includes secret id and code", tests.PairingChallengeIncludesSecretIdAndCode),
    ("pairing complete requires challenge id", tests.PairingCompleteRequiresChallengeId),
    ("pairing complete rejects mismatched challenge id", tests.PairingCompleteRejectsMismatchedChallengeId),
    ("pairing service rate limits failed completion attempts", tests.PairingServiceRateLimitsFailedCompletionAttempts),
    ("bridge security status summarizes pairing policy without secrets", tests.BridgeSecurityStatusSummarizesPairingPolicyWithoutSecrets),
    ("pairing token inventory exposes safe fingerprints only", tests.PairingTokenInventoryExposesSafeFingerprintsOnly),
    ("pairing token management endpoints require bearer auth", tests.PairingTokenManagementEndpointsRequireBearerAuth),
    ("local only endpoints reject remote access", tests.LocalOnlyEndpointsRejectRemoteAccess),
    ("local codex history reads threads from jsonl sessions", tests.LocalCodexHistoryReadsThreadsFromJsonlSessions),
    ("local codex history filters subagent threads from mobile list", tests.LocalCodexHistoryFiltersSubagentThreadsFromMobileList),
    ("local codex history filters instruction and developer messages", tests.LocalCodexHistoryFiltersInstructionAndDeveloperMessages),
    ("local codex history recovers latest windows goal", tests.LocalCodexHistoryRecoversLatestWindowsGoal),
    ("local codex history recovers multiple active windows goals", tests.LocalCodexHistoryRecoversMultipleActiveWindowsGoals),
    ("codex gateway falls back to local history", tests.CodexGatewayFallsBackToLocalHistory),
    ("conversation relay starts and reuses codex threads", tests.ConversationRelayStartsAndReusesCodexThreads),
    ("conversation relay does not fake local messages when codex send fails", tests.ConversationRelayDoesNotFakeLocalMessagesWhenCodexSendFails),
    ("conversation endpoint returns error status when codex send fails", tests.ConversationEndpointReturnsErrorStatusWhenCodexSendFails),
    ("device token store validates expiry and revocation", tests.DeviceTokenStoreValidatesExpiryAndRevocation),
    ("network interface service reports private mobile bridge URLs", tests.NetworkInterfaceServiceReportsPrivateMobileBridgeUrls),
    ("network interface service hides public hosts unless explicitly allowed", tests.NetworkInterfaceServiceHidesPublicHostsUnlessExplicitlyAllowed),
    ("network interface service prioritizes explicit external bridge URLs", tests.NetworkInterfaceServicePrioritizesExplicitExternalBridgeUrls),
    ("network interface service accepts temporary host override", tests.NetworkInterfaceServiceAcceptsTemporaryHostOverride),
    ("sync service updates goal and records mobile-visible event", tests.SyncServiceUpdatesGoalAndRecordsMobileVisibleEvent),
    ("sync service restores windows goal when bridge starts empty", tests.SyncServiceRestoresWindowsGoalWhenBridgeStartsEmpty),
    ("sync service restores multiple windows goals when bridge starts empty", tests.SyncServiceRestoresMultipleWindowsGoalsWhenBridgeStartsEmpty),
    ("sync service tracks task progress through completion", tests.SyncServiceTracksTaskProgressThroughCompletion),
    ("sync service records codex turn progress events", tests.SyncServiceRecordsCodexTurnProgressEvents),
    ("sync service records mobile user prompts for thread overlay", tests.SyncServiceRecordsMobileUserPromptsForThreadOverlay),
    ("codex notification mapper assigns active thread to streaming deltas", tests.CodexNotificationMapperAssignsActiveThreadToStreamingDeltas),
    ("codex gateway records mobile visible turn lifecycle", tests.CodexGatewayRecordsMobileVisibleTurnLifecycle),
    ("codex gateway overlays mobile user prompts onto thread reads", tests.CodexGatewayOverlaysMobileUserPromptsOntoThreadReads),
    ("codex gateway deduplicates mobile user prompt overlay when history catches up", tests.CodexGatewayDeduplicatesMobileUserPromptOverlayWhenHistoryCatchesUp),
    ("conversation detail exposes local pending messages with codex thread data", tests.ConversationDetailExposesLocalPendingMessagesWithCodexThreadData),
    ("bridge hosting defaults to all interfaces for phone access", tests.BridgeHostingDefaultsToAllInterfacesForPhoneAccess),
    ("bridge hosting keeps default port fixed when occupied", tests.BridgeHostingKeepsDefaultPortFixedWhenOccupied),
    ("bridge hosting accepts explicit bind urls", tests.BridgeHostingAcceptsExplicitBindUrls),
    ("bridge hosting keeps explicit configured urls even when occupied", tests.BridgeHostingKeepsExplicitConfiguredUrlsEvenWhenOccupied),
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

    public void FileServiceReturnsEmptyListForMissingDirectory()
    {
        using var workspace = new TempWorkspace();
        var root = workspace.CreateDirectory("project");
        var store = new ProjectStore();
        var project = store.AddProject("demo", root);
        var files = new FileWorkspaceService(store);

        var listed = files.List(project.Id, "missing\\superpowers");

        AssertEqual(0, listed.Count, "missing folder returns empty list instead of throwing 500");
    }

    public void FileEndpointSafetyWrapperReturnsBadRequestForEscapedPaths()
    {
        var result = FileEndpointHelpers.SafeFileResult<object>(
            () => throw new UnauthorizedAccessException("Path escapes the authorized project root."));

        AssertTrue(
            result is IStatusCodeHttpResult status && status.StatusCode == StatusCodes.Status400BadRequest,
            "escaped path returns 400 instead of an unhandled exception");
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

    public void FileServiceDownloadsBinaryFilesWithContentType()
    {
        using var workspace = new TempWorkspace();
        var root = workspace.CreateDirectory("project");
        var imagePath = Path.Combine(root, "s03_image2.png");
        var bytes = new byte[] { 137, 80, 78, 71 };
        File.WriteAllBytes(imagePath, bytes);

        var store = new ProjectStore();
        var project = store.AddProject("demo", root);
        var files = new FileWorkspaceService(store);

        var downloaded = files.Download(project.Id, "s03_image2.png");

        AssertEqual("image/png", downloaded.ContentType, "png content type");
        AssertEqual("s03_image2.png", downloaded.FileName, "file name");
        AssertTrue(downloaded.Bytes.SequenceEqual(bytes), "bytes preserved");
    }

    public void FileServiceDownloadsHtmlFilesAsUtf8Html()
    {
        using var workspace = new TempWorkspace();
        var root = workspace.CreateDirectory("project");
        var htmlPath = Path.Combine(root, "preview.htm");
        File.WriteAllText(htmlPath, "<!doctype html><title>连接</title>", Encoding.UTF8);

        var store = new ProjectStore();
        var project = store.AddProject("demo", root);
        var files = new FileWorkspaceService(store);

        var downloaded = files.Download(project.Id, "preview.htm");

        AssertEqual("text/html; charset=utf-8", downloaded.ContentType, "html content type");
        AssertEqual("preview.htm", downloaded.FileName, "html file name");
        AssertEqual("text", downloaded.Language, "html stays text-readable");
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
            () => service.Complete(challenge.Code, challenge.Id),
            "expired challenge should fail");

        var fresh = service.Start(TimeSpan.FromMinutes(1));
        var token = service.Complete(fresh.Code, fresh.Id);
        AssertTrue(token.AccessToken.Length >= 32, "access token length");
        AssertTrue(tokenStore.Validate(token.AccessToken), "token store validates issued token");
        AssertThrows<InvalidOperationException>(
            () => service.Complete(fresh.Code, fresh.Id),
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

    public void ConversationServiceBindsCodexThreadIds()
    {
        var clock = new ManualClock(DateTimeOffset.UtcNow);
        var service = new ConversationService(clock);
        var conversation = service.Create("demo", "project-1", "C:\\repo");

        var linked = service.BindCodexThread(conversation.Id, "thread-abc");
        var snapshot = service.Get(conversation.Id);

        AssertEqual("thread-abc", linked.CodexThreadId, "linked record returns thread id");
        AssertEqual("thread-abc", snapshot.Conversation.CodexThreadId, "snapshot preserves linked thread id");
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
        using var workspace = new TempWorkspace();
        var client = new FakeCodexAppServerClient();
        client.Enqueue("config/read", new Dictionary<string, object?> { ["model"] = "gpt-5.5" });
        client.Enqueue("account/read", new Dictionary<string, object?> { ["authMode"] = "chatgpt" });
        client.Enqueue("thread/list", new Dictionary<string, object?> { ["items"] = Array.Empty<object>() });
        client.Enqueue("thread/read", new Dictionary<string, object?> { ["thread"] = new Dictionary<string, object?>() });
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(workspace.CreateDirectory("empty-codex")));

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

    public void CodexGatewayPrefersLocalHistoryForFastMobileThreadLoading()
    {
        using var workspace = new TempWorkspace();
        var codexHome = workspace.CreateDirectory(".codex");
        var sessionsDir = Path.Combine(codexHome, "sessions", "2026", "06", "01");
        Directory.CreateDirectory(sessionsDir);

        var localThreadId = "019e-local-fast";
        var rolloutPath = Path.Combine(sessionsDir, $"rollout-2026-06-01T10-00-00-{localThreadId}.jsonl");
        File.WriteAllText(
            Path.Combine(codexHome, "session_index.jsonl"),
            $"{{\"id\":\"{localThreadId}\",\"thread_name\":\"fast local history\",\"updated_at\":\"2026-06-01T10:00:00Z\"}}",
            Encoding.UTF8);
        File.WriteAllText(
            rolloutPath,
            $"{{\"timestamp\":\"2026-06-01T10:00:00Z\",\"type\":\"session_meta\",\"payload\":{{\"id\":\"{localThreadId}\",\"timestamp\":\"2026-06-01T10:00:00Z\",\"cwd\":\"C:\\\\repo\",\"cli_version\":\"0.131.0-alpha.9\",\"source\":\"vscode\",\"model_provider\":\"newapi\"}}}}",
            Encoding.UTF8);

        var client = new FakeCodexAppServerClient();
        client.Enqueue("thread/list", new Dictionary<string, object?>
        {
            ["data"] = new[]
            {
                new Dictionary<string, object?>
                {
                    ["id"] = "thread-live",
                    ["name"] = "live app-server thread",
                    ["cwd"] = "C:\\repo",
                    ["updatedAt"] = 1,
                },
            },
        });
        client.Enqueue("thread/read", new Dictionary<string, object?>
        {
            ["thread"] = new Dictionary<string, object?>
            {
                ["id"] = "thread-live",
                ["name"] = "live app-server thread",
                ["cwd"] = "C:\\repo",
                ["turns"] = Array.Empty<object>(),
            },
        });
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(codexHome));

        var list = gateway.ListThreadsAsync().GetAwaiter().GetResult();
        var read = gateway.ReadThreadAsync(localThreadId).GetAwaiter().GetResult();

        AssertEqual(0, client.Calls.Count, "thread list/detail should not block on app-server when local Codex history exists");
        AssertEqual(localThreadId, list.Json.GetProperty("data")[0].GetProperty("id").GetString(), "local list wins for fast mobile loading");
        AssertEqual(localThreadId, read.Json.GetProperty("thread").GetProperty("id").GetString(), "local detail wins for fast mobile loading");
    }

    public void CodexGatewaySerializesThreadStartAndTurnInputPayloads()
    {
        using var workspace = new TempWorkspace();
        var client = new FakeCodexAppServerClient();
        client.Enqueue("thread/start", new Dictionary<string, object?>
        {
            ["thread"] = new Dictionary<string, object?> { ["id"] = "thread-started" },
        });
        client.Enqueue("turn/start", new Dictionary<string, object?>
        {
            ["turn"] = new Dictionary<string, object?> { ["id"] = "turn-started" },
        });
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(workspace.CreateDirectory("empty-codex")));

        _ = gateway.StartThreadAsync(new StartCodexThreadRequest("C:\\repo", "第一条手机消息")).GetAwaiter().GetResult();
        _ = gateway.StartTurnAsync(new StartCodexTurnRequest("thread-started", "继续手机消息")).GetAwaiter().GetResult();

        var startParams = (Dictionary<string, object?>)client.Calls[0].Parameters!;
        var startInput = ((IEnumerable<object>)startParams["input"]!).Cast<Dictionary<string, object?>>().Single();
        AssertEqual("thread/start", client.Calls[0].Method, "thread start method");
        AssertEqual("C:\\repo", startParams["cwd"], "thread start cwd");
        AssertEqual(true, startParams["persistExtendedHistory"], "mobile-created threads are persisted for Windows Codex history");
        AssertEqual("text", startInput["type"], "thread start uses text input");
        AssertEqual("第一条手机消息", startInput["text"], "thread start prompt serialized as input text");
        AssertTrue(startInput.TryGetValue("text_elements", out var elements) && elements is Array, "thread start carries text elements");

        var turnParams = (Dictionary<string, object?>)client.Calls[1].Parameters!;
        var turnInput = ((IEnumerable<object>)turnParams["input"]!).Cast<Dictionary<string, object?>>().Single();
        AssertEqual("turn/start", client.Calls[1].Method, "turn start method");
        AssertEqual("thread-started", turnParams["threadId"], "turn start thread id");
        AssertEqual("继续手机消息", turnInput["text"], "turn start prompt serialized as input text");
    }

    public void CodexGatewayResumesUnloadedHistoryBeforeStartingTurn()
    {
        using var workspace = new TempWorkspace();
        var client = new FakeCodexAppServerClient();
        client.Enqueue("turn/start", new InvalidOperationException("thread is not loaded"));
        client.Enqueue("thread/resume", new Dictionary<string, object?>
        {
            ["thread"] = new Dictionary<string, object?> { ["id"] = "thread-history" },
        });
        client.Enqueue("turn/start", new Dictionary<string, object?>
        {
            ["turn"] = new Dictionary<string, object?> { ["id"] = "turn-history" },
        });
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(workspace.CreateDirectory("empty-codex")));

        _ = gateway.StartTurnAsync(new StartCodexTurnRequest("thread-history", "从手机继续之前的历史对话")).GetAwaiter().GetResult();

        AssertEqual("turn/start", client.Calls[0].Method, "first turn start attempted");
        AssertEqual("thread/resume", client.Calls[1].Method, "unloaded history thread resumed");
        AssertEqual("turn/start", client.Calls[2].Method, "turn start retried after resume");
        var resumeParams = (Dictionary<string, object?>)client.Calls[1].Parameters!;
        AssertEqual("thread-history", resumeParams["threadId"], "resume uses history thread id");
        AssertEqual(false, resumeParams["excludeTurns"], "resume loads previous turns so mobile continues real history");
        AssertEqual(true, resumeParams["persistExtendedHistory"], "resume keeps mobile turns visible in Windows history");
        var retryParams = (Dictionary<string, object?>)client.Calls[2].Parameters!;
        AssertEqual("thread-history", retryParams["threadId"], "retry uses same thread id");
    }

    public void CodexGatewayRetriesStartTurnAfterInitializationFailure()
    {
        using var workspace = new TempWorkspace();
        var client = new FakeCodexAppServerClient();
        client.Enqueue("turn/start", new InvalidOperationException("""{"code":-32600,"message":"Not initialized"}"""));
        client.Enqueue("initialize", new Dictionary<string, object?>
        {
            ["serverInfo"] = new Dictionary<string, object?> { ["name"] = "codex" },
        });
        client.Enqueue("turn/start", new Dictionary<string, object?>
        {
            ["turn"] = new Dictionary<string, object?> { ["id"] = "turn-after-init" },
        });
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(workspace.CreateDirectory("empty-codex")));

        _ = gateway.StartTurnAsync(new StartCodexTurnRequest("thread-init", "初始化后继续")).GetAwaiter().GetResult();

        AssertEqual("turn/start", client.Calls[0].Method, "first turn start attempted");
        AssertEqual("initialize", client.Calls[1].Method, "initialize sent after not initialized");
        var initializeParams = (Dictionary<string, object?>)client.Calls[1].Parameters!;
        var capabilities = (Dictionary<string, object?>)initializeParams["capabilities"]!;
        AssertEqual(true, capabilities["experimentalApi"], "initialize enables experimental api for persisted history resume");
        AssertEqual("turn/start", client.Calls[2].Method, "turn start retried after initialize");
    }

    public void CodexGatewayReportsLocalHistoryStatusWithoutAppServerProbe()
    {
        using var workspace = new TempWorkspace();
        var codexHome = workspace.CreateDirectory(".codex");
        File.WriteAllText(
            Path.Combine(codexHome, "session_index.jsonl"),
            "{\"id\":\"thread-status\",\"thread_name\":\"status\",\"updated_at\":\"2026-06-02T00:00:00Z\"}",
            Encoding.UTF8);
        var client = new FakeCodexAppServerClient { Failure = new InvalidOperationException("app-server should not be probed") };
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(codexHome));

        var status = gateway.GetStatusAsync().GetAwaiter().GetResult();

        AssertTrue(status.Available, "local history status available");
        AssertTrue(status.Message.Contains("本机历史", StringComparison.Ordinal), "status explains local history mode");
        AssertEqual(0, client.Calls.Count, "status must not start/probe app-server");
    }

    public void ConnectPagePrefersReachableNonLoopbackBridgeUrl()
    {
        var summary = new NetworkInterfaceService(
            () =>
            [
                IPAddress.Parse("127.0.0.1"),
                IPAddress.Parse("192.168.31.25"),
                IPAddress.Parse("100.72.10.9"),
            ],
            allowPublicBridgeHosts: false).ReadSummary("http", 5010);

        var preferred = ConnectPageService.SelectPreferredEndpoint(summary);

        AssertEqual("http://192.168.31.25:5010", preferred.Url, "LAN URL should beat loopback");
        AssertEqual("private-lan", preferred.Scope, "preferred scope");
    }

    public void ConnectionPageCreatesQrPairingPayload()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 1, 10, 0, 0, TimeSpan.Zero));
        var tokenStore = new DeviceTokenStore(clock);
        var pairing = new PairingService(clock, tokenStore);
        var network = new NetworkInterfaceService(
            () =>
            [
                IPAddress.Parse("127.0.0.1"),
                IPAddress.Parse("192.168.31.25"),
                IPAddress.Parse("10.8.0.4"),
            ],
            allowPublicBridgeHosts: false);
        var pageService = new ConnectPageService(pairing, network);

        var page = pageService.Create("http", 51870, TimeSpan.FromMinutes(5));
        using var payload = JsonDocument.Parse(page.PayloadJson);
        var root = payload.RootElement;

        AssertEqual("codex-mobile-bridge", root.GetProperty("type").GetString(), "payload type");
        AssertEqual(1, root.GetProperty("version").GetInt32(), "payload version");
        AssertTrue(!string.IsNullOrWhiteSpace(root.GetProperty("challengeId").GetString()), "payload challenge id");
        AssertEqual("http://192.168.31.25:51870", root.GetProperty("bridgeUrl").GetString(), "payload bridge URL");
        var bridgeUrls = root.GetProperty("bridgeUrls").EnumerateArray().Select(item => item.GetString()).ToArray();
        AssertTrue(
            bridgeUrls.SequenceEqual(
                [
                    "http://192.168.31.25:51870",
                    "http://10.8.0.4:51870",
                ]),
            "payload bridge URLs");
        AssertEqual(page.PairingCode, root.GetProperty("pairingCode").GetString(), "payload pairing code");
        AssertEqual(page.ExpiresAt, root.GetProperty("expiresAt").GetDateTimeOffset(), "payload expiry");
        AssertTrue(page.PairingCode.Length == 6, "pairing code length");
        AssertTrue(page.QrSvg.StartsWith("<svg", StringComparison.Ordinal), "QR is local SVG");
        AssertTrue(page.Html.Contains("连接 Codex Mobile Bridge", StringComparison.Ordinal), "Chinese title rendered");
        AssertTrue(page.Html.Contains("background:#fff", StringComparison.Ordinal), "white background rendered");
        AssertTrue(page.Html.Contains("http://127.0.0.1:51870", StringComparison.Ordinal), "alternative URL rendered");
        AssertTrue(page.Html.Contains("iPad/Web 地址", StringComparison.Ordinal), "iPad web section rendered");
        AssertTrue(page.Html.Contains("有效期 5 分钟且只能使用一次", StringComparison.Ordinal), "pairing TTL warning rendered");
        AssertTrue(page.Html.Contains("http://192.168.31.25:51870/ipad/", StringComparison.Ordinal), "LAN iPad URL rendered");
        AssertTrue(page.Html.Contains("http://10.8.0.4:51870/ipad/", StringComparison.Ordinal), "VPN iPad URL rendered");
    }

    public void ConnectPageIsWindowsLocalOnly()
    {
        AssertFalse(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/connect")), "/connect should not be public");
        AssertFalse(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/connect/")), "/connect slash should not be public");
        AssertFalse(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/pairing/start")), "/pairing/start should not be public");
        AssertTrue(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/ipad")), "/ipad should stay public for iPad");
        AssertTrue(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/pairing/complete")), "/pairing/complete remains public for paired QR flow");
        AssertFalse(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/projects")), "projects should stay protected");

        AssertTrue(BridgeAccessPolicy.IsLocalHost(new HostString("127.0.0.1:5010")), "loopback host allowed");
        AssertTrue(BridgeAccessPolicy.IsLocalHost(new HostString("localhost:5010")), "localhost allowed");
        AssertTrue(BridgeAccessPolicy.IsLocalHost(new HostString("[::1]:5010")), "IPv6 loopback host allowed");
        AssertFalse(BridgeAccessPolicy.IsLocalHost(new HostString("move-president-guns-victorian.trycloudflare.com")), "tunnel host rejected");
        AssertFalse(BridgeAccessPolicy.IsLocalHost(new HostString("10.250.236.241:5010")), "LAN host rejected");

        AssertTrue(IsLocalOnlyRequest("/connect", "127.0.0.1:5010", IPAddress.Loopback), "local connect allowed");
        AssertFalse(IsLocalOnlyRequest("/connect", "move-president-guns-victorian.trycloudflare.com", IPAddress.Loopback), "tunnel host cannot render QR");
        AssertFalse(IsLocalOnlyRequest("/connect", "10.250.236.241:5010", IPAddress.Loopback), "LAN host cannot render QR");
        AssertFalse(IsLocalOnlyRequest("/connect", "127.0.0.1:5010", IPAddress.Parse("10.250.236.241")), "remote address cannot render QR");
    }

    public void IpadWebRuntimeFilesAreNotLongCached()
    {
        AssertEqual("no-cache, no-store, must-revalidate", IpadWebCachePolicy.CacheControlFor("index.html"), "index no cache");
        AssertEqual("no-cache, no-store, must-revalidate", IpadWebCachePolicy.CacheControlFor("main.dart.js"), "runtime js no cache");
        AssertEqual("no-cache, no-store, must-revalidate", IpadWebCachePolicy.CacheControlFor("flutter_bootstrap.js"), "bootstrap no cache");
        AssertEqual("public, max-age=604800", IpadWebCachePolicy.CacheControlFor("assets/FontManifest.json"), "assets can be cached");
    }

    public void StartupGuidePrintsRealPhoneUrlsAndLocalQrPage()
    {
        var summary = new NetworkInterfaceService(
            () =>
            [
                IPAddress.Parse("127.0.0.1"),
                IPAddress.Parse("10.250.236.241"),
            ],
            allowPublicBridgeHosts: false).ReadSummary("http", 5010);

        var guide = BridgeStartupExperience.CreateGuide("http", 5010, summary);

        AssertEqual("http://127.0.0.1:5010/connect", guide.LocalConnectUrl, "local QR page URL");
        AssertTrue(guide.PhoneBridgeUrls.Contains("http://10.250.236.241:5010"), "real phone bridge URL listed");
        AssertTrue(guide.IpadWebUrls.Contains("http://10.250.236.241:5010/ipad/"), "iPad web URL listed");
        AssertTrue(guide.ConsoleText.Contains("iPad/Web URLs", StringComparison.Ordinal), "console prints iPad URL section");
        AssertTrue(guide.ConsoleText.Contains("http://10.250.236.241:5010/ipad/", StringComparison.Ordinal), "console prints real iPad URL");
        AssertTrue(guide.ConsoleText.Contains("http://10.250.236.241:5010", StringComparison.Ordinal), "console prints real phone URL");
        AssertTrue(guide.ConsoleText.Contains("http://127.0.0.1:5010/connect", StringComparison.Ordinal), "console prints local QR UI");
        AssertTrue(guide.ConsoleText.Contains("/connect 只能在 Windows 本机", StringComparison.Ordinal), "console explains local-only QR UI");
        AssertFalse(guide.ConsoleText.Contains("Phone QR URLs", StringComparison.Ordinal), "console does not print remote QR URLs");
        AssertFalse(guide.ConsoleText.Contains("http://10.250.236.241:5010/connect", StringComparison.Ordinal), "console does not expose LAN QR URL");
        AssertTrue(guide.ConsoleText.Contains("不要在手机填 0.0.0.0", StringComparison.Ordinal), "console explains 0.0.0.0");
    }

    public void PairingChallengeIncludesSecretIdAndCode()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 1, 14, 50, 0, TimeSpan.Zero));
        var pairing = new PairingService(clock, new DeviceTokenStore(clock));

        var challenge = pairing.Start(TimeSpan.FromMinutes(5));

        AssertTrue(!string.IsNullOrWhiteSpace(challenge.Id), "challenge id issued");
        AssertTrue(challenge.Id.Length >= 16, "challenge id length");
        AssertTrue(challenge.Code.Length == 6, "challenge code length");
    }

    public void PairingCompleteRejectsMismatchedChallengeId()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 1, 14, 50, 0, TimeSpan.Zero));
        var pairing = new PairingService(clock, new DeviceTokenStore(clock));
        var challenge = pairing.Start(TimeSpan.FromMinutes(5));

        AssertThrows<InvalidOperationException>(
            () => pairing.Complete(challenge.Code, "wrong-challenge"),
            "challenge id mismatch should fail");

        var token = pairing.Complete(challenge.Code, challenge.Id);
        AssertTrue(token.AccessToken.Length >= 32, "matching challenge completes");
    }

    public void PairingCompleteRequiresChallengeId()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 1, 14, 55, 0, TimeSpan.Zero));
        var pairing = new PairingService(clock, new DeviceTokenStore(clock));
        var challenge = pairing.Start(TimeSpan.FromMinutes(5));

        AssertThrows<InvalidOperationException>(
            () => pairing.Complete(challenge.Code),
            "challenge id is required to prove QR challenge secret");

        var token = pairing.Complete(challenge.Code, challenge.Id);
        AssertTrue(token.AccessToken.Length >= 32, "challenge remains usable with matching id");
    }

    public void PairingServiceRateLimitsFailedCompletionAttempts()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 1, 15, 0, 0, TimeSpan.Zero));
        var pairing = new PairingService(clock, new DeviceTokenStore(clock));
        var challenge = pairing.Start(TimeSpan.FromMinutes(5));

        for (var attempt = 0; attempt < PairingService.MaxFailedAttempts; attempt++)
        {
            AssertThrows<InvalidOperationException>(
                () => pairing.Complete("000000", challenge.Id),
                "wrong code should fail");
        }

        var locked = pairing.ReadSecuritySnapshot();
        AssertEqual(PairingService.MaxFailedAttempts, locked.FailedAttempts, "failed attempt count");
        AssertTrue(locked.CooldownUntil > clock.Now, "cooldown started");
        AssertThrows<InvalidOperationException>(
            () => pairing.Start(TimeSpan.FromMinutes(5)),
            "new pairing challenges are blocked during cooldown");
        AssertThrows<InvalidOperationException>(
            () => pairing.Complete(challenge.Code, challenge.Id),
            "pairing completion is blocked during cooldown");

        clock.Advance(TimeSpan.FromMinutes(3));
        var fresh = pairing.Start(TimeSpan.FromMinutes(5));
        var token = pairing.Complete(fresh.Code, fresh.Id);
        var recovered = pairing.ReadSecuritySnapshot();

        AssertTrue(token.AccessToken.Length >= 32, "pairing works after cooldown");
        AssertEqual(0, recovered.FailedAttempts, "success resets failed attempts");
        AssertTrue(recovered.CooldownUntil is null, "success clears cooldown");
        AssertEqual(1, recovered.SuccessfulPairings, "success count recorded");
        AssertEqual(0, recovered.ActiveChallenges, "successful challenge is closed");
    }

    public void LocalOnlyEndpointsRejectRemoteAccess()
    {
        AssertTrue(BridgeAccessPolicy.IsLocalOnlyEndpoint(new Microsoft.AspNetCore.Http.PathString("/connect")), "/connect is local only");
        AssertTrue(BridgeAccessPolicy.IsLocalOnlyEndpoint(new Microsoft.AspNetCore.Http.PathString("/pairing/start")), "/pairing/start is local only");
        AssertFalse(BridgeAccessPolicy.IsLocalOnlyEndpoint(new Microsoft.AspNetCore.Http.PathString("/goal")), "/goal is not local only");
        AssertTrue(BridgeAccessPolicy.IsLocalAddress(IPAddress.Loopback), "loopback allowed");
        AssertFalse(BridgeAccessPolicy.IsLocalAddress(IPAddress.Parse("10.250.236.241")), "remote address rejected");
    }

    public void BridgeSecurityStatusSummarizesPairingPolicyWithoutSecrets()
    {
        var status = BridgeEndpointPolicy.ReadSecurityStatus();

        AssertTrue(status.PairingRequiresChallengeId, "pairing must require challenge id");
        AssertTrue(status.LocalOnlyEndpoints.Contains("/connect"), "connect local-only status listed");
        AssertTrue(status.LocalOnlyEndpoints.Contains("/pairing/start"), "pairing start local-only status listed");
        AssertTrue(status.PublicEndpoints.Contains("/security/status"), "status endpoint listed");
        AssertTrue(status.PublicEndpoints.Contains("/ipad"), "iPad web app endpoint listed");
        AssertTrue(status.PublicEndpoints.Contains("/pairing/complete"), "pairing complete endpoint listed");
        AssertFalse(status.PublicEndpoints.Contains("/pairing"), "pairing namespace must not be public");
        AssertFalse(status.PublicEndpoints.Contains("token"), "status must not include tokens");
        AssertFalse(status.PublicEndpoints.Contains("challengeId"), "status must not include challenge ids");
        AssertFalse(status.PublicEndpoints.Contains("code"), "status must not include pairing codes");
    }

    public void PairingTokenInventoryExposesSafeFingerprintsOnly()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 1, 13, 0, 0, TimeSpan.Zero));
        var store = new DeviceTokenStore(clock);
        var token = store.Issue("phone-a", TimeSpan.FromMinutes(10));
        var expired = store.Issue("phone-old", TimeSpan.FromSeconds(1));

        clock.Advance(TimeSpan.FromSeconds(2));
        var inventory = store.ListActive(token.AccessToken);

        AssertEqual(1, inventory.Count, "expired tokens are hidden");
        AssertEqual("phone-a", inventory.Single().DeviceName, "device name");
        AssertTrue(inventory.Single().Fingerprint.Length == 12, "short fingerprint length");
        AssertTrue(inventory.Single().IsCurrent, "current token marked");
        AssertFalse(inventory.Single().Fingerprint == token.AccessToken, "raw token is not exposed");
        AssertFalse(JsonSerializer.Serialize(inventory).Contains(token.AccessToken, StringComparison.Ordinal), "raw token not serialized");
        AssertFalse(JsonSerializer.Serialize(inventory).Contains(expired.AccessToken, StringComparison.Ordinal), "expired raw token not serialized");
    }

    public void PairingTokenManagementEndpointsRequireBearerAuth()
    {
        AssertTrue(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/pairing/complete")), "pairing complete remains public");
        AssertFalse(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/pairing/tokens")), "token inventory requires bearer auth");
        AssertFalse(BridgeEndpointPolicy.IsPublicEndpoint(new Microsoft.AspNetCore.Http.PathString("/pairing/tokens/abc/revoke")), "token revoke requires bearer auth");
    }

    public void LocalCodexHistoryReadsThreadsFromJsonlSessions()
    {
        using var workspace = new TempWorkspace();
        var codexHome = workspace.CreateDirectory(".codex");
        var sessionsDir = Path.Combine(codexHome, "sessions", "2026", "05", "31");
        Directory.CreateDirectory(sessionsDir);

        var threadId = "019e9999-test-thread";
        var rolloutPath = Path.Combine(sessionsDir, $"rollout-2026-05-31T10-00-00-{threadId}.jsonl");
        var indexLine = $"{{\"id\":\"{threadId}\",\"thread_name\":\"实现调研目标并测试\",\"updated_at\":\"2026-05-31T10:00:00Z\"}}";
        var metaLine = $"{{\"timestamp\":\"2026-05-31T10:00:00Z\",\"type\":\"session_meta\",\"payload\":{{\"id\":\"{threadId}\",\"timestamp\":\"2026-05-31T10:00:00Z\",\"cwd\":\"C:\\\\Users\\\\TestUser\\\\Desktop\\\\code\\\\dev\\\\codex_mobile_app\",\"originator\":\"Codex Desktop\",\"cli_version\":\"0.131.0-alpha.9\",\"source\":\"vscode\",\"thread_source\":\"user\",\"model_provider\":\"newapi\"}}}}";
        File.WriteAllText(
            Path.Combine(codexHome, "session_index.jsonl"),
            indexLine,
            Encoding.UTF8);
        File.WriteAllText(
            rolloutPath,
            string.Join(Environment.NewLine, new[]
            {
                metaLine,
                "{\"timestamp\":\"2026-05-31T10:01:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"message\":\"手机端和 Windows 端同步\"}}",
                "{\"timestamp\":\"2026-05-31T10:02:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"agent_message\",\"message\":\"已读取真实 Codex 线程\"}}",
            }),
            Encoding.UTF8);

        var service = new LocalCodexHistoryService(codexHome);
        var list = service.ListThreads();
        var read = service.ReadThread(threadId);

        AssertTrue(list.GetProperty("data").GetArrayLength() == 1, "one local thread listed");
        AssertEqual(threadId, list.GetProperty("data")[0].GetProperty("id").GetString(), "thread id preserved");
        AssertEqual("实现调研目标并测试", list.GetProperty("data")[0].GetProperty("name").GetString(), "thread name preserved");
        AssertEqual("agentMessage", read.GetProperty("thread").GetProperty("turns")[0].GetProperty("items")[1].GetProperty("type").GetString(), "thread detail built");
    }

    public void LocalCodexHistoryFiltersInstructionAndDeveloperMessages()
    {
        using var workspace = new TempWorkspace();
        var codexHome = workspace.CreateDirectory(".codex");
        var sessionsDir = Path.Combine(codexHome, "sessions", "2026", "06", "01");
        Directory.CreateDirectory(sessionsDir);

        var threadId = "019e9999-filter-thread";
        var rolloutPath = Path.Combine(sessionsDir, $"rollout-2026-06-01T10-00-00-{threadId}.jsonl");
        File.WriteAllText(
            Path.Combine(codexHome, "session_index.jsonl"),
            $"{{\"id\":\"{threadId}\",\"thread_name\":\"过滤系统指令\",\"updated_at\":\"2026-06-01T10:00:00Z\"}}",
            Encoding.UTF8);
        File.WriteAllText(
            rolloutPath,
            string.Join(Environment.NewLine, new[]
            {
                $"{{\"timestamp\":\"2026-06-01T10:00:00Z\",\"type\":\"session_meta\",\"payload\":{{\"id\":\"{threadId}\",\"timestamp\":\"2026-06-01T10:00:00Z\",\"cwd\":\"C:\\\\repo\",\"base_instructions\":{{\"text\":\"<permissions instructions>不要显示</permissions instructions>\"}}}}}}",
                "{\"timestamp\":\"2026-06-01T10:01:00Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"developer\",\"content\":[{\"type\":\"text\",\"text\":\"<skills_instructions>不要显示</skills_instructions>\"}]}}",
                "{\"timestamp\":\"2026-06-01T10:02:00Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":\"真实用户问题\"}]}}",
                "{\"timestamp\":\"2026-06-01T10:03:00Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"真实助手回复\"}]}}",
            }),
            Encoding.UTF8);

        var service = new LocalCodexHistoryService(codexHome);
        var read = service.ReadThread(threadId);
        var items = read.GetProperty("thread").GetProperty("turns")[0].GetProperty("items");
        var serialized = read.ToString();

        AssertEqual(2, items.GetArrayLength(), "only user and assistant messages are exposed");
        AssertEqual("userMessage", items[0].GetProperty("type").GetString(), "user message kept");
        AssertEqual("agentMessage", items[1].GetProperty("type").GetString(), "assistant message kept");
        AssertEqual("真实用户问题", items[0].GetProperty("content")[0].GetProperty("text").GetString(), "user text kept");
        AssertEqual("真实助手回复", items[1].GetProperty("text").GetString(), "assistant text kept");
        AssertFalse(serialized.Contains("permissions instructions", StringComparison.OrdinalIgnoreCase), "session instructions filtered");
        AssertFalse(serialized.Contains("skills_instructions", StringComparison.OrdinalIgnoreCase), "developer instructions filtered");
    }

    public void LocalCodexHistoryFiltersSubagentThreadsFromMobileList()
    {
        using var workspace = new TempWorkspace();
        var codexHome = workspace.CreateDirectory(".codex");
        var sessionsDir = Path.Combine(codexHome, "sessions", "2026", "06", "02");
        Directory.CreateDirectory(sessionsDir);

        var mainThreadId = "019e-main-thread";
        var subagentThreadId = "019e-subagent-thread";
        File.WriteAllText(
            Path.Combine(codexHome, "session_index.jsonl"),
            string.Join(Environment.NewLine, new[]
            {
                $"{{\"id\":\"{mainThreadId}\",\"thread_name\":\"主线程\",\"updated_at\":\"2026-06-02T10:00:00Z\"}}",
                $"{{\"id\":\"{subagentThreadId}\",\"thread_name\":\"子 agent 线程\",\"updated_at\":\"2026-06-02T10:01:00Z\"}}",
            }),
            Encoding.UTF8);
        File.WriteAllText(
            Path.Combine(sessionsDir, $"rollout-main-{mainThreadId}.jsonl"),
            $"{{\"timestamp\":\"2026-06-02T10:00:00Z\",\"type\":\"session_meta\",\"payload\":{{\"id\":\"{mainThreadId}\",\"timestamp\":\"2026-06-02T10:00:00Z\",\"cwd\":\"C:\\\\repo\",\"thread_source\":\"user\"}}}}",
            Encoding.UTF8);
        File.WriteAllText(
            Path.Combine(sessionsDir, $"rollout-sub-{subagentThreadId}.jsonl"),
            $"{{\"timestamp\":\"2026-06-02T10:01:00Z\",\"type\":\"session_meta\",\"payload\":{{\"id\":\"{subagentThreadId}\",\"timestamp\":\"2026-06-02T10:01:00Z\",\"cwd\":\"C:\\\\repo\",\"thread_source\":\"subagent\",\"agent_nickname\":\"Fermat\",\"agent_role\":\"explorer\"}}}}",
            Encoding.UTF8);

        var service = new LocalCodexHistoryService(codexHome);
        var list = service.ListThreads();
        var data = list.GetProperty("data");
        var subagentRead = service.ReadThread(subagentThreadId).GetProperty("thread");

        AssertEqual(1, data.GetArrayLength(), "subagent thread hidden from mobile list");
        AssertEqual(mainThreadId, data[0].GetProperty("id").GetString(), "main thread remains listed");
        AssertEqual("subagent", subagentRead.GetProperty("threadSource").GetString(), "detail preserves source for direct reads");
        AssertEqual("Fermat", subagentRead.GetProperty("agentNickname").GetString(), "subagent nickname preserved");
    }

    public void LocalCodexHistoryRecoversLatestWindowsGoal()
    {
        using var workspace = new TempWorkspace();
        var codexHome = CreateCodexHomeWithGoal(
            workspace,
            "019e7777-goal-thread",
            "手机端必须同步 Windows 既有 /goal",
            "active",
            "2026-06-01T09:01:48Z");

        var service = new LocalCodexHistoryService(codexHome);

        var goal = service.ReadLatestGoal();

        AssertTrue(goal is not null, "windows goal recovered");
        AssertEqual("手机端必须同步 Windows 既有 /goal", goal!.Objective, "objective recovered");
        AssertEqual(GoalStatus.Active, goal.Status, "goal status recovered");
        AssertEqual("windows-codex-history", goal.Source, "goal source explains provenance");
        AssertEqual(new DateTimeOffset(2026, 6, 1, 9, 1, 48, TimeSpan.Zero), goal.UpdatedAt, "goal update time recovered");
    }

    public void LocalCodexHistoryRecoversMultipleActiveWindowsGoals()
    {
        using var workspace = new TempWorkspace();
        var codexHome = CreateCodexHomeWithGoals(
            workspace,
            ("019e7777-goal-a", "第一个 Windows goal", "active", "2026-06-01T09:01:00Z"),
            ("019e7777-goal-b", "第二个 Windows goal", "active", "2026-06-01T09:02:00Z"));

        var service = new LocalCodexHistoryService(codexHome);

        var goals = service.ReadGoals();

        AssertEqual(2, goals.Count, "both active windows goals recovered");
        AssertEqual("第二个 Windows goal", goals[0].Objective, "latest goal first");
        AssertEqual("第一个 Windows goal", goals[1].Objective, "older goal kept");
        AssertTrue(goals.All(goal => goal.Source == "windows-codex-history"), "goal source preserved for all");
    }

    public void CodexGatewayFallsBackToLocalHistory()
    {
        using var workspace = new TempWorkspace();
        var codexHome = workspace.CreateDirectory(".codex");
        var sessionsDir = Path.Combine(codexHome, "sessions", "2026", "05", "31");
        Directory.CreateDirectory(sessionsDir);

        var threadId = "019e8888-fallback";
        var rolloutPath = Path.Combine(sessionsDir, $"rollout-2026-05-31T10-00-00-{threadId}.jsonl");
        var indexLine = $"{{\"id\":\"{threadId}\",\"thread_name\":\"本地兜底线程\",\"updated_at\":\"2026-05-31T10:00:00Z\"}}";
        var metaLine = $"{{\"timestamp\":\"2026-05-31T10:00:00Z\",\"type\":\"session_meta\",\"payload\":{{\"id\":\"{threadId}\",\"timestamp\":\"2026-05-31T10:00:00Z\",\"cwd\":\"C:\\\\Users\\\\TestUser\\\\Desktop\\\\code\\\\dev\\\\codex_mobile_app\",\"originator\":\"Codex Desktop\",\"cli_version\":\"0.131.0-alpha.9\",\"source\":\"vscode\",\"thread_source\":\"user\",\"model_provider\":\"newapi\"}}}}";
        File.WriteAllText(
            Path.Combine(codexHome, "session_index.jsonl"),
            indexLine,
            Encoding.UTF8);
        File.WriteAllText(
            rolloutPath,
            metaLine,
            Encoding.UTF8);

        var client = new FakeCodexAppServerClient { Failure = new InvalidOperationException("app-server down") };
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(codexHome));

        var list = gateway.ListThreadsAsync().GetAwaiter().GetResult();
        var read = gateway.ReadThreadAsync(threadId).GetAwaiter().GetResult();

        AssertEqual("thread/list", list.Method, "list method preserved");
        AssertEqual("local-codex-history", list.Json.GetProperty("source").GetString(), "local history source");
        AssertEqual(threadId, list.Json.GetProperty("data")[0].GetProperty("id").GetString(), "fallback thread id");
        AssertEqual(threadId, read.Json.GetProperty("thread").GetProperty("id").GetString(), "fallback read thread id");
    }

    public void ConversationRelayStartsAndReusesCodexThreads()
    {
        using var workspace = new TempWorkspace();
        var clock = new ManualClock(DateTimeOffset.UtcNow);
        var conversations = new ConversationService(clock);
        var conversation = conversations.Create("Bridge setup", "project-1", "C:\\repo");
        var client = new FakeCodexAppServerClient();
        client.Enqueue("thread/start", new Dictionary<string, object?>
        {
            ["thread"] = new Dictionary<string, object?> { ["id"] = "thread-relay-1" },
        });
        client.Enqueue("turn/start", new Dictionary<string, object?>
        {
            ["turn"] = new Dictionary<string, object?> { ["id"] = "turn-relay-2" },
        });
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(workspace.CreateDirectory("empty-codex")));
        var relay = new ConversationCodexRelayService(conversations, gateway);

        var first = relay.SendUserMessageAsync(conversation.Id, "从手机启动真实 Codex 对话").GetAwaiter().GetResult();
        var second = relay.SendUserMessageAsync(conversation.Id, "从手机继续同一个 Codex 对话").GetAwaiter().GetResult();

        AssertEqual("thread-relay-1", first.Conversation.CodexThreadId, "first send binds created codex thread");
        AssertEqual("thread-relay-1", second.Conversation.CodexThreadId, "second send keeps same codex thread");
        AssertEqual("thread/start", client.Calls[0].Method, "first send starts thread");
        AssertEqual("turn/start", client.Calls[1].Method, "second send starts turn");
        var turnParams = (Dictionary<string, object?>)client.Calls[1].Parameters!;
        AssertEqual("thread-relay-1", turnParams["threadId"], "turn uses linked thread id");
        AssertEqual(2, second.Messages.Count(message => message.Role == "user"), "both mobile user messages are recorded locally");
    }

    public void ConversationRelayDoesNotFakeLocalMessagesWhenCodexSendFails()
    {
        using var workspace = new TempWorkspace();
        var clock = new ManualClock(DateTimeOffset.UtcNow);
        var conversations = new ConversationService(clock);
        var conversation = conversations.Create("Bridge setup", "project-1", "C:\\repo");
        var client = new FakeCodexAppServerClient { Failure = new InvalidOperationException("Not initialized") };
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(workspace.CreateDirectory("empty-codex")));
        var relay = new ConversationCodexRelayService(conversations, gateway);

        AssertThrows<InvalidOperationException>(
            () => relay.SendUserMessageAsync(conversation.Id, "这条消息不应假装发送成功").GetAwaiter().GetResult(),
            "failed codex send should surface as an error");

        var after = conversations.Get(conversation.Id);
        AssertEqual(0, after.Messages.Count, "failed send does not persist a fake local user bubble");
        AssertTrue(string.IsNullOrWhiteSpace(after.Conversation.CodexThreadId), "failed new send does not bind a fake codex thread");
    }

    public void ConversationEndpointReturnsErrorStatusWhenCodexSendFails()
    {
        var detail = new { ConversationId = "conv_1" };

        var result = ConversationEndpointHelpers.FailedSendResult(
            new InvalidOperationException("codex app-server unavailable"),
            detail);

        AssertTrue(
            result is IStatusCodeHttpResult status && status.StatusCode == StatusCodes.Status502BadGateway,
            "codex send failures must use a non-success status so mobile does not treat them as sent");
    }

    public void ConversationDetailExposesLocalPendingMessagesWithCodexThreadData()
    {
        using var workspace = new TempWorkspace();
        var clock = new ManualClock(DateTimeOffset.UtcNow);
        var conversations = new ConversationService(clock);
        var conversation = conversations.Create("Bridge setup", "project-1", "C:\\repo");
        conversations.AddMessage(conversation.Id, "user", "手机暂存消息");
        conversations.BindCodexThread(conversation.Id, "thread-real-1");
        var client = new FakeCodexAppServerClient();
        client.Enqueue("thread/read", new Dictionary<string, object?>
        {
            ["thread"] = new Dictionary<string, object?>
            {
                ["id"] = "thread-real-1",
                ["name"] = "真实 Codex 线程",
                ["cwd"] = "C:\\repo",
                ["turns"] = new object[]
                {
                    new Dictionary<string, object?>
                    {
                        ["items"] = new object[]
                        {
                            new Dictionary<string, object?>
                            {
                                ["type"] = "agentMessage",
                                ["text"] = "Windows Codex 真实回复",
                            },
                        },
                    },
                },
            },
        });
        var gateway = new CodexAppServerGateway(client, new LocalCodexHistoryService(workspace.CreateDirectory("empty-codex")));

        var detail = ConversationEndpointHelpers.ReadDetailAsync(conversation.Id, conversations, gateway, CancellationToken.None).GetAwaiter().GetResult();
        var json = JsonSerializer.SerializeToElement(detail);

        AssertEqual(1, json.GetProperty("Messages").GetArrayLength(), "bridge-local pending messages remain visible while thread read succeeds");
        AssertEqual("手机暂存消息", json.GetProperty("Messages")[0].GetProperty("Content").GetString(), "local pending user prompt exposed");
        AssertEqual("thread-real-1", json.GetProperty("CodexThread").GetProperty("thread").GetProperty("id").GetString(), "real codex thread is returned");
        AssertTrue(json.GetProperty("CodexThreadError").ValueKind == JsonValueKind.Null, "no codex thread error");
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

    public void NetworkInterfaceServicePrioritizesExplicitExternalBridgeUrls()
    {
        WithTemporaryEnvironment("CODEX_MOBILE_EXTERNAL_BRIDGE_URLS", "https://codex-phone.trycloudflare.com,not-a-url,http://203.0.113.44:5010/connect", () =>
        {
            var service = new NetworkInterfaceService(
                () =>
                [
                    IPAddress.Parse("127.0.0.1"),
                    IPAddress.Parse("10.250.236.241"),
                ],
                allowPublicBridgeHosts: false);

            var summary = service.ReadSummary("http", 5010);
            var preferred = ConnectPageService.SelectPreferredEndpoint(summary);
            var urls = ConnectPageService.SelectMobileBridgeUrls(summary, preferred);

            AssertEqual("external", preferred.Scope, "external URL should be preferred");
            AssertEqual("https://codex-phone.trycloudflare.com", preferred.Url, "first external URL preferred");
            AssertTrue(summary.Endpoints.Any(endpoint => endpoint.Url == "http://203.0.113.44:5010" && endpoint.Scope == "external"), "external URL strips /connect path");
            AssertTrue(urls.First() == "https://codex-phone.trycloudflare.com", "mobile candidates start with external tunnel");
            AssertTrue(urls.Contains("http://10.250.236.241:5010"), "LAN URL remains a fallback");
            AssertTrue(summary.Warnings.Any(warning => warning.Contains("not-a-url", StringComparison.Ordinal)), "invalid external URL warning");
        });
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

    public void SyncServiceRestoresWindowsGoalWhenBridgeStartsEmpty()
    {
        using var workspace = new TempWorkspace();
        var codexHome = CreateCodexHomeWithGoal(
            workspace,
            "019e7777-goal-thread",
            "恢复 Windows 当前 goal 到手机面板",
            "active",
            "2026-06-01T09:10:00Z");
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 1, 9, 11, 0, TimeSpan.Zero));
        var service = new SyncStateService(clock, new LocalCodexHistoryService(codexHome));

        var snapshot = service.GetSnapshot();

        AssertEqual("恢复 Windows 当前 goal 到手机面板", snapshot.Goal?.Objective, "snapshot includes recovered goal");
        AssertEqual("windows-codex-history", snapshot.Goal?.Source, "snapshot preserves recovered source");
        AssertEqual(1, snapshot.Goals.Count, "single recovered goal is also listed");
        AssertTrue(snapshot.Events.Any(evt => evt.Type == "goal.recovered"), "recovery event visible to mobile");
    }

    public void SyncServiceRestoresMultipleWindowsGoalsWhenBridgeStartsEmpty()
    {
        using var workspace = new TempWorkspace();
        var codexHome = CreateCodexHomeWithGoals(
            workspace,
            ("019e7777-goal-a", "目录页也要显示第一个 goal", "active", "2026-06-01T09:10:00Z"),
            ("019e7777-goal-b", "目录页也要显示第二个 goal", "active", "2026-06-01T09:11:00Z"));
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 1, 9, 12, 0, TimeSpan.Zero));
        var service = new SyncStateService(clock, new LocalCodexHistoryService(codexHome));

        var snapshot = service.GetSnapshot();

        AssertEqual(2, snapshot.Goals.Count, "mobile snapshot exposes all recovered windows goals");
        AssertEqual("目录页也要显示第二个 goal", snapshot.Goal?.Objective, "latest goal remains primary");
        AssertTrue(snapshot.Goals.Any(goal => goal.Objective == "目录页也要显示第一个 goal"), "first goal present");
        AssertTrue(snapshot.Goals.Any(goal => goal.Objective == "目录页也要显示第二个 goal"), "second goal present");
        AssertEqual(2, snapshot.Events.Count(evt => evt.Type == "goal.recovered"), "each recovered goal emits a visible event");
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

    public void SyncServiceRecordsCodexTurnProgressEvents()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 2, 14, 0, 0, TimeSpan.Zero));
        var service = new SyncStateService(clock);

        service.RecordEvent(
            "codex.turn.accepted",
            "turn_job_1",
            new Dictionary<string, object?>
            {
                ["threadId"] = "thread-1",
                ["message"] = "已提交到 Bridge",
            });
        clock.Advance(TimeSpan.FromSeconds(1));
        service.RecordEvent(
            "codex.appserver.notification",
            "turn/completed",
            new Dictionary<string, object?>
            {
                ["threadId"] = "thread-1",
                ["method"] = "turn/completed",
            });

        var snapshot = service.GetSnapshot();

        AssertEqual(2, snapshot.Events.Count, "two progress events recorded");
        AssertTrue(snapshot.Events.Any(evt => evt.Type == "codex.turn.accepted"), "accepted event visible");
        var completed = snapshot.Events.Single(evt => evt.Type == "codex.appserver.notification");
        AssertEqual("turn/completed", completed.EntityId, "notification method is entity id");
        AssertEqual("thread-1", completed.Payload["threadId"]?.ToString(), "payload preserves thread id");
    }

    public void SyncServiceRecordsMobileUserPromptsForThreadOverlay()
    {
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 2, 16, 30, 0, TimeSpan.Zero));
        var service = new SyncStateService(clock);

        service.RecordMobileUserMessage("thread-phone", "手机发出的消息", "turn_job_1");
        var snapshot = service.GetSnapshot();
        var overlays = service.ListMobileUserMessages("thread-phone");

        AssertEqual(1, overlays.Count, "mobile prompt overlay count");
        AssertEqual("thread-phone", overlays.Single().ThreadId, "overlay thread id");
        AssertEqual("user", overlays.Single().Role, "overlay role");
        AssertEqual("手机发出的消息", overlays.Single().Text, "overlay text");
        AssertTrue(snapshot.Events.Any(evt => evt.Type == "codex.turn.mobile_user" && evt.EntityId == "thread-phone"), "mobile user event visible");
    }

    public void CodexNotificationMapperAssignsActiveThreadToStreamingDeltas()
    {
        using var deltaDocument = JsonDocument.Parse(
            "{\"jsonrpc\":\"2.0\",\"method\":\"item/agentMessage/delta\",\"params\":{\"delta\":\"正在生成\"}}");
        var delta = CodexNotificationMapper.Map(deltaDocument.RootElement, "thread-lifecycle");

        AssertEqual("thread-lifecycle", delta.EntityId, "fallback thread becomes entity id for unscoped delta");
        AssertEqual("thread-lifecycle", delta.Payload["threadId"]?.ToString(), "fallback thread id is added to delta payload");
        AssertEqual("正在生成", delta.Payload["delta"]?.ToString(), "delta text is preserved");
        AssertFalse(delta.ClearsActiveThread, "streaming delta keeps active thread context");

        using var completedDocument = JsonDocument.Parse(
            "{\"jsonrpc\":\"2.0\",\"method\":\"turn/completed\",\"params\":{}}");
        var completed = CodexNotificationMapper.Map(completedDocument.RootElement, "thread-lifecycle");

        AssertEqual("thread-lifecycle", completed.EntityId, "completion without ids is still scoped to active thread");
        AssertEqual("thread-lifecycle", completed.Payload["threadId"]?.ToString(), "completion payload receives active thread id");
        AssertTrue(completed.ClearsActiveThread, "turn completion clears active thread context");
    }

    public void CodexGatewayRecordsMobileVisibleTurnLifecycle()
    {
        using var workspace = new TempWorkspace();
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 2, 14, 10, 0, TimeSpan.Zero));
        var sync = new SyncStateService(clock);
        var client = new FakeCodexAppServerClient();
        client.Enqueue("turn/start", new Dictionary<string, object?> { ["ok"] = true });
        var gateway = new CodexAppServerGateway(
            client,
            new LocalCodexHistoryService(workspace.CreateDirectory("empty-codex")),
            sync);

        gateway.StartTurnAsync(new StartCodexTurnRequest("thread-lifecycle", "继续处理")).GetAwaiter().GetResult();
        var events = sync.GetSnapshot().Events;

        AssertTrue(events.Any(evt => evt.Type == "codex.turn.starting" && evt.EntityId == "thread-lifecycle"), "turn start event visible");
        AssertTrue(events.Any(evt => evt.Type == "codex.turn.dispatched" && evt.EntityId == "thread-lifecycle"), "turn dispatched event visible");
    }

    public void CodexGatewayOverlaysMobileUserPromptsOntoThreadReads()
    {
        using var workspace = new TempWorkspace();
        var codexHome = CreateCodexHomeWithThread(
            workspace,
            "019e-mobile-overlay",
            "手机 overlay 线程",
            [
                "{\"timestamp\":\"2026-06-02T16:20:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"agent_message\",\"message\":\"Windows 旧回复\"}}",
            ]);
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 2, 16, 31, 0, TimeSpan.Zero));
        var sync = new SyncStateService(clock);
        sync.RecordMobileUserMessage("019e-mobile-overlay", "手机端发出的 USER", "turn_job_mobile");
        var gateway = new CodexAppServerGateway(
            new FakeCodexAppServerClient(),
            new LocalCodexHistoryService(codexHome),
            sync);

        var read = gateway.ReadThreadAsync("019e-mobile-overlay").GetAwaiter().GetResult();
        var items = read.Json.GetProperty("thread").GetProperty("turns")[0].GetProperty("items");

        AssertEqual(2, items.GetArrayLength(), "mobile prompt is overlaid onto local thread items");
        AssertEqual("agentMessage", items[0].GetProperty("type").GetString(), "existing history remains first");
        AssertEqual("userMessage", items[1].GetProperty("type").GetString(), "mobile prompt becomes a user message");
        AssertEqual("手机端发出的 USER", items[1].GetProperty("content")[0].GetProperty("text").GetString(), "mobile prompt text visible");
        AssertEqual("mobile-bridge", items[1].GetProperty("source").GetString(), "overlay source is explicit");
    }

    public void CodexGatewayDeduplicatesMobileUserPromptOverlayWhenHistoryCatchesUp()
    {
        using var workspace = new TempWorkspace();
        var codexHome = CreateCodexHomeWithThread(
            workspace,
            "019e-mobile-dedupe",
            "手机 overlay 去重",
            [
                "{\"timestamp\":\"2026-06-02T16:20:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"message\":\"手机端发出的 USER\"}}",
                "{\"timestamp\":\"2026-06-02T16:21:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"agent_message\",\"message\":\"Windows 回复\"}}",
            ]);
        var clock = new ManualClock(new DateTimeOffset(2026, 6, 2, 16, 32, 0, TimeSpan.Zero));
        var sync = new SyncStateService(clock);
        sync.RecordMobileUserMessage("019e-mobile-dedupe", "手机端发出的 USER", "turn_job_mobile");
        var gateway = new CodexAppServerGateway(
            new FakeCodexAppServerClient(),
            new LocalCodexHistoryService(codexHome),
            sync);

        var read = gateway.ReadThreadAsync("019e-mobile-dedupe").GetAwaiter().GetResult();
        var items = read.Json.GetProperty("thread").GetProperty("turns")[0].GetProperty("items");

        AssertEqual(2, items.GetArrayLength(), "duplicate overlay is suppressed after history includes the user prompt");
        AssertEqual(1, items.EnumerateArray().Count(item => item.GetProperty("type").GetString() == "userMessage"), "only one user prompt remains visible");
    }

    public void BridgeHostingDefaultsToAllInterfacesForPhoneAccess()
    {
        WithTemporaryEnvironment("ASPNETCORE_URLS", null, () =>
            WithTemporaryEnvironment("CODEX_MOBILE_BRIDGE_URLS", null, () =>
                WithTemporaryEnvironment("CODEX_MOBILE_BIND_URLS", null, () =>
                {
                    var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();

                    var urls = BridgeHosting.ResolveUrls(configuration, port => port == 5010, () => 6042);

                    AssertEqual("http://0.0.0.0:5010", urls.Single(), "default bind url");
                })));
    }

    public void BridgeHostingKeepsDefaultPortFixedWhenOccupied()
    {
        WithTemporaryEnvironment("ASPNETCORE_URLS", null, () =>
            WithTemporaryEnvironment("CODEX_MOBILE_BRIDGE_URLS", null, () =>
                WithTemporaryEnvironment("CODEX_MOBILE_BIND_URLS", null, () =>
                {
                    var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();

                    var urls = BridgeHosting.ResolveUrls(configuration, port => false, () => 6042);

                    AssertEqual("http://0.0.0.0:5010", urls.Single(), "default port stays fixed");
                    AssertEqual(5010, BridgeHosting.ResolvePort(urls), "default port is reported consistently");
                })));
    }

    public void BridgeHostingAcceptsExplicitBindUrls()
    {
        WithTemporaryEnvironment("ASPNETCORE_URLS", null, () =>
            WithTemporaryEnvironment("CODEX_MOBILE_BRIDGE_URLS", "http://127.0.0.1:5011;http://0.0.0.0:5011", () =>
                WithTemporaryEnvironment("CODEX_MOBILE_BIND_URLS", null, () =>
                {
                    var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();

                    var urls = BridgeHosting.ResolveUrls(configuration, port => false, () => 6042);

                    AssertEqual(2, urls.Length, "explicit url count");
                    AssertTrue(urls.Contains("http://0.0.0.0:5011"), "explicit all-interface url");
                })));
    }

    public void BridgeHostingKeepsExplicitConfiguredUrlsEvenWhenOccupied()
    {
        WithTemporaryEnvironment("ASPNETCORE_URLS", "http://127.0.0.1:5010", () =>
            WithTemporaryEnvironment("CODEX_MOBILE_BRIDGE_URLS", null, () =>
                WithTemporaryEnvironment("CODEX_MOBILE_BIND_URLS", null, () =>
                {
                    var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();

                    var urls = BridgeHosting.ResolveUrls(configuration, port => false, () => 6042);

                    AssertEqual("http://127.0.0.1:5010", urls.Single(), "explicit ASPNETCORE_URLS is preserved");
                })));
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

    private static string CreateCodexHomeWithGoal(
        TempWorkspace workspace,
        string threadId,
        string objective,
        string status,
        string updatedAt)
    {
        var codexHome = workspace.CreateDirectory(".codex-goal");
        var sessionsDir = Path.Combine(codexHome, "sessions", "2026", "06", "01");
        Directory.CreateDirectory(sessionsDir);

        var rolloutPath = Path.Combine(sessionsDir, $"rollout-2026-06-01T09-00-00-{threadId}.jsonl");
        var indexLine = $"{{\"id\":\"{threadId}\",\"thread_name\":\"Windows goal thread\",\"updated_at\":\"{updatedAt}\"}}";
        var metaLine = $"{{\"timestamp\":\"2026-06-01T09:00:00Z\",\"type\":\"session_meta\",\"payload\":{{\"id\":\"{threadId}\",\"timestamp\":\"2026-06-01T09:00:00Z\",\"cwd\":\"C:\\\\Users\\\\TestUser\\\\Desktop\\\\code\\\\dev\\\\codex_mobile_app\",\"source\":\"vscode\",\"model_provider\":\"newapi\"}}}}";
        var goalLine = JsonSerializer.Serialize(new
        {
            timestamp = updatedAt,
            type = "event_msg",
            payload = new
            {
                type = "thread_goal_updated",
                threadId,
                goal = new
                {
                    threadId,
                    objective,
                    status,
                    createdAt = "2026-06-01T09:00:00Z",
                    updatedAt,
                },
            },
        });

        File.WriteAllText(Path.Combine(codexHome, "session_index.jsonl"), indexLine, Encoding.UTF8);
        File.WriteAllText(
            rolloutPath,
            string.Join(Environment.NewLine, new[] { metaLine, goalLine }),
            Encoding.UTF8);
        return codexHome;
    }

    private static string CreateCodexHomeWithThread(
        TempWorkspace workspace,
        string threadId,
        string title,
        IReadOnlyList<string> rolloutLines)
    {
        var codexHome = workspace.CreateDirectory($".codex-{Guid.NewGuid():N}");
        var sessionsDir = Path.Combine(codexHome, "sessions", "2026", "06", "02");
        Directory.CreateDirectory(sessionsDir);

        var rolloutPath = Path.Combine(sessionsDir, $"rollout-2026-06-02T16-20-00-{threadId}.jsonl");
        var indexLine = JsonSerializer.Serialize(new
        {
            id = threadId,
            thread_name = title,
            updated_at = "2026-06-02T16:20:00Z",
        });
        var metaLine = JsonSerializer.Serialize(new
        {
            timestamp = "2026-06-02T16:20:00Z",
            type = "session_meta",
            payload = new
            {
                id = threadId,
                timestamp = "2026-06-02T16:20:00Z",
                cwd = @"C:\Users\TestUser\Desktop\code\dev\codex_mobile_app",
                source = "vscode",
                thread_source = "user",
                model_provider = "newapi",
            },
        });

        File.WriteAllText(Path.Combine(codexHome, "session_index.jsonl"), indexLine, Encoding.UTF8);
        File.WriteAllText(
            rolloutPath,
            string.Join(Environment.NewLine, new[] { metaLine }.Concat(rolloutLines)),
            Encoding.UTF8);
        return codexHome;
    }

    private static string CreateCodexHomeWithGoals(
        TempWorkspace workspace,
        params (string ThreadId, string Objective, string Status, string UpdatedAt)[] goals)
    {
        var codexHome = workspace.CreateDirectory(".codex-goals");
        var sessionsDir = Path.Combine(codexHome, "sessions", "2026", "06", "01");
        Directory.CreateDirectory(sessionsDir);

        var indexLines = new List<string>();
        foreach (var goal in goals)
        {
            var rolloutPath = Path.Combine(sessionsDir, $"rollout-2026-06-01T09-00-00-{goal.ThreadId}.jsonl");
            indexLines.Add($"{{\"id\":\"{goal.ThreadId}\",\"thread_name\":\"Windows goal thread\",\"updated_at\":\"{goal.UpdatedAt}\"}}");
            var metaLine = $"{{\"timestamp\":\"2026-06-01T09:00:00Z\",\"type\":\"session_meta\",\"payload\":{{\"id\":\"{goal.ThreadId}\",\"timestamp\":\"2026-06-01T09:00:00Z\",\"cwd\":\"C:\\\\Users\\\\TestUser\\\\Desktop\\\\code\\\\dev\\\\codex_mobile_app\",\"source\":\"vscode\",\"model_provider\":\"newapi\"}}}}";
            var goalLine = JsonSerializer.Serialize(new
            {
                timestamp = goal.UpdatedAt,
                type = "event_msg",
                payload = new
                {
                    type = "thread_goal_updated",
                    threadId = goal.ThreadId,
                    goal = new
                    {
                        threadId = goal.ThreadId,
                        objective = goal.Objective,
                        status = goal.Status,
                        createdAt = "2026-06-01T09:00:00Z",
                        updatedAt = goal.UpdatedAt,
                    },
                },
            });

            File.WriteAllText(
                rolloutPath,
                string.Join(Environment.NewLine, new[] { metaLine, goalLine }),
                Encoding.UTF8);
        }

        File.WriteAllText(Path.Combine(codexHome, "session_index.jsonl"), string.Join(Environment.NewLine, indexLines), Encoding.UTF8);
        return codexHome;
    }

    private static void AssertTrue(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
    }

    private static void AssertFalse(bool condition, string message) => AssertTrue(!condition, message);

    private static bool IsLocalOnlyRequest(string path, string host, IPAddress remoteAddress)
    {
        var context = new DefaultHttpContext();
        context.Request.Path = new PathString(path);
        context.Request.Host = new HostString(host);
        context.Connection.RemoteIpAddress = remoteAddress;
        return BridgeAccessPolicy.IsLocalOnlyRequest(context);
    }

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

        if (response.Response is Exception exception)
        {
            throw exception;
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
