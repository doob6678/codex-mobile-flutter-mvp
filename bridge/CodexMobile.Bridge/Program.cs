using CodexMobile.Bridge.Hubs;
using CodexMobile.Bridge.Models;
using CodexMobile.Bridge.Services;
using System.Text.Json;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls(BridgeHosting.ResolveUrls(builder.Configuration));

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
    store.AddConfiguredProjects(configuration["DefaultProjects"]);
    store.AddConfiguredProjects(Environment.GetEnvironmentVariable("CODEX_MOBILE_DEFAULT_PROJECTS"));
    return store;
});
builder.Services.AddSingleton<FileWorkspaceService>();
builder.Services.AddSingleton<PairingService>();
builder.Services.AddSingleton<AuditLog>();
builder.Services.AddSingleton<CommandService>();
builder.Services.AddSingleton<ConversationService>();
builder.Services.AddSingleton<NetworkInterfaceService>();
builder.Services.AddSingleton<SyncStateService>();
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

app.Use(async (context, next) =>
{
    if (BridgeEndpointPolicy.IsPublicEndpoint(context.Request.Path))
    {
        await next();
        return;
    }

    var tokenStore = context.RequestServices.GetRequiredService<DeviceTokenStore>();
    var authorization = context.Request.Headers.Authorization.ToString();
    var token = authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
        ? authorization["Bearer ".Length..].Trim()
        : null;

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

app.MapGet("/protocol/summary", (ProtocolAssetService protocol) => Results.Ok(protocol.ReadSummary()));
app.MapGet("/network/interfaces", (HttpContext context, NetworkInterfaceService network) =>
{
    var port = context.Request.Host.Port
        ?? (string.Equals(context.Request.Scheme, "https", StringComparison.OrdinalIgnoreCase) ? 443 : 80);
    return Results.Ok(network.ReadSummary(context.Request.Scheme, port));
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
    Results.Ok(await codex.ReadConfigAsync(cancellationToken)));
app.MapGet("/codex/account", async (CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await codex.ReadAccountAsync(cancellationToken)));
app.MapGet("/codex/threads", async (CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await codex.ListThreadsAsync(cancellationToken)));
app.MapGet("/codex/threads/{threadId}", async (string threadId, CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await codex.ReadThreadAsync(threadId, cancellationToken)));
app.MapPost("/codex/threads", async (StartCodexThreadRequest request, CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await codex.StartThreadAsync(request, cancellationToken)));
app.MapPost("/codex/turns", async (StartCodexTurnRequest request, CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await codex.StartTurnAsync(request, cancellationToken)));
app.MapPost("/codex/raw", async (CodexAppServerRawRequest request, CodexAppServerGateway codex, CancellationToken cancellationToken) =>
    Results.Ok(await codex.CallAsync(request.Method, request.Params, cancellationToken)));

app.MapPost("/pairing/start", (PairingService pairing) => Results.Ok(pairing.Start(TimeSpan.FromMinutes(5))));
app.MapPost("/pairing/complete", (PairingCompleteRequest request, PairingService pairing) => Results.Ok(pairing.Complete(request.Code)));

app.MapGet("/projects", (ProjectStore projects) => Results.Ok(projects.ListProjects()));
app.MapPost("/projects", (AddProjectRequest request, ProjectStore projects) =>
{
    var project = projects.AddProject(request.Name, request.RootPath);
    return Results.Created($"/projects/{project.Id}", project);
});

app.MapGet("/files/list", (string projectId, string? path, FileWorkspaceService files) =>
    Results.Ok(files.List(projectId, path ?? ".")));
app.MapGet("/files/read", (string projectId, string path, FileWorkspaceService files) =>
    Results.Ok(files.ReadText(projectId, path)));
app.MapGet("/files/hash", (string projectId, string path, FileWorkspaceService files) =>
    Results.Ok(files.Hash(projectId, path)));
app.MapPost("/files/patch", (FilePatchRequest request, FileWorkspaceService files) =>
    Results.Ok(files.ApplyPatch(request)));

app.MapGet("/conversations", (ConversationService conversations) => Results.Ok(conversations.List()));
app.MapPost("/conversations", (CreateConversationRequest request, ConversationService conversations) =>
{
    var conversation = conversations.Create(request.Title, request.ProjectId, request.WorkingDirectory);
    return Results.Created($"/conversations/{conversation.Id}", conversation);
});
app.MapGet("/conversations/{id}", (string id, ConversationService conversations) => Results.Ok(conversations.Get(id)));
app.MapPost("/conversations/{id}/messages", (string id, AddMessageRequest request, ConversationService conversations) =>
    Results.Ok(conversations.AddMessage(id, request.Role, request.Content)));

app.MapGet("/approvals", (ConversationService conversations) => Results.Ok(conversations.ListApprovals()));
app.MapPost("/approvals/{id}/resolve", (string id, ResolveApprovalRequest request, ConversationService conversations) =>
    Results.Ok(conversations.ResolveApproval(id, request.Decision)));

app.MapGet("/audit", (AuditLog audit) => Results.Ok(audit.List()));
app.MapPost("/commands/preview", (CommandRequest request, CommandService commands) => Results.Ok(commands.Preview(request)));
app.MapPost("/commands/run", async (CommandRequest request, CommandService commands, CancellationToken cancellationToken) =>
    Results.Ok(await commands.RunAsync(request, cancellationToken)));

app.MapHub<BridgeHub>("/hubs/events");

app.Run();

public partial class Program;

public static class BridgeEndpointPolicy
{
    public static bool IsPublicEndpoint(PathString path)
    {
        return path.StartsWithSegments("/health", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/pairing", StringComparison.OrdinalIgnoreCase)
            || path.StartsWithSegments("/protocol", StringComparison.OrdinalIgnoreCase);
    }
}
