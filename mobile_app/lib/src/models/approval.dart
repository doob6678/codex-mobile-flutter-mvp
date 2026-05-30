enum ApprovalRisk { low, medium, high }

enum ApprovalAction { approve, reject }

class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.projectId,
    required this.title,
    required this.command,
    required this.risk,
    required this.actions,
  });

  final String id;
  final String projectId;
  final String title;
  final String command;
  final ApprovalRisk risk;
  final List<ApprovalAction> actions;

  factory ApprovalRequest.fromJson(Map<String, Object?> json) {
    final rawActions = json['actions'];
    return ApprovalRequest(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? json['conversationId'] as String? ?? '',
      title:
          json['title'] as String? ??
          json['summary'] as String? ??
          'Approval request',
      command: json['command'] as String? ?? json['summary'] as String? ?? '',
      risk: _riskFromJson(json['risk'] as String?),
      actions: rawActions is List<Object?>
          ? rawActions
                .whereType<String>()
                .map(_actionFromJson)
                .whereType<ApprovalAction>()
                .toList(growable: false)
          : json['decision'] == 'pending'
          ? const [ApprovalAction.approve, ApprovalAction.reject]
          : const [],
    );
  }

  static ApprovalRisk _riskFromJson(String? value) {
    return switch (value) {
      'high' => ApprovalRisk.high,
      'medium' => ApprovalRisk.medium,
      _ => ApprovalRisk.low,
    };
  }

  static ApprovalAction? _actionFromJson(String value) {
    return switch (value) {
      'approve' => ApprovalAction.approve,
      'reject' => ApprovalAction.reject,
      _ => null,
    };
  }
}
