class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.latestMessage,
    this.unreadCount = 0,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final String latestMessage;
  final int unreadCount;

  factory ConversationSummary.fromJson(Map<String, Object?> json) {
    return ConversationSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled conversation',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      latestMessage: json['latestMessage'] as String? ?? '',
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
