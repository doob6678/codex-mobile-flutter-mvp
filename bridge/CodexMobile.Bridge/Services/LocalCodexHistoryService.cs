using System.Text.Json;
using System.Text.RegularExpressions;

namespace CodexMobile.Bridge.Services;

public sealed class LocalCodexHistoryService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly Regex ApiKeyAssignment = new(@"OPENAI_API_KEY\s*=\s*\S+", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex SecretToken = new(@"sk-[A-Za-z0-9_\-]+", RegexOptions.Compiled);

    private readonly string codexHome;

    public LocalCodexHistoryService(string? codexHome = null)
    {
        this.codexHome = codexHome
            ?? Environment.GetEnvironmentVariable("CODEX_HOME")
            ?? Path.Combine(
                Environment.GetEnvironmentVariable("USERPROFILE")
                    ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                ".codex");
    }

    public bool IsAvailable => File.Exists(SessionIndexPath);

    private string SessionIndexPath => Path.Combine(codexHome, "session_index.jsonl");

    public JsonElement ListThreads(int limit = 200)
    {
        var threads = ReadSessionIndex()
            .OrderByDescending(thread => thread.UpdatedAt)
            .Take(limit)
            .Select(thread =>
            {
                var metadata = TryReadSessionMetadata(thread.Id);
                return new Dictionary<string, object?>
                {
                    ["id"] = thread.Id,
                    ["sessionId"] = thread.Id,
                    ["forkedFromId"] = null,
                    ["preview"] = Redact(thread.Name),
                    ["ephemeral"] = false,
                    ["modelProvider"] = metadata.ModelProvider,
                    ["createdAt"] = metadata.CreatedAt.ToUnixTimeSeconds(),
                    ["updatedAt"] = thread.UpdatedAt.ToUnixTimeSeconds(),
                    ["status"] = metadata.Archived ? "archived" : "idle",
                    ["path"] = metadata.RolloutPath,
                    ["cwd"] = metadata.Cwd,
                    ["cliVersion"] = metadata.CliVersion,
                    ["source"] = metadata.Source,
                    ["threadSource"] = null,
                    ["agentNickname"] = null,
                    ["agentRole"] = null,
                    ["gitInfo"] = null,
                    ["name"] = Redact(thread.Name),
                    ["turns"] = Array.Empty<object>(),
                };
            })
            .ToArray();

        return JsonSerializer.SerializeToElement(new
        {
            data = threads,
            nextCursor = (string?)null,
            backwardsCursor = (string?)null,
            source = "local-codex-history",
        }, JsonOptions);
    }

    public JsonElement ReadThread(string threadId, int maxItems = 300)
    {
        var indexed = ReadSessionIndex().FirstOrDefault(thread => string.Equals(thread.Id, threadId, StringComparison.OrdinalIgnoreCase));
        var metadata = TryReadSessionMetadata(threadId);
        var items = ReadThreadItems(metadata.RolloutPath, maxItems);
        var name = indexed?.Name ?? metadata.Title ?? threadId;

        var thread = new Dictionary<string, object?>
        {
            ["id"] = threadId,
            ["sessionId"] = threadId,
            ["forkedFromId"] = null,
            ["preview"] = Redact(name),
            ["ephemeral"] = false,
            ["modelProvider"] = metadata.ModelProvider,
            ["createdAt"] = metadata.CreatedAt.ToUnixTimeSeconds(),
            ["updatedAt"] = (indexed?.UpdatedAt ?? metadata.UpdatedAt).ToUnixTimeSeconds(),
            ["status"] = metadata.Archived ? "archived" : "idle",
            ["path"] = metadata.RolloutPath,
            ["cwd"] = metadata.Cwd,
            ["cliVersion"] = metadata.CliVersion,
            ["source"] = metadata.Source,
            ["threadSource"] = null,
            ["agentNickname"] = null,
            ["agentRole"] = null,
            ["gitInfo"] = null,
            ["name"] = Redact(name),
            ["turns"] = new[]
            {
                new Dictionary<string, object?>
                {
                    ["id"] = $"turn_{threadId}",
                    ["items"] = items,
                    ["itemsView"] = "full",
                    ["status"] = metadata.Archived ? "completed" : "idle",
                    ["error"] = null,
                    ["startedAt"] = metadata.CreatedAt.ToUnixTimeSeconds(),
                    ["completedAt"] = metadata.UpdatedAt.ToUnixTimeSeconds(),
                    ["durationMs"] = null,
                },
            },
        };

        return JsonSerializer.SerializeToElement(new
        {
            thread,
            source = "local-codex-history",
        }, JsonOptions);
    }

    private IReadOnlyList<IndexedThread> ReadSessionIndex()
    {
        if (!File.Exists(SessionIndexPath))
        {
            return Array.Empty<IndexedThread>();
        }

        var threads = new List<IndexedThread>();
        foreach (var line in ReadSharedLines(SessionIndexPath))
        {
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }

            try
            {
                using var document = JsonDocument.Parse(line);
                var root = document.RootElement;
                var id = ReadString(root, "id");
                if (string.IsNullOrWhiteSpace(id))
                {
                    continue;
                }

                threads.Add(new IndexedThread(
                    id,
                    ReadString(root, "thread_name", "Untitled Codex thread"),
                    ReadDate(root, "updated_at")));
            }
            catch (JsonException)
            {
                continue;
            }
        }

        return threads;
    }

    private SessionMetadata TryReadSessionMetadata(string threadId)
    {
        var rolloutPath = FindRolloutPath(threadId);
        if (rolloutPath is null)
        {
            return SessionMetadata.Empty(threadId);
        }

        foreach (var line in ReadSharedLines(rolloutPath))
        {
            try
            {
                using var document = JsonDocument.Parse(line);
                var root = document.RootElement;
                if (!root.TryGetProperty("type", out var type) || type.GetString() != "session_meta")
                {
                    continue;
                }

                var payload = root.GetProperty("payload");
                return new SessionMetadata(
                    ReadString(payload, "cwd", ""),
                    ReadString(payload, "model_provider", "unknown"),
                    ReadString(payload, "cli_version", ""),
                    ReadString(payload, "source", "local"),
                    ReadString(payload, "id", threadId),
                    ReadDate(payload, "timestamp"),
                    File.GetLastWriteTimeUtc(rolloutPath),
                    rolloutPath,
                    rolloutPath.Contains($"{Path.DirectorySeparatorChar}archived_sessions{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase));
            }
            catch (JsonException)
            {
                continue;
            }
        }

        return SessionMetadata.Empty(threadId) with { RolloutPath = rolloutPath };
    }

    private IReadOnlyList<Dictionary<string, object?>> ReadThreadItems(string? rolloutPath, int maxItems)
    {
        if (string.IsNullOrWhiteSpace(rolloutPath) || !File.Exists(rolloutPath))
        {
            return Array.Empty<Dictionary<string, object?>>();
        }

        var items = new List<Dictionary<string, object?>>();
        foreach (var line in ReadSharedLines(rolloutPath))
        {
            if (items.Count >= maxItems)
            {
                break;
            }

            try
            {
                using var document = JsonDocument.Parse(line);
                var item = TryMapLineToThreadItem(document.RootElement, items.Count);
                if (item is not null)
                {
                    items.Add(item);
                }
            }
            catch (JsonException)
            {
                continue;
            }
        }

        return items;
    }

    private Dictionary<string, object?>? TryMapLineToThreadItem(JsonElement root, int index)
    {
        var type = ReadString(root, "type");
        if (type == "event_msg" && root.TryGetProperty("payload", out var payload))
        {
            var payloadType = ReadString(payload, "type");
            if (payloadType == "user_message")
            {
                return UserMessage(index, ReadString(payload, "message"));
            }

            if (payloadType == "agent_message")
            {
                return AgentMessage(index, ReadString(payload, "message"));
            }
        }

        if (type == "response_item" && root.TryGetProperty("payload", out var response))
        {
            var responseType = ReadString(response, "type");
            if (responseType == "message")
            {
                var role = ReadString(response, "role");
                var text = ReadResponseText(response);
                return role == "user" ? UserMessage(index, text) : AgentMessage(index, text);
            }

            if (responseType == "function_call")
            {
                var command = $"{ReadString(response, "name")} {ReadString(response, "arguments")}".Trim();
                return CommandExecution(index, command, null);
            }

            if (responseType == "function_call_output")
            {
                return CommandExecution(index, ReadString(response, "call_id"), ReadString(response, "output"));
            }
        }

        return null;
    }

    private static Dictionary<string, object?> UserMessage(int index, string text)
    {
        return new Dictionary<string, object?>
        {
            ["type"] = "userMessage",
            ["id"] = $"local_user_{index}",
            ["content"] = new[]
            {
                new Dictionary<string, object?>
                {
                    ["type"] = "text",
                    ["text"] = Redact(text),
                    ["text_elements"] = Array.Empty<object>(),
                },
            },
        };
    }

    private static Dictionary<string, object?> AgentMessage(int index, string text)
    {
        return new Dictionary<string, object?>
        {
            ["type"] = "agentMessage",
            ["id"] = $"local_agent_{index}",
            ["text"] = Redact(text),
            ["phase"] = null,
            ["memoryCitation"] = null,
        };
    }

    private static Dictionary<string, object?> CommandExecution(int index, string command, string? output)
    {
        return new Dictionary<string, object?>
        {
            ["type"] = "commandExecution",
            ["id"] = $"local_command_{index}",
            ["command"] = Redact(command),
            ["cwd"] = "",
            ["processId"] = null,
            ["source"] = "local-history",
            ["status"] = "completed",
            ["commandActions"] = Array.Empty<object>(),
            ["aggregatedOutput"] = string.IsNullOrWhiteSpace(output) ? null : Redact(output),
            ["exitCode"] = null,
            ["durationMs"] = null,
        };
    }

    private string? FindRolloutPath(string threadId)
    {
        var sessions = Path.Combine(codexHome, "sessions");
        var archived = Path.Combine(codexHome, "archived_sessions");
        foreach (var root in new[] { sessions, archived })
        {
            if (!Directory.Exists(root))
            {
                continue;
            }

            var match = Directory.EnumerateFiles(root, $"*{threadId}*.jsonl", SearchOption.AllDirectories)
                .OrderByDescending(File.GetLastWriteTimeUtc)
                .FirstOrDefault();
            if (match is not null)
            {
                return match;
            }
        }

        return null;
    }

    private static string ReadResponseText(JsonElement response)
    {
        if (!response.TryGetProperty("content", out var content) || content.ValueKind != JsonValueKind.Array)
        {
            return "";
        }

        return string.Join(
            "\n",
            content.EnumerateArray()
                .Select(item => ReadString(item, "text"))
                .Where(text => !string.IsNullOrWhiteSpace(text)));
    }

    private static IEnumerable<string> ReadSharedLines(string path)
    {
        using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete);
        using var reader = new StreamReader(stream);

        while (reader.ReadLine() is { } line)
        {
            yield return line;
        }
    }

    private static string ReadString(JsonElement element, string property, string fallback = "")
    {
        return element.TryGetProperty(property, out var value) && value.ValueKind != JsonValueKind.Null
            ? value.ToString()
            : fallback;
    }

    private static DateTimeOffset ReadDate(JsonElement element, string property)
    {
        var value = ReadString(element, property);
        return DateTimeOffset.TryParse(value, out var parsed)
            ? parsed
            : DateTimeOffset.UnixEpoch;
    }

    private static string Redact(string message)
    {
        var redacted = ApiKeyAssignment.Replace(message, "OPENAI_API_KEY=[REDACTED]");
        return SecretToken.Replace(redacted, "[REDACTED]");
    }

    private sealed record IndexedThread(string Id, string Name, DateTimeOffset UpdatedAt);

    private sealed record SessionMetadata(
        string Cwd,
        string ModelProvider,
        string CliVersion,
        string Source,
        string? Title,
        DateTimeOffset CreatedAt,
        DateTimeOffset UpdatedAt,
        string? RolloutPath,
        bool Archived)
    {
        public static SessionMetadata Empty(string threadId)
        {
            return new SessionMetadata(
                "",
                "unknown",
                "",
                "local",
                threadId,
                DateTimeOffset.UnixEpoch,
                DateTimeOffset.UnixEpoch,
                null,
                false);
        }
    }
}
