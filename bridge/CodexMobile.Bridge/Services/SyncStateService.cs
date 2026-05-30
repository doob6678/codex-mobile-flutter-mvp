using CodexMobile.Bridge.Models;
using System.Collections.Concurrent;
using System.Threading.Channels;

namespace CodexMobile.Bridge.Services;

public sealed class SyncStateService
{
    private readonly IClock clock;
    private readonly object gate = new();
    private readonly Dictionary<string, GoalRecord> goals = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, CodexTaskRecord> tasks = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<CodexSyncEvent> events = new();
    private readonly ConcurrentDictionary<Guid, Channel<CodexSyncSnapshot>> subscribers = new();

    public SyncStateService(IClock clock)
    {
        this.clock = clock;
    }

    public GoalRecord? CurrentGoal()
    {
        lock (gate)
        {
            return goals.Values.OrderByDescending(goal => goal.UpdatedAt).FirstOrDefault();
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
        lock (gate)
        {
            return new CodexSyncSnapshot(
                CurrentGoalUnsafe(),
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

    private void PublishSnapshot()
    {
        var snapshot = GetSnapshot();
        foreach (var subscriber in subscribers.Values)
        {
            subscriber.Writer.TryWrite(snapshot);
        }
    }
}
