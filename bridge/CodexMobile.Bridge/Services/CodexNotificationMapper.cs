using System.Text.Json;

namespace CodexMobile.Bridge.Services;

public sealed record CodexMappedNotification(
    string Method,
    string EntityId,
    Dictionary<string, object?> Payload,
    bool ClearsActiveThread);

public static class CodexNotificationMapper
{
    public static CodexMappedNotification Map(JsonElement root, string? activeThreadId = null)
    {
        var method = ReadMethod(root);
        var payload = ReadPayload(method, root, activeThreadId);
        var entityId = ReadEntityId(method, root, activeThreadId);
        return new CodexMappedNotification(
            method,
            entityId,
            payload,
            ClearsActiveThread(method));
    }

    public static string? ReadThreadId(object? parameters)
    {
        if (parameters is null)
        {
            return null;
        }

        var element = JsonSerializer.SerializeToElement(parameters, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        if (element.ValueKind != JsonValueKind.Object ||
            !element.TryGetProperty("threadId", out var threadId) ||
            threadId.ValueKind == JsonValueKind.Null)
        {
            return null;
        }

        var text = threadId.ToString();
        return string.IsNullOrWhiteSpace(text) ? null : text;
    }

    private static string ReadMethod(JsonElement root)
    {
        if (!root.TryGetProperty("method", out var methodElement))
        {
            return "notification";
        }

        return methodElement.GetString() ?? "notification";
    }

    private static Dictionary<string, object?> ReadPayload(
        string method,
        JsonElement root,
        string? activeThreadId)
    {
        var payload = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
        {
            ["method"] = method,
            ["message"] = DescribeNotification(method),
        };

        if (root.TryGetProperty("params", out var parameters) && parameters.ValueKind == JsonValueKind.Object)
        {
            foreach (var name in new[] { "threadId", "turnId", "itemId", "subagentId", "callId", "status" })
            {
                if (parameters.TryGetProperty(name, out var value) && value.ValueKind != JsonValueKind.Null)
                {
                    payload[name] = value.ToString();
                }
            }

            if (string.Equals(method, "item/agentMessage/delta", StringComparison.Ordinal)
                && parameters.TryGetProperty("delta", out var delta)
                && delta.ValueKind == JsonValueKind.String)
            {
                payload["delta"] = delta.GetString() ?? "";
            }
        }

        if (!payload.ContainsKey("threadId") && ShouldUseActiveThread(method) && !string.IsNullOrWhiteSpace(activeThreadId))
        {
            payload["threadId"] = activeThreadId;
        }

        return payload;
    }

    private static string ReadEntityId(string method, JsonElement root, string? activeThreadId)
    {
        if (root.TryGetProperty("params", out var parameters) && parameters.ValueKind == JsonValueKind.Object)
        {
            foreach (var name in new[] { "turnId", "threadId", "itemId", "subagentId", "callId" })
            {
                if (parameters.TryGetProperty(name, out var value) && value.ValueKind != JsonValueKind.Null)
                {
                    var text = value.ToString();
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        return text;
                    }
                }
            }
        }

        if (ShouldUseActiveThread(method) && !string.IsNullOrWhiteSpace(activeThreadId))
        {
            return activeThreadId;
        }

        return method;
    }

    private static bool ShouldUseActiveThread(string method)
    {
        return method.StartsWith("turn/", StringComparison.Ordinal)
            || method.StartsWith("item/", StringComparison.Ordinal)
            || method.StartsWith("thread/", StringComparison.Ordinal);
    }

    private static bool ClearsActiveThread(string method)
    {
        return string.Equals(method, "turn/completed", StringComparison.Ordinal)
            || string.Equals(method, "turn/failed", StringComparison.Ordinal)
            || string.Equals(method, "turn/cancelled", StringComparison.Ordinal);
    }

    private static string DescribeNotification(string method)
    {
        var normalized = method.ToLowerInvariant();
        if (normalized.Contains("turn/completed", StringComparison.Ordinal)
            || normalized.Contains("turncompleted", StringComparison.Ordinal))
        {
            return "Windows Codex 已完成这一轮处理";
        }

        if (normalized.Contains("turn/started", StringComparison.Ordinal)
            || normalized.Contains("turnstarted", StringComparison.Ordinal))
        {
            return "Windows Codex 已开始处理这一轮";
        }

        if (normalized.Contains("agentmessage", StringComparison.Ordinal)
            && normalized.Contains("delta", StringComparison.Ordinal))
        {
            return "Windows Codex 正在生成回复";
        }

        if (normalized.Contains("item", StringComparison.Ordinal)
            || normalized.Contains("tool", StringComparison.Ordinal)
            || normalized.Contains("command", StringComparison.Ordinal))
        {
            return "Windows Codex 正在执行中间步骤";
        }

        return $"app-server 通知：{method}";
    }
}
