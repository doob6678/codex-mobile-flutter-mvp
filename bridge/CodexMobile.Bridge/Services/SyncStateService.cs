using CodexMobile.Bridge.Models;
using System.Collections.Concurrent;
using System.Text.RegularExpressions;
using System.Threading.Channels;

namespace CodexMobile.Bridge.Services;

public sealed class SyncStateService
{
    private const int MaxEvents = 3000;
    private static readonly Regex ApiKeyAssignment = new(@"OPENAI_API_KEY\s*=\s*\S+", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex SecretToken = new(@"sk-[A-Za-z0-9_\-]+", RegexOptions.Compiled);
    private readonly IClock clock;
    private readonly LocalCodexHistoryService? localHistory;
    private readonly object gate = new();
    private readonly Dictionary<string, GoalRecord> goals = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, CodexTaskRecord> tasks = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, List<MobileUserMessageRecord>> mobileUserMessages = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<CodexSyncEvent> events = new();
    private readonly ConcurrentDictionary<Guid, Channel<CodexSyncSnapshot>> subscribers = new();
    private bool historyGoalLoaded;

    public SyncStateService(IClock clock, LocalCodexHistoryService? localHistory = null)
    {
        this.clock = clock;
        this.localHistory = localHistory;
    }

    public GoalRecord? CurrentGoal()
    {
        EnsureHistoryGoalLoaded();
        lock (gate)
        {
            return goals.Values.OrderByDescending(goal => goal.UpdatedAt).FirstOrDefault();
        }
    }

    public IReadOnlyList<GoalRecord> ListGoals()
    {
        EnsureHistoryGoalLoaded();
        lock (gate)
        {
            return goals.Values.OrderByDescending(goal => goal.UpdatedAt).ToArray();
        }
    }

    public IReadOnlyList<CodexTaskRecord> ListTasks()
    {
        lock (gate)
        {
            return tasks.Values.OrderByDescending(task => task.UpdatedAt).ToArray();
        }
    }

    public CodexSyncSnapshot GetSnapshot()
    {
        EnsureHistoryGoalLoaded();
        lock (gate)
        {
            return new CodexSyncSnapshot(
                CurrentGoalUnsafe(),
                goals.Values.OrderByDescending(goal => goal.UpdatedAt).ToArray(),
                tasks.Values.OrderByDescending(task => task.UpdatedAt).ToArray(),
                events.ToArray(),
                clock.Now);
        }
    }

    public GoalRecord UpdateGoal(UpdateGoalRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Objective))
        {
            throw new ArgumentException("Goal objective is required.", nameof(request));
        }

        var now = clock.Now;
        GoalRecord goal;
        lock (gate)
        {
            var existing = CurrentGoalUnsafe();
            goal = new GoalRecord(
                existing?.Id ?? $"goal_{Guid.NewGuid():N}",
                request.Objective.Trim(),
                request.Status,
                string.IsNullOrWhiteSpace(request.Source) ? "mobile" : request.Source.Trim(),
                existing?.CreatedAt ?? now,
                now,
                request.Status == GoalStatus.Completed ? now : existing?.CompletedAt);
            goals[goal.Id] = goal;
            events.Add(new CodexSyncEvent(
                "goal.updated",
                goal.Id,
                now,
                new Dictionary<string, object?>
                {
                    ["objective"] = goal.Objective,
                    ["status"] = goal.Status.ToString(),
                    ["source"] = goal.Source,
                }));
        }

