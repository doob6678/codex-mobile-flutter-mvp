using Microsoft.AspNetCore.SignalR;

namespace CodexMobile.Bridge.Hubs;

public sealed class BridgeHub : Hub
{
    public async Task SubscribeConversation(string conversationId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"conversation:{conversationId}");
    }

    public async Task UnsubscribeConversation(string conversationId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"conversation:{conversationId}");
    }
}
