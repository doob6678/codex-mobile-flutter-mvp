enum GoalStatus { active, completed, paused }

extension GoalStatusLabel on GoalStatus {
  String get label => switch (this) {
    GoalStatus.active => '进行中',
    GoalStatus.paused => '暂停',
    GoalStatus.completed => '完成',
  };
}

enum CodexTaskStatus { pending, running, blocked, completed, failed }

enum CodexTurnJobStatus { pending, running, completed, failed }

class GoalRecord {
  const GoalRecord({
    required this.id,
    required this.objective,
    required this.status,
    required this.source,
    required this.updatedAt,
    this.threadId,
  });

  final String id;
  final String objective;
  final GoalStatus status;
  final String source;
  final DateTime updatedAt;
  final String? threadId;

  factory GoalRecord.fromJson(Map<String, Object?> json) {
    return GoalRecord(
      id: json['id'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      status: _goalStatus(json['status'] as String?),
      source: json['source'] as String? ?? 'bridge',
      threadId: _readNullableString(json['threadId']),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class CodexTaskRecord {
  const CodexTaskRecord({
    required this.id,
    required this.title,
    required this.detail,
    required this.status,
    required this.progressPercent,
    required this.summary,
    required this.updatedAt,
    this.conversationId,
  });

  final String id;
  final String title;
  final String detail;
  final String? conversationId;
  final CodexTaskStatus status;
  final int progressPercent;
  final String summary;
  final DateTime updatedAt;

  bool get isComplete => status == CodexTaskStatus.completed;

  factory CodexTaskRecord.fromJson(Map<String, Object?> json) {
    return CodexTaskRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled task',
      detail: json['detail'] as String? ?? '',
      conversationId: json['conversationId'] as String?,
      status: _taskStatus(json['status'] as String?),
      progressPercent: json['progressPercent'] as int? ?? 0,
      summary: json['summary'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class CodexTurnJobRecord {
  const CodexTurnJobRecord({
    required this.id,
    required this.status,
    required this.promptPreview,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    this.threadId,
    this.conversationId,
    this.startedAt,
    this.completedAt,
    this.failedAt,
    this.error,
  });

  final String id;
  final String? threadId;
  final String? conversationId;
  final CodexTurnJobStatus status;
  final String promptPreview;
  final String lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final String? error;

  bool get isActive =>
      status == CodexTurnJobStatus.pending ||
      status == CodexTurnJobStatus.running;

  factory CodexTurnJobRecord.fromJson(Map<String, Object?> json) {
    return CodexTurnJobRecord(
      id: json['id'] as String? ?? '',
      threadId: _readNullableString(json['threadId']),
      conversationId: _readNullableString(json['conversationId']),
      status: _turnJobStatus(json['status'] as String?),
      promptPreview: json['promptPreview'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
      startedAt: _readNullableDate(json['startedAt']),
      completedAt: _readNullableDate(json['completedAt']),
      failedAt: _readNullableDate(json['failedAt']),
      error: _readNullableString(json['error']),
    );
  }
}

class CodexSyncSnapshot {
  const CodexSyncSnapshot({
    required this.tasks,
    required this.updatedAt,
    this.events = const [],
    this.goals = const [],
    this.jobs = const [],
    this.goal,
  });

  final GoalRecord? goal;
  final List<GoalRecord> goals;
  final List<CodexTaskRecord> tasks;
  final List<CodexTurnJobRecord> jobs;
  final List<CodexSyncEvent> events;
  final DateTime updatedAt;

  factory CodexSyncSnapshot.fromJson(Map<String, Object?> json) {
    final rawGoal = json['goal'];
    final rawGoals = json['goals'];
    final rawTasks = json['tasks'];
    final rawJobs = json['jobs'];
    final rawEvents = json['events'];
    final goals = rawGoals is List<Object?>
        ? rawGoals
              .whereType<Map<String, Object?>>()
              .map(GoalRecord.fromJson)
              .toList(growable: false)
        : const <GoalRecord>[];
    final primaryGoal = rawGoal is Map<String, Object?>
        ? GoalRecord.fromJson(rawGoal)
        : goals.isNotEmpty
        ? goals.first
        : null;
    return CodexSyncSnapshot(
      goal: primaryGoal,
      goals: goals,
      tasks: rawTasks is List<Object?>
          ? rawTasks
                .whereType<Map<String, Object?>>()
                .map(CodexTaskRecord.fromJson)
                .toList(growable: false)
          : const [],
      jobs: rawJobs is List<Object?>
          ? rawJobs
                .whereType<Map<String, Object?>>()
                .map(CodexTurnJobRecord.fromJson)
                .toList(growable: false)
          : const [],
      events: rawEvents is List<Object?>
          ? rawEvents
                .whereType<Map<String, Object?>>()
                .map(CodexSyncEvent.fromJson)
                .toList(growable: false)
          : const [],
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class CodexSyncEvent {
  const CodexSyncEvent({
    required this.type,
    required this.entityId,
    required this.timestamp,
    this.payload = const {},
  });

  final String type;
  final String entityId;
  final DateTime timestamp;
  final Map<String, Object?> payload;

  String get message => (payload['message'] ?? '').toString();

  factory CodexSyncEvent.fromJson(Map<String, Object?> json) {
    final rawPayload = json['payload'];
    return CodexSyncEvent(
      type: json['type'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      payload: rawPayload is Map<String, Object?>
          ? Map<String, Object?>.from(rawPayload)
          : const {},
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

GoalStatus _goalStatus(String? value) {
  return switch (value?.toLowerCase()) {
    'completed' => GoalStatus.completed,
    'paused' => GoalStatus.paused,
    _ => GoalStatus.active,
  };
}

CodexTaskStatus _taskStatus(String? value) {
  return switch (value?.toLowerCase()) {
    'running' => CodexTaskStatus.running,
    'blocked' => CodexTaskStatus.blocked,
    'completed' => CodexTaskStatus.completed,
    'failed' => CodexTaskStatus.failed,
    _ => CodexTaskStatus.pending,
  };
}

CodexTurnJobStatus _turnJobStatus(String? value) {
  return switch (value?.toLowerCase()) {
    'running' => CodexTurnJobStatus.running,
    'completed' => CodexTurnJobStatus.completed,
    'failed' => CodexTurnJobStatus.failed,
    _ => CodexTurnJobStatus.pending,
  };
}

DateTime _readDate(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _readNullableDate(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

String? _readNullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
