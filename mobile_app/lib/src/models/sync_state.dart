enum GoalStatus { active, completed, paused }

enum CodexTaskStatus { pending, running, blocked, completed, failed }

class GoalRecord {
  const GoalRecord({
    required this.id,
    required this.objective,
    required this.status,
    required this.source,
    required this.updatedAt,
  });

  final String id;
  final String objective;
  final GoalStatus status;
  final String source;
  final DateTime updatedAt;

  factory GoalRecord.fromJson(Map<String, Object?> json) {
    return GoalRecord(
      id: json['id'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      status: _goalStatus(json['status'] as String?),
      source: json['source'] as String? ?? 'bridge',
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

class CodexSyncSnapshot {
  const CodexSyncSnapshot({
    required this.tasks,
    required this.updatedAt,
    this.goal,
  });

  final GoalRecord? goal;
  final List<CodexTaskRecord> tasks;
  final DateTime updatedAt;

  factory CodexSyncSnapshot.fromJson(Map<String, Object?> json) {
    final rawGoal = json['goal'];
    final rawTasks = json['tasks'];
    return CodexSyncSnapshot(
      goal: rawGoal is Map<String, Object?> ? GoalRecord.fromJson(rawGoal) : null,
      tasks: rawTasks is List<Object?>
          ? rawTasks
                .whereType<Map<String, Object?>>()
                .map(CodexTaskRecord.fromJson)
                .toList(growable: false)
          : const [],
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
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
