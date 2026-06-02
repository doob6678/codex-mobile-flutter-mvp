class CodexBackendStatus {
  const CodexBackendStatus({
    required this.available,
    required this.message,
    required this.checkedAt,
  });

  final bool available;
  final String message;
  final DateTime checkedAt;

  bool get usesFallbackHistory => !available;

  String get label => available ? 'Bridge 实时' : '历史兜底';

  factory CodexBackendStatus.fromJson(Map<String, Object?> json) {
    return CodexBackendStatus(
      available: json['available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      checkedAt:
          DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
