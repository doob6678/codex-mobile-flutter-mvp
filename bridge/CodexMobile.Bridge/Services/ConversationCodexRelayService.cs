using CodexMobile.Bridge.Models;

namespace CodexMobile.Bridge.Services;

public sealed class ConversationCodexRelayService
{
    private readonly ConversationService conversations;
    private readonly CodexAppServerGateway codex;

    public ConversationCodexRelayService(ConversationService conversations, CodexAppServerGateway codex)
    {
        this.conversations = conversations;
        this.codex = codex;
    }

    public async Task<ConversationSnapshot> SendUserMessageAsync(
        string conversationId,
        string content,
        CancellationToken cancellationToken = default,
        bool recordLocalMessage = true)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            throw new ArgumentException("Conversation message content is required.", nameof(content));
        }

        var prompt = content.Trim();
        var before = conversations.Get(conversationId).Conversation;

        if (string.IsNullOrWhiteSpace(before.CodexThreadId))
        {
            var start = await codex.StartThreadAsync(
                new StartCodexThreadRequest(before.WorkingDirectory, prompt),
                cancellationToken);
            var threadId = CodexAppServerGateway.TryReadThreadId(start.Json);
            if (string.IsNullOrWhiteSpace(threadId))
            {
                throw new InvalidOperationException("Codex thread/start did not return a thread id.");
            }

            conversations.BindCodexThread(conversationId, threadId);
        }
        else
        {
            await codex.StartTurnAsync(
                new StartCodexTurnRequest(before.CodexThreadId, prompt),
                cancellationToken);
        }

        if (recordLocalMessage)
        {
            conversations.AddMessage(conversationId, "user", prompt);
        }

        return conversations.Get(conversationId);
    }
}
