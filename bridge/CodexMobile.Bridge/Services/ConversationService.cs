using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class ConversationService
{
    private readonly IClock clock;
    private readonly object gate = new();
    private readonly Dictionary<string, ConversationRecord> conversations = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<ConversationMessage> messages = new();
    private readonly List<ApprovalRecord> approvals = new();

    public ConversationService(IClock clock)
    {
        this.clock = clock;
    }

    public ConversationRecord Create(string title, string projectId, string workingDirectory)
    {
        var now = clock.Now;
        var conversation = new ConversationRecord(
            $"conv_{Guid.NewGuid():N}",
            string.IsNullOrWhiteSpace(title) ? "New task" : title.Trim(),
            projectId,
            workingDirectory,
            null,
            now,
            now);

        lock (gate)
        {
            conversations[conversation.Id] = conversation;
        }

        return conversation;
    }

    public IReadOnlyList<ConversationRecord> List()
    {
        lock (gate)
        {
            return conversations.Values.OrderByDescending(conversation => conversation.UpdatedAt).ToArray();
        }
    }

    public ConversationRecord BindCodexThread(string conversationId, string codexThreadId)
    {
        if (string.IsNullOrWhiteSpace(codexThreadId))
        {
            throw new ArgumentException("Codex thread id is required.", nameof(codexThreadId));
        }

        lock (gate)
        {
            if (!conversations.TryGetValue(conversationId, out var conversation))
            {
                throw new KeyNotFoundException($"Conversation '{conversationId}' was not found.");
            }

            var updated = conversation with
            {
                CodexThreadId = codexThreadId.Trim(),
                UpdatedAt = clock.Now,
            };
            conversations[conversationId] = updated;
            return updated;
        }
    }

    public ConversationSnapshot Get(string conversationId)
    {
        lock (gate)
        {
            if (!conversations.TryGetValue(conversationId, out var conversation))
            {
                throw new KeyNotFoundException($"Conversation '{conversationId}' was not found.");
            }

            return new ConversationSnapshot(
                conversation,
                messages.Where(message => message.ConversationId == conversationId).ToArray(),
                approvals.Where(approval => approval.ConversationId == conversationId).ToArray());
        }
    }

    public ConversationMessage AddMessage(string conversationId, string role, string content)
    {
        var now = clock.Now;
        lock (gate)
        {
            if (!conversations.TryGetValue(conversationId, out var conversation))
            {
                throw new KeyNotFoundException($"Conversation '{conversationId}' was not found.");
            }

            var message = new ConversationMessage($"msg_{Guid.NewGuid():N}", conversationId, role, content, now);
            messages.Add(message);
            conversations[conversationId] = conversation with { UpdatedAt = now };
            return message;
        }
    }

    public ApprovalRecord RequestApproval(string conversationId, ApprovalKind kind, string summary)
    {
        var now = clock.Now;
        lock (gate)
        {
            if (!conversations.ContainsKey(conversationId))
            {
                throw new KeyNotFoundException($"Conversation '{conversationId}' was not found.");
            }

            var approval = new ApprovalRecord(
                $"approval_{Guid.NewGuid():N}",
                conversationId,
                kind,
                summary,
                ApprovalDecision.Pending,
                now,
                null);
            approvals.Add(approval);
            return approval;
        }
    }

    public ApprovalRecord ResolveApproval(string approvalId, ApprovalDecision decision)
    {
        lock (gate)
        {
            var index = approvals.FindIndex(approval => approval.Id.Equals(approvalId, StringComparison.OrdinalIgnoreCase));
            if (index < 0)
            {
                throw new KeyNotFoundException($"Approval '{approvalId}' was not found.");
            }

            var resolved = approvals[index] with { Decision = decision, ResolvedAt = clock.Now };
            approvals[index] = resolved;
            return resolved;
        }
    }

    public IReadOnlyList<ApprovalRecord> ListApprovals()
    {
        lock (gate)
        {
            return approvals.OrderByDescending(approval => approval.CreatedAt).ToArray();
        }
    }
}
