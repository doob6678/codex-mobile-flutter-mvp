class CodexThreadSummary {
  const CodexThreadSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.projectName,
    required this.projectPath,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String preview;
  final String projectName;
  final String projectPath;
  final String status;
  final DateTime updatedAt;

  factory CodexThreadSummary.fromJson(Map<String, Object?> json) {
    final cwd = _readString(json['cwd']);
    final preview = _readString(json['preview']);
    final name = _readString(json['name']);
    final title = name.trim().isNotEmpty ? name : preview;

    return CodexThreadSummary(
      id: _readString(json['id']),
      title: title.trim().isEmpty ? 'Untitled Codex thread' : title,
      preview: preview,
      projectName: _lastPathSegment(cwd),
      projectPath: cwd,
      status: _readString(json['status']).isEmpty
          ? 'unknown'
          : _readString(json['status']),
      updatedAt: _readTimestamp(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

class CodexThreadGroup {
  const CodexThreadGroup({
    required this.projectName,
    required this.projectPath,
    required this.threads,
  });

  final String projectName;
  final String projectPath;
  final List<CodexThreadSummary> threads;
}

class CodexThreadCollection {
  const CodexThreadCollection({required this.groups});

  final List<CodexThreadGroup> groups;

  factory CodexThreadCollection.fromJson(Object? json) {
    final threads = _readThreadList(json)
        .map(CodexThreadSummary.fromJson)
        .where((thread) => thread.id.isNotEmpty)
        .toList();

    threads.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

    final grouped = <String, List<CodexThreadSummary>>{};
    for (final thread in threads) {
      grouped.putIfAbsent(thread.projectPath, () => []).add(thread);
    }

    final groups = grouped.entries.map((entry) {
      final first = entry.value.first;
      return CodexThreadGroup(
        projectName: first.projectName,
        projectPath: entry.key,
        threads: List.unmodifiable(entry.value),
      );
    }).toList();

    groups.sort(
      (left, right) =>
          right.threads.first.updatedAt.compareTo(left.threads.first.updatedAt),
    );

    return CodexThreadCollection(groups: List.unmodifiable(groups));
  }
}

class CodexThreadMessage {
  const CodexThreadMessage({required this.role, required this.text});

  final String role;
  final String text;
}

class CodexThreadDetail {
  const CodexThreadDetail({required this.thread, required this.messages});

  final CodexThreadSummary thread;
  final List<CodexThreadMessage> messages;

  factory CodexThreadDetail.fromJson(Object? json) {
    final threadJson = _readThreadObject(json);
    final thread = CodexThreadSummary.fromJson(threadJson);
    final messages = <CodexThreadMessage>[];

    final turns = threadJson['turns'];
    if (turns is List<Object?>) {
      for (final turn in turns.whereType<Map<String, Object?>>()) {
        final items = turn['items'];
        if (items is! List<Object?>) {
          continue;
        }

        for (final item in items.whereType<Map<String, Object?>>()) {
          final message = _messageFromItem(item);
          if (message != null && message.text.trim().isNotEmpty) {
            messages.add(message);
          }
        }
      }
    }

    return CodexThreadDetail(
      thread: thread,
      messages: List.unmodifiable(messages),
    );
  }
}

List<Map<String, Object?>> _readThreadList(Object? json) {
  Object? cursor = json;
  if (cursor is Map<String, Object?> && cursor.containsKey('json')) {
    cursor = cursor['json'];
  }
  if (cursor is Map<String, Object?> && cursor.containsKey('data')) {
    cursor = cursor['data'];
  }
  if (cursor is! List<Object?>) {
    return const [];
  }
  return cursor.whereType<Map<String, Object?>>().toList(growable: false);
}

Map<String, Object?> _readThreadObject(Object? json) {
  Object? cursor = json;
  if (cursor is Map<String, Object?> && cursor.containsKey('json')) {
    cursor = cursor['json'];
  }
  if (cursor is Map<String, Object?> && cursor.containsKey('thread')) {
    cursor = cursor['thread'];
  }
  return cursor is Map<String, Object?> ? cursor : const {};
}

CodexThreadMessage? _messageFromItem(Map<String, Object?> item) {
  final type = _readString(item['type']);
  switch (type) {
    case 'userMessage':
      final content = item['content'];
      if (content is! List<Object?>) {
        return null;
      }
      final parts = content
          .whereType<Map<String, Object?>>()
          .map((input) => _readString(input['text'] ?? input['path'] ?? input['url'] ?? input['name']))
          .where((text) => text.trim().isNotEmpty)
          .toList();
      return CodexThreadMessage(role: 'user', text: parts.join('\n'));
    case 'agentMessage':
      return CodexThreadMessage(role: 'assistant', text: _readString(item['text']));
    case 'plan':
      return CodexThreadMessage(role: 'plan', text: _readString(item['text']));
    case 'reasoning':
      final summary = item['summary'];
      final content = item['content'];
      final parts = [
        if (summary is List<Object?>) ...summary.map(_readString),
        if (content is List<Object?>) ...content.map(_readString),
      ].where((text) => text.trim().isNotEmpty).toList();
      return CodexThreadMessage(role: 'reasoning', text: parts.join('\n'));
    case 'commandExecution':
      final command = _readString(item['command']);
      final output = _readString(item['aggregatedOutput']);
      return CodexThreadMessage(
        role: 'command',
        text: output.isEmpty ? command : '$command\n$output',
      );
    default:
      return null;
  }
}

String _readString(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

DateTime _readTimestamp(Object? value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).round(),
      isUtc: true,
    );
  }
  if (value is String) {
    return DateTime.tryParse(value) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

String _lastPathSegment(String path) {
  final trimmed = path.trim().replaceAll(RegExp(r'[\\/]+$'), '');
  if (trimmed.isEmpty) {
    return 'Unknown project';
  }
  final parts = trimmed.split(RegExp(r'[\\/]'));
  return parts.isEmpty || parts.last.isEmpty ? trimmed : parts.last;
}
