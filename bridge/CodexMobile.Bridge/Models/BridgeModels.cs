namespace CodexMobile.Bridge.Models;

public sealed record AddProjectRequest(string Name, string RootPath);

public sealed record ProjectRecord(string Id, string Name, string RootPath, DateTimeOffset CreatedAt);

public sealed record CodexFileEntry(
    string Name,
    string RelativePath,
    bool IsDirectory,
    long Size,
    DateTimeOffset ModifiedAt);

public sealed record FileReadResponse(
    string ProjectId,
    string Path,
    string Content,
    string Hash,
    long Size,
    string Language,
    string ContentType);

public sealed record FileDownloadResponse(
    string ProjectId,
    string Path,
    string FileName,
    string ContentType,
    long Size,
    byte[] Bytes,
    string? Language);

public sealed record FileHashResponse(string ProjectId, string Path, string Hash);

public sealed record FilePatchRequest(string ProjectId, string Path, string ExpectedHash, string ReplacementText);

public sealed record FilePatchResponse(string ProjectId, string Path, string PreviousHash, string NewHash, bool Applied);

public sealed record PairingCompleteRequest(string Code, string ChallengeId);

public sealed record PairingChallenge(string Id, string Code, DateTimeOffset ExpiresAt);

public sealed record PairingToken(string AccessToken, DateTimeOffset ExpiresAt, string DeviceName = "mobile-device");

public sealed record PairingTokenStatus(
    string Fingerprint,
    string DeviceName,
    DateTimeOffset ExpiresAt,
    bool IsCurrent);

public sealed record PairingSecuritySnapshot(
    int ActiveChallenges,
    int FailedAttempts,
    int FailedAttemptLimit,
    DateTimeOffset? CooldownUntil,
    int SuccessfulPairings,
    DateTimeOffset? LastPairedAt);

public sealed record BridgeSecurityStatus(
    bool PairingRequiresChallengeId,
    IReadOnlyList<string> LocalOnlyEndpoints,
    IReadOnlyList<string> PublicEndpoints,
    PairingSecuritySnapshot? Pairing = null);

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
    string? CodexThreadId,
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

public sealed record BridgeNetworkSummary(
    string Scheme,
    int Port,
    bool PublicExposureAllowed,
    IReadOnlyList<BridgeNetworkEndpoint> Endpoints,
    IReadOnlyList<string> Warnings);

public sealed record BridgeNetworkEndpoint(
    string Host,
    string Url,
    string Scope,
    bool RequiresPairing,
    bool IsRecommendedForMobile);

public sealed record GoalRecord(
    string Id,
    string Objective,
    GoalStatus Status,
    string Source,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? CompletedAt);

public enum GoalStatus
{
    Active,
    Completed,
    Paused,
}

public sealed record UpdateGoalRequest(
    string Objective,
    GoalStatus Status = GoalStatus.Active,
    string Source = "mobile");

public sealed record CodexTaskRecord(
    string Id,
    string Title,
    string Detail,
    string? ConversationId,
    CodexTaskStatus Status,
    int ProgressPercent,
    string Summary,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? CompletedAt);

public enum CodexTaskStatus
{
    Pending,
    Running,
    Blocked,
    Completed,
    Failed,
}

public sealed record CreateCodexTaskRequest(
    string Title,
    string Detail,
    string? ConversationId = null);

public sealed record UpdateCodexTaskProgressRequest(
    CodexTaskStatus Status,
    int ProgressPercent,
    string Summary);

public sealed record CodexSyncEvent(
    string Type,
    string EntityId,
    DateTimeOffset Timestamp,
    IReadOnlyDictionary<string, object?> Payload);

public sealed record MobileUserMessageRecord(
    string Id,
    string ThreadId,
    string Role,
    string Text,
    string Source,
    string? JobId,
    DateTimeOffset CreatedAt);

public sealed record CodexSyncSnapshot(
    GoalRecord? Goal,
    IReadOnlyList<GoalRecord> Goals,
    IReadOnlyList<CodexTaskRecord> Tasks,
    IReadOnlyList<CodexSyncEvent> Events,
    DateTimeOffset UpdatedAt);

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
