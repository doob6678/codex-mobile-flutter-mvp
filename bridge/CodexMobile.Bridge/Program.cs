using CodexMobile.Bridge.Hubs;
using CodexMobile.Bridge.Models;
using CodexMobile.Bridge.Services;
using Microsoft.Extensions.FileProviders;
using System.Text.Json;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);
var bindUrls = BridgeHosting.ResolveUrls(builder.Configuration);
builder.WebHost.UseUrls(bindUrls);

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
});

builder.Services.AddSingleton<IClock, SystemClock>();
builder.Services.AddSingleton<DeviceTokenStore>();
builder.Services.AddSingleton(sp =>
{
    var store = new ProjectStore();
    var configuration = sp.GetRequiredService<IConfiguration>();
    var codexConfigPath = configuration["Codex:ConfigPath"]
        ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".codex",
            "config.toml");
    store.AddTrustedProjectsFromCodexConfig(codexConfigPath);
    store.AddConfiguredProjects(configuration["DefaultProjects"]);
    store.AddConfiguredProjects(Environment.GetEnvironmentVariable("CODEX_MOBILE_DEFAULT_PROJECTS"));
    return store;
});
builder.Services.AddSingleton<FileWorkspaceService>();
builder.Services.AddSingleton<PairingService>();
builder.Services.AddSingleton<AuditLog>();
builder.Services.AddSingleton<CommandService>();
builder.Services.AddSingleton<ConversationService>();
builder.Services.AddSingleton<ConversationCodexRelayService>();
builder.Services.AddSingleton<NetworkInterfaceService>();
builder.Services.AddSingleton<ConnectPageService>();
builder.Services.AddSingleton<SyncStateService>();
builder.Services.AddSingleton<LocalCodexHistoryService>();
builder.Services.AddSingleton<ICodexAppServerClient, StdioCodexAppServerClient>();
builder.Services.AddSingleton<CodexAppServerGateway>();
builder.Services.AddSingleton(sp =>
{
    var root = builder.Configuration["RepositoryRoot"] ?? Directory.GetCurrentDirectory();
    return new ProtocolAssetService(root);
});
builder.Services.AddSignalR();

var app = builder.Build();
var streamJsonOptions = new JsonSerializerOptions(JsonSerializerDefaults.Web);
streamJsonOptions.Converters.Add(new JsonStringEnumConverter());

app.Lifetime.ApplicationStarted.Register(() =>
{
    var port = BridgeHosting.ResolvePort(bindUrls);
    var summary = app.Services.GetRequiredService<NetworkInterfaceService>().ReadSummary(
        bindUrls.FirstOrDefault(url => url.StartsWith("https", StringComparison.OrdinalIgnoreCase)) is not null
            ? "https"
            : "http",
        port);
    var guide = BridgeStartupExperience.CreateGuide(
        summary.Scheme,
        summary.Port,
        summary);
    BridgeStartupExperience.PrintAndOpen(guide);
});

var ipadWebRoot = Path.Combine(AppContext.BaseDirectory, "wwwroot", "ipad");
if (Directory.Exists(ipadWebRoot))
{
    app.Use(async (context, next) =>
    {
        if (string.Equals(context.Request.Path.Value, "/ipad", StringComparison.OrdinalIgnoreCase))
        {
            context.Response.Redirect("/ipad/");
            return;
        }

        await next();
    });
    app.UseDefaultFiles(new DefaultFilesOptions
    {
        FileProvider = new PhysicalFileProvider(ipadWebRoot),
        RequestPath = "/ipad",
        DefaultFileNames = ["index.html"],
    });
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new PhysicalFileProvider(ipadWebRoot),
        RequestPath = "/ipad",
    });
}

app.Use(async (context, next) =>
{
    if (BridgeAccessPolicy.IsLocalOnlyEndpoint(context.Request.Path))
    {
        if (!BridgeAccessPolicy.IsLocalOnlyRequest(context))
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsJsonAsync(new
            {
                error = "This endpoint is Windows-local only. Open http://127.0.0.1:5010/connect on the Windows PC.",
            });
            return;
        }

        await next();
        return;
    }

    if (BridgeEndpointPolicy.IsPublicEndpoint(context.Request.Path))
    {
        await next();
        return;
    }

    var tokenStore = context.RequestServices.GetRequiredService<DeviceTokenStore>();
    var token = BridgeEndpointPolicy.ReadBearerToken(context);

    if (!tokenStore.Validate(token))
    {
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await context.Response.WriteAsJsonAsync(new { error = "Bridge pairing token is missing, expired, or revoked." });
        return;
    }

    await next();
});

