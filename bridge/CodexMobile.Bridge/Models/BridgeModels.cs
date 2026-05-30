namespace CodexMobile.Bridge.Models;

public sealed record AddProjectRequest(string Name, string RootPath);

public sealed record ProjectRecord(string Id, string Name, string RootPath, DateTimeOffset CreatedAt);

public sealed record CodexFileEntry(
    string Name,
    string RelativePath,
    bool IsDirectory,
    long Size,
    DateTimeOffset ModifiedAt);

public sealed record FileReadResponse(string ProjectId, string Path, string Content, string Hash, long Size);

public sealed record FileHashResponse(string ProjectId, string Path, string Hash);

public sealed record FilePatchRequest(string ProjectId, string Path, string ExpectedHash, string ReplacementText);

public sealed record FilePatchResponse(string ProjectId, string Path, string PreviousHash, string NewHash, bool Applied);

public sealed record PairingCompleteRequest(string Code);

public sealed record PairingChallenge(string Code, DateTimeOffset ExpiresAt);

public sealed record PairingToken(string AccessToken, DateTimeOffset ExpiresAt, string DeviceName = "mobile-device");

public sealed record CommandRequest(string Command, string WorkingDirectory);

public sealed record CommandPreview(string Command, string WorkingDirectory, RiskLevel RiskLevel, bool RequiresApproval);

public sealed record CommandRunResult(string Command, int ExitCode, string Stdout, string Stderr, DateTimeOffset FinishedAt);

public enum RiskLevel
{
    ReadOnly,
    Test,
    Verification,
}

public sealed record CreateConversationRequest(string Title, string ProjectId, string WorkingDirectory);

public sealed record AddMessageRequest(string Role, string Content);

public sealed record ConversationRecord(
    string Id,
    string Title,
    string ProjectId,
    string WorkingDirectory,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record ConversationMessage(
    string Id,
    string ConversationId,
    string Role,
    string Content,
    DateTimeOffset CreatedAt);

public sealed record ConversationSnapshot(
    ConversationRecord Conversation,
    IReadOnlyList<ConversationMessage> Messages,
    IReadOnlyList<ApprovalRecord> Approvals);

public sealed record ApprovalRecord(
    string Id,
    string ConversationId,
    ApprovalKind Kind,
    string Summary,
    ApprovalDecision Decision,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt);

public enum ApprovalKind
{
    Command,
    FileChange,
}

public enum ApprovalDecision
{
    Pending,
    Approved,
    Rejected,
}

public sealed record ResolveApprovalRequest(ApprovalDecision Decision);

public sealed record AuditEntry(string Id, string Type, string Message, DateTimeOffset CreatedAt);

public sealed record ProtocolSummary(
    string Source,
    IReadOnlyList<string> TypeScriptAssets,
    IReadOnlyList<string> SchemaAssets,
    IReadOnlyList<string> SupportedMethods);

public sealed record CodexAppServerStatus(bool Available, string Message, DateTimeOffset CheckedAt);

public sealed record CodexAppServerJsonResponse(string Method, System.Text.Json.JsonElement Json);

public sealed record CodexAppServerRawRequest(string Method, System.Text.Json.JsonElement? Params);

public sealed record StartCodexThreadRequest(
    string WorkingDirectory,
    string Prompt,
    string? Model = null,
    string? ApprovalPolicy = null,
    string? SandboxMode = null);

public sealed record StartCodexTurnRequest(string ThreadId, string Prompt);