        PublishSnapshot();
        return goal;
    }

    public CodexTaskRecord CreateTask(CreateCodexTaskRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
        {
            throw new ArgumentException("Task title is required.", nameof(request));
        }

        var now = clock.Now;
        var task = new CodexTaskRecord(
            $"task_{Guid.NewGuid():N}",
            request.Title.Trim(),
            string.IsNullOrWhiteSpace(request.Detail) ? request.Title.Trim() : request.Detail.Trim(),
            string.IsNullOrWhiteSpace(request.ConversationId) ? null : request.ConversationId.Trim(),
            CodexTaskStatus.Pending,
            0,
            "Task created on mobile",
            now,
            now,
            null);

        lock (gate)
        {
            tasks[task.Id] = task;
            events.Add(new CodexSyncEvent(
                "task.created",
                task.Id,
                now,
                new Dictionary<string, object?>
                {
                    ["title"] = task.Title,
                    ["status"] = task.Status.ToString(),
                    ["progressPercent"] = task.ProgressPercent,
                }));
        }

        PublishSnapshot();
        return task;
    }

    public CodexTaskRecord UpdateTaskProgress(string taskId, UpdateCodexTaskProgressRequest request)
    {
        var now = clock.Now;
        CodexTaskRecord updated;
        lock (gate)
        {
            if (!tasks.TryGetValue(taskId, out var existing))
            {
                throw new KeyNotFoundException($"Task '{taskId}' was not found.");
            }

            updated = existing with
            {
                Status = request.Status,
                ProgressPercent = Math.Clamp(request.ProgressPercent, 0, 100),
                Summary = string.IsNullOrWhiteSpace(request.Summary) ? existing.Summary : request.Summary.Trim(),
                UpdatedAt = now,
                CompletedAt = request.Status == CodexTaskStatus.Completed ? now : existing.CompletedAt,
            };
            tasks[taskId] = updated;
            events.Add(new CodexSyncEvent(
                "task.updated",
                taskId,
                now,
                new Dictionary<string, object?>
                {
                    ["status"] = updated.Status.ToString(),
                    ["progressPercent"] = updated.ProgressPercent,
                    ["summary"] = updated.Summary,
                }));
        }

        PublishSnapshot();
        return updated;
    }

    public MobileUserMessageRecord RecordMobileUserMessage(string threadId, string text, string? jobId = null)
    {
        if (string.IsNullOrWhiteSpace(threadId))
        {
            throw new ArgumentException("Thread id is required.", nameof(threadId));
        }

        if (string.IsNullOrWhiteSpace(text))
        {
            throw new ArgumentException("Message text is required.", nameof(text));
        }

        var now = clock.Now;
        var cleanedText = Redact(text.Trim());
        var record = new MobileUserMessageRecord(
            $"mobile_user_{Guid.NewGuid():N}",
            threadId.Trim(),
            "user",
            cleanedText,
            "mobile-bridge",
            string.IsNullOrWhiteSpace(jobId) ? null : jobId.Trim(),
            now);

        lock (gate)
        {
            if (!mobileUserMessages.TryGetValue(record.ThreadId, out var threadMessages))
            {
                threadMessages = new List<MobileUserMessageRecord>();
                mobileUserMessages[record.ThreadId] = threadMessages;
            }

            if (threadMessages.Any(existing =>
                    string.Equals(existing.Role, record.Role, StringComparison.OrdinalIgnoreCase)
                    && string.Equals(existing.Text.Trim(), record.Text.Trim(), StringComparison.Ordinal)))
            {
                return threadMessages.First(existing =>
                    string.Equals(existing.Role, record.Role, StringComparison.OrdinalIgnoreCase)
                    && string.Equals(existing.Text.Trim(), record.Text.Trim(), StringComparison.Ordinal));
            }

            threadMessages.Add(record);
            events.Add(new CodexSyncEvent(
                "codex.turn.mobile_user",
                record.ThreadId,
                now,
                new Dictionary<string, object?>
                {
                    ["threadId"] = record.ThreadId,
                    ["role"] = record.Role,
                    ["text"] = record.Text,
                    ["source"] = record.Source,
                    ["jobId"] = record.JobId,
                    ["message"] = "手机发送的 USER 消息已记录，等待 Windows Codex 处理",
                }));
            TrimEventsUnsafe();
        }

        PublishSnapshot();
        return record;
    }

    public IReadOnlyList<MobileUserMessageRecord> ListMobileUserMessages(string threadId)
    {
        if (string.IsNullOrWhiteSpace(threadId))
        {
            return Array.Empty<MobileUserMessageRecord>();
        }

        lock (gate)
        {
            return mobileUserMessages.TryGetValue(threadId.Trim(), out var threadMessages)
                ? threadMessages.OrderBy(message => message.CreatedAt).ToArray()
                : Array.Empty<MobileUserMessageRecord>();
        }
    }

    public CodexSyncEvent RecordEvent(
        string type,
        string entityId,
        IReadOnlyDictionary<string, object?>? payload = null)
    {
        if (string.IsNullOrWhiteSpace(type))
        {
            throw new ArgumentException("Event type is required.", nameof(type));
        }

        var now = clock.Now;
        var syncEvent = new CodexSyncEvent(
            type.Trim(),
            string.IsNullOrWhiteSpace(entityId) ? type.Trim() : entityId.Trim(),
            now,
            payload is null
                ? new Dictionary<string, object?>()
                : new Dictionary<string, object?>(payload, StringComparer.OrdinalIgnoreCase));

        lock (gate)
        {
            events.Add(syncEvent);
            TrimEventsUnsafe();
        }

        PublishSnapshot();
        return syncEvent;
    }

    public async IAsyncEnumerable<CodexSyncSnapshot> StreamSnapshots([System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var channel = Channel.CreateUnbounded<CodexSyncSnapshot>(new UnboundedChannelOptions
        {
            SingleReader = true,
            SingleWriter = false,
        });
        var id = Guid.NewGuid();
        subscribers[id] = channel;

        await channel.Writer.WriteAsync(GetSnapshot(), cancellationToken);

        using var registration = cancellationToken.Register(() =>
        {
            if (subscribers.TryRemove(id, out var removed))
            {
                removed.Writer.TryComplete();
            }
        });

        try
        {
            while (await channel.Reader.WaitToReadAsync(cancellationToken))
            {
                while (channel.Reader.TryRead(out var snapshot))
                {
                    yield return snapshot;
                }
            }
        }
        finally
        {
            if (subscribers.TryRemove(id, out var removed))
            {
                removed.Writer.TryComplete();
            }
        }
    }

    private GoalRecord? CurrentGoalUnsafe()
    {
        return goals.Values.OrderByDescending(goal => goal.UpdatedAt).FirstOrDefault();
    }

    private void EnsureHistoryGoalLoaded()
    {
        if (historyGoalLoaded || localHistory is null)
        {
            return;
        }

        lock (gate)
        {
            if (historyGoalLoaded)
            {
                historyGoalLoaded = true;
                return;
            }
        }

        var recoveredGoals = localHistory.ReadGoals();
        lock (gate)
        {
            historyGoalLoaded = true;
            foreach (var recovered in recoveredGoals)
            {
                if (goals.ContainsKey(recovered.Id))
                {
                    continue;
                }

                goals[recovered.Id] = recovered;
            events.Add(new CodexSyncEvent(
                "goal.recovered",
                    recovered.Id,
                    recovered.UpdatedAt,
                    new Dictionary<string, object?>
                    {
                        ["objective"] = recovered.Objective,
                        ["status"] = recovered.Status.ToString(),
                        ["source"] = recovered.Source,
                    }));
            }

            TrimEventsUnsafe();
        }
    }

    private void TrimEventsUnsafe()
    {
        if (events.Count <= MaxEvents)
        {
            return;
        }

        events.RemoveRange(0, events.Count - MaxEvents);
    }

    private static string Redact(string message)
    {
        var redacted = ApiKeyAssignment.Replace(message, "OPENAI_API_KEY=[REDACTED]");
        return SecretToken.Replace(redacted, "[REDACTED]");
    }

    private void PublishSnapshot()
    {
        var snapshot = GetSnapshot();
        foreach (var subscriber in subscribers.Values)
        {
            subscriber.Writer.TryWrite(snapshot);
        }
    }
}