app.MapGet("/", () => Results.Redirect("/health"));
app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    service = "codex-mobile-bridge",
    time = DateTimeOffset.UtcNow,
}));
app.MapGet("/security/status", () => Results.Ok(BridgeEndpointPolicy.ReadSecurityStatus()));

app.MapGet("/protocol/summary", (ProtocolAssetService protocol) => Results.Ok(protocol.ReadSummary()));
app.MapGet("/network/interfaces", (HttpContext context, NetworkInterfaceService network) =>
{
    var port = context.Request.Host.Port
        ?? (string.Equals(context.Request.Scheme, "https", StringComparison.OrdinalIgnoreCase) ? 443 : 80);
    return Results.Ok(network.ReadSummary(context.Request.Scheme, port));
});
app.MapGet("/connect", (HttpContext context, ConnectPageService connectPage) =>
{
    var port = context.Request.Host.Port
        ?? (string.Equals(context.Request.Scheme, "https", StringComparison.OrdinalIgnoreCase) ? 443 : 80);
    var page = connectPage.Create(context.Request.Scheme, port, TimeSpan.FromMinutes(5));
    return Results.Content(page.Html, "text/html; charset=utf-8");
});
app.MapGet("/sync/state", (SyncStateService sync) => Results.Ok(sync.GetSnapshot()));
app.MapGet("/sync/stream", async (HttpContext context, SyncStateService sync) =>
{
    context.Response.Headers.ContentType = "text/event-stream";
    context.Response.Headers.CacheControl = "no-cache";
    await foreach (var snapshot in sync.StreamSnapshots(context.RequestAborted))
    {
        var json = JsonSerializer.Serialize(snapshot, streamJsonOptions);
        await context.Response.WriteAsync($"event: sync.state\ndata: {json}\n\n", context.RequestAborted);
        await context.Response.Body.FlushAsync(context.RequestAborted);
    }
});
app.MapGet("/goal", (SyncStateService sync) => Results.Ok(sync.CurrentGoal()));
app.MapGet("/goals", (SyncStateService sync) => Results.Ok(sync.ListGoals()));
app.MapPost("/goal", (UpdateGoalRequest request, SyncStateService sync) =>
    Results.Ok(sync.UpdateGoal(request)));
app.MapGet("/tasks", (SyncStateService sync) => Results.Ok(sync.ListTasks()));
app.MapPost("/tasks", (CreateCodexTaskRequest request, SyncStateService sync) =>
{
    var task = sync.CreateTask(request);
    return Results.Created($"/tasks/{task.Id}", task);
});
app.MapPost("/tasks/{id}/progress", (string id, UpdateCodexTaskProgressRequest request, SyncStateService sync) =>
    Results.Ok(sync.UpdateTaskProgress(id, request)));
