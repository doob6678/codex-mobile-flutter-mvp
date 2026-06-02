import 'codex_thread.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.latestMessage,
    this.codexThreadId,
    this.unreadCount = 0,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final String latestMessage;
  final String? codexThreadId;
  final int unreadCount;

  factory ConversationSummary.fromJson(Map<String, Object?> json) {
    return ConversationSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled conversation',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      latestMessage: json['latestMessage'] as String? ?? '',
      codexThreadId: json['codexThreadId'] as String?,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}

class ConversationDetail {
  const ConversationDetail({
    required this.conversation,
    required this.messages,
    this.codexThreadError,
  });

  final ConversationRecord conversation;
  final List<ConversationMessage> messages;
  final String? codexThreadError;

  factory ConversationDetail.fromJson(Object? json) {
    final root = _readObject(json);
    final conversation = ConversationRecord.fromJson(
      _readObject(root['conversation']),
    );
    final codexThread = root['codexThread'];
    final codexMessages = codexThread is Map<String, Object?>
        ? CodexThreadDetail.fromJson(codexThread).messages
              .map(
                (message) => ConversationMessage(
                  id: 'codex_${message.role}_${message.text.hashCode}',
                  conversationId: conversation.id,
                  role: message.role,
                  content: message.text,
                  source: 'windows-codex',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                ),
              )
              .toList(growable: false)
        : const <ConversationMessage>[];
    final rawMessages = root['messages'];
    final localMessages = rawMessages is List<Object?>
        ? rawMessages
              .whereType<Map<String, Object?>>()
              .map(ConversationMessage.fromJson)
              .toList(growable: false)
        : const <ConversationMessage>[];

    final messages = codexMessages.isEmpty
        ? localMessages
        : _mergeLocalAndCodexMessages(localMessages, codexMessages);

    return ConversationDetail(
      conversation: conversation,
      messages: messages,
      codexThreadError: _readString(root['codexThreadError']).isEmpty
          ? null
          : _readString(root['codexThreadError']),
    );
  }
}

class ConversationRecord {
  const ConversationRecord({
    required this.id,
    required this.title,
    required this.projectId,
    required this.workingDirectory,
    required this.createdAt,
    required this.updatedAt,
    this.codexThreadId,
  });

  final String id;
  final String title;
  final String projectId;
  final String workingDirectory;
  final String? codexThreadId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ConversationRecord.fromJson(Map<String, Object?> json) {
    return ConversationRecord(
      id: _readString(json['id']),
      title: _readString(json['title']).isEmpty
          ? 'Untitled conversation'
          : _readString(json['title']),
      projectId: _readString(json['projectId']),
      workingDirectory: _readString(json['workingDirectory']),
      codexThreadId: _readString(json['codexThreadId']).isEmpty
          ? null
          : _readString(json['codexThreadId']),
      createdAt: _readTimestamp(json['createdAt']),
      updatedAt: _readTimestamp(json['updatedAt']),
    );
  }
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.source = 'bridge-local',
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final DateTime createdAt;
  final String source;

  factory ConversationMessage.fromJson(Map<String, Object?> json) {
    return ConversationMessage(
      id: _readString(json['id']),
      conversationId: _readString(json['conversationId']),
      role: _readString(json['role']).isEmpty ? 'user' : _readString(json['role']),
      content: _readString(json['content']),
      source: _readString(json['source']).isEmpty ? 'bridge-local' : _readString(json['source']),
      createdAt: _readTimestamp(json['createdAt']),
    );
  }
}

List<ConversationMessage> _mergeLocalAndCodexMessages(
  List<ConversationMessage> localMessages,
  List<ConversationMessage> codexMessages,
) {
  final codexKeys = codexMessages.map(_messageKey).toSet();
  return [
    for (final message in localMessages)
      if (!codexKeys.contains(_messageKey(message))) message,
    ...codexMessages,
  ];
}

String _messageKey(ConversationMessage message) {
  return '${message.role.trim().toLowerCase()}\n${message.content.trim()}';
}

Map<String, Object?> _readObject(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  return const {};
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
  if (value is String) {
    return DateTime.tryParse(value) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).round(),
      isUtc: true,
    );
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