app.MapGet("/codex/status", async (CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await codex.GetStatusAsync(cancellationToken)));
app.MapGet("/codex/config", async (CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    await SafeCodexResult(() => codex.ReadConfigAsync(cancellationToken)));
app.MapGet("/codex/account", async (CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    await SafeCodexResult(() => codex.ReadAccountAsync(cancellationToken)));
app.MapGet("/codex/threads", async (CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    await SafeCodexResult(() => codex.ListThreadsAsync(cancellationToken)));
app.MapGet("/codex/threads/{threadId}", async (string threadId, CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    await SafeCodexResult(() => codex.ReadThreadAsync(threadId, cancellationToken)));
app.MapPost("/codex/threads", async (StartCodexThreadRequest request, CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    await SafeCodexResult(() => codex.StartThreadAsync(request, cancellationToken)));
app.MapPost("/codex/turns", (StartCodexTurnRequest request, CodexAppServerGateway codex, SyncStateService sync) =>
{
    var jobId = $"turn_job_{Guid.NewGuid():N}";
    Console.WriteLine($"[{DateTimeOffset.Now:O}] [{jobId}] accepted /codex/turns threadId={request.ThreadId} promptChars={request.Prompt?.Length ?? 0}");
    if (!string.IsNullOrWhiteSpace(request.ThreadId) && !string.IsNullOrWhiteSpace(request.Prompt))
    {
        sync.RecordMobileUserMessage(request.ThreadId, request.Prompt, jobId);
    }

    sync.RecordEvent(
        "codex.turn.accepted",
        jobId,
        new Dictionary<string, object?>
        {
            ["jobId"] = jobId,
            ["threadId"] = request.ThreadId,
            ["promptChars"] = request.Prompt?.Length ?? 0,
            ["message"] = "Bridge 已收到手机消息，正在后台投递到 Windows Codex",
        });
    _ = Task.Run(async () =>
    {
        var started = DateTimeOffset.UtcNow;
        try
        {
            Console.WriteLine($"[{DateTimeOffset.Now:O}] [{jobId}] dispatch starting");
            sync.RecordEvent(
                "codex.turn.dispatch.starting",
                jobId,
                new Dictionary<string, object?>
                {
                    ["jobId"] = jobId,
                    ["threadId"] = request.ThreadId,
                    ["message"] = "Bridge 正在调用 Windows Codex app-server",
                });
            await codex.StartTurnAsync(request, CancellationToken.None);
            Console.WriteLine($"[{DateTimeOffset.Now:O}] [{jobId}] dispatch completed elapsedMs={(DateTimeOffset.UtcNow - started).TotalMilliseconds:0}");
            sync.RecordEvent(
                "codex.turn.dispatch.completed",
                jobId,
                new Dictionary<string, object?>
                {
                    ["jobId"] = jobId,
                    ["threadId"] = request.ThreadId,
                    ["elapsedMs"] = (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
                    ["message"] = "Bridge 已完成投递，手机将继续刷新同一线程历史",
                });
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[{DateTimeOffset.Now:O}] [{jobId}] dispatch failed elapsedMs={(DateTimeOffset.UtcNow - started).TotalMilliseconds:0}: {ex}");
            sync.RecordEvent(
                "codex.turn.dispatch.failed",
                jobId,
                new Dictionary<string, object?>
                {
                    ["jobId"] = jobId,
                    ["threadId"] = request.ThreadId,
                    ["elapsedMs"] = (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
                    ["error"] = ex.Message,
                    ["message"] = "Bridge 投递失败，详情见 Windows 控制台日志",
                });
        }
    });

    return Results.Ok(new
    {
        Sent = true,
        Accepted = true,
        Queued = true,
        JobId = jobId,
        request.ThreadId,
        Message = "Bridge accepted the mobile prompt and is dispatching it to Windows Codex in the background.",
    });
});
app.MapPost("/codex/raw", async (CodexAppServerRawRequest request, CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await codex.CallAsync(request.Method, request.Params, cancellationToken)));

app.MapPost("/pairing/start", (PairingService pairing) => Results.Ok(pairing.Start(TimeSpan.FromMinutes(5))));
app.MapPost("/pairing/complete", (PairingCompleteRequest request, PairingService pairing) =>
{
    try
    {
        return Results.Ok(pairing.Complete(request.Code, request.ChallengeId));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});
app.MapGet("/pairing/tokens", (HttpContext context, DeviceTokenStore tokenStore) =>
    Results.Ok(new { tokens = tokenStore.ListActive(BridgeEndpointPolicy.ReadBearerToken(context)) }));
app.MapPost("/pairing/tokens/{fingerprint}/revoke", (string fingerprint, DeviceTokenStore tokenStore) =>
    tokenStore.RevokeByFingerprint(fingerprint)
        ? Results.Ok(new { revoked = true })
        : Results.NotFound(new { error = "Pairing token was not found." }));

app.MapGet("/projects", (ProjectStore projects) => Results.Ok(projects.ListProjects()));
app.MapPost("/projects", (AddProjectRequest request, ProjectStore projects) =>
{
    var project = projects.AddProject(request.Name, request.RootPath);
    return Results.Created($"/projects/{project.Id}", project);
});

app.MapGet("/files/list", (string projectId, string? path, FileWorkspaceService files) =>
    FileEndpointHelpers.SafeFileResult(() => files.List(projectId, path ?? ".")));
app.MapGet("/files/read", (string projectId, string path, FileWorkspaceService files) =>
    FileEndpointHelpers.SafeFileResult(() => files.ReadText(projectId, path)));
app.MapGet("/files/download", (string projectId, string path, FileWorkspaceService files) =>
    FileEndpointHelpers.SafeFileResult(() => files.Download(projectId, path)));
app.MapGet("/files/hash", (string projectId, string path, FileWorkspaceService files) =>
    FileEndpointHelpers.SafeFileResult(() => files.Hash(projectId, path)));
app.MapPost("/files/patch", (FilePatchRequest request, FileWorkspaceService files) =>
    Results.Ok(files.ApplyPatch(request)));

app.MapGet("/conversations", (ConversationService conversations) =>
    Results.Ok(ConversationEndpointHelpers.ListSummaries(conversations)));
app.MapPost("/conversations", (CreateConversationRequest request, ConversationService conversations) =>
{
    var conversation = conversations.Create(request.Title, request.ProjectId, request.WorkingDirectory);
    return Results.Created($"/conversations/{conversation.Id}", conversation);
});
app.MapGet("/conversations/{id}", async (string id, ConversationService conversations, CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await ConversationEndpointHelpers.ReadDetailAsync(id, conversations, codex, cancellationToken)));
app.MapPost("/conversations/{id}/messages", async (string id, AddMessageRequest request, ConversationService conversations, ConversationCodexRelayService relay, CodexAppServerGateway codex, SyncStateService sync, CancellationToken cancellationToken) =>
{
    try
    {
        if (string.Equals(request.Role, "user", StringComparison.OrdinalIgnoreCase))
        {
            var content = request.Content ?? "";
            conversations.AddMessage(id, "user", content);
            var jobId = $"conversation_job_{Guid.NewGuid():N}";
            Console.WriteLine($"[{DateTimeOffset.Now:O}] [{jobId}] accepted conversation message conversationId={id} chars={content.Length}");
            sync.RecordEvent(
                "codex.conversation.accepted",
                jobId,
                new Dictionary<string, object?>
                {
                    ["jobId"] = jobId,
                    ["conversationId"] = id,
                    ["promptChars"] = content.Length,
                    ["message"] = "Bridge 会话消息已进入后台发送队列",
                });
            _ = Task.Run(async () =>
            {
                var started = DateTimeOffset.UtcNow;
                try
                {
                    Console.WriteLine($"[{DateTimeOffset.Now:O}] [{jobId}] conversation dispatch starting");
                    sync.RecordEvent(
                        "codex.conversation.dispatch.starting",
                        jobId,
                        new Dictionary<string, object?>
                        {
                            ["jobId"] = jobId,
                            ["conversationId"] = id,
                            ["message"] = "Bridge 正在把会话消息投递到 Windows Codex",
                        });
                    await relay.SendUserMessageAsync(id, content, CancellationToken.None, recordLocalMessage: false);
                    Console.WriteLine($"[{DateTimeOffset.Now:O}] [{jobId}] conversation dispatch completed elapsedMs={(DateTimeOffset.UtcNow - started).TotalMilliseconds:0}");
                    sync.RecordEvent(
                        "codex.conversation.dispatch.completed",
                        jobId,
                        new Dictionary<string, object?>
                        {
                            ["jobId"] = jobId,
                            ["conversationId"] = id,
                            ["elapsedMs"] = (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
                            ["message"] = "Bridge 会话已完成投递，手机将继续刷新回复",
                        });
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"[{DateTimeOffset.Now:O}] [{jobId}] conversation dispatch failed elapsedMs={(DateTimeOffset.UtcNow - started).TotalMilliseconds:0}: {ex}");
                    sync.RecordEvent(
                        "codex.conversation.dispatch.failed",
                        jobId,
                        new Dictionary<string, object?>
                        {
                            ["jobId"] = jobId,
                            ["conversationId"] = id,
                            ["elapsedMs"] = (long)(DateTimeOffset.UtcNow - started).TotalMilliseconds,
                            ["error"] = ex.Message,
                            ["message"] = "Bridge 会话投递失败，详情见 Windows 控制台日志",
                        });
                }
            });
        }
        else
        {
            conversations.AddMessage(id, request.Role, request.Content);
        }

        return Results.Ok(await ConversationEndpointHelpers.ReadDetailAsync(id, conversations, codex, cancellationToken));
    }
    catch (Exception ex)
    {
        var detail = await ConversationEndpointHelpers.ReadDetailAsync(id, conversations, codex, cancellationToken);
        return ConversationEndpointHelpers.FailedSendResult(ex, detail);
    }
});

app.MapGet("/approvals", (ConversationService conversations) => Results.Ok(conversations.ListApprovals()));
app.MapPost("/approvals/{id}/resolve", (string id, ResolveApprovalRequest request, ConversationService conversations) =>
    Results.Ok(conversations.ResolveApproval(id, request.Decision)));

app.MapGet("/audit", (AuditLog audit) => Results.Ok(audit.List()));
app.MapPost("/commands/preview", (CommandRequest request, CommandService commands) => Results.Ok(commands.Preview(request)));
app.MapPost("/commands/run", async (CommandRequest request, CommandService commands, CancellationToken cancellationToken) =>
    Results.Ok(await commands.RunAsync(request, cancellationToken)));

app.MapHub<BridgeHub>("/hubs/events");

app.Run();

static async Task<IResult> SafeCodexResult(Func<Task<CodexAppServerJsonResponse>> action)
{
    try
    {
        return Results.Ok(await action());
    }
    catch (Exception ex)
    {
        return Results.Json(new
        {
            Ok = false,
            Available = false,
            Error = ex.Message,
        }, statusCode: StatusCodes.Status502BadGateway);
    }
}

public partial class Program;

public static class FileEndpointHelpers
{
    public static IResult SafeFileResult<T>(Func<T> action)
    {
        try
        {
            return Results.Ok(action());
        }
        catch (Exception ex) when (ex is UnauthorizedAccessException or DirectoryNotFoundException or FileNotFoundException or ArgumentException or KeyNotFoundException)
        {
            return Results.Json(new
            {
                Ok = false,
                Error = ex.Message,
            }, statusCode: StatusCodes.Status400BadRequest);
        }
    }
}

public static class BridgeEndpointPolicy
{
    private static readonly string[] LocalOnlyEndpoints =
    [
        "/connect",
        "/pairing/start",
    ];

    private static readonly string[] PublicEndpoints =
    [
        "/health",
        "/security/status",
        "/ipad",
        "/pairing/complete",
        "/protocol",
    ];

    public static bool IsPublicEndpoint(PathString path)
    {
        return path.StartsWithSegments("/health", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/security/status", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/ipad", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/pairing/complete", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/protocol", StringComparison.OrdinalIgnoreCase);
    }

    public static BridgeSecurityStatus ReadSecurityStatus() => new(
        PairingRequiresChallengeId: true,
        LocalOnlyEndpoints,
        PublicEndpoints);

    public static string? ReadBearerToken(HttpContext context)
    {
        var authorization = context.Request.Headers.Authorization.ToString();
        return authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
            ? authorization["Bearer ".Length..].Trim()
            : null;
    }
}

public static class ConversationEndpointHelpers
{
    public static IResult FailedSendResult(Exception exception, object detail)
    {
        var statusCode = exception is ArgumentException or KeyNotFoundException
            ? StatusCodes.Status400BadRequest
            : StatusCodes.Status502BadGateway;

        return Results.Json(new
        {
            Sent = false,
            Error = exception.Message,
            Detail = detail,
        }, statusCode: statusCode);
    }

    public static IReadOnlyList<object> ListSummaries(ConversationService conversations)
    {
        return conversations.List()
            .Select(conversation =>
            {
                var snapshot = conversations.Get(conversation.Id);
                var latest = snapshot.Messages
                    .OrderByDescending(message => message.CreatedAt)
                    .FirstOrDefault()?.Content ?? "";
                return new
                {
                    conversation.Id,
                    conversation.Title,
                    conversation.ProjectId,
                    conversation.WorkingDirectory,
                    conversation.CodexThreadId,
                    conversation.CreatedAt,
                    conversation.UpdatedAt,
                    LatestMessage = latest,
                    UnreadCount = 0,
                };
            })
            .Cast<object>()
            .ToArray();
    }

    public static async Task<object> ReadDetailAsync(
        string id,
        ConversationService conversations,
        CodexAppServerGateway codex,
        CancellationToken cancellationToken)
    {
        var snapshot = conversations.Get(id);
        object? codexThread = null;
        string? codexThreadError = null;
        if (!string.IsNullOrWhiteSpace(snapshot.Conversation.CodexThreadId))
        {
            try
            {
                var read = await codex.ReadThreadAsync(snapshot.Conversation.CodexThreadId, cancellationToken);
                codexThread = read.Json;
            }
            catch (Exception ex)
            {
                codexThreadError = ex.Message;
            }
        }

        var exposedMessages = snapshot.Messages;

        return new
        {
            snapshot.Conversation,
            Messages = exposedMessages,
            snapshot.Approvals,
            CodexThread = codexThread,
            CodexThreadError = codexThreadError,
        };
    }
}
