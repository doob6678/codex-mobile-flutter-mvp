import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/approval.dart';
import 'screen_frame.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ApprovalRequest>>(
      future: api.listApprovals(),
      builder: (context, snapshot) {
        final approvals = snapshot.data;
        return ScreenFrame(
          title: '审批',
          icon: Icons.verified_user,
          child: _ApprovalList(api: api, approvals: approvals),
        );
      },
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.api, required this.approvals});

  final CodexMobileApi api;
  final List<ApprovalRequest>? approvals;

  @override
  Widget build(BuildContext context) {
    if (approvals == null) {
      return const SizedBox(height: 240, child: LoadingView());
    }
    if (approvals!.isEmpty) {
      return const SizedBox(
        height: 240,
        child: EmptyView(message: '当前没有待处理审批。'),
      );
    }
    return Column(
      children: [
        for (final approval in approvals!)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_riskIcon(approval.risk)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          approval.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(approval.risk.name.toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(approval.command),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (approval.actions.contains(ApprovalAction.approve))
                        FilledButton(
                          onPressed: () => api.resolveApproval(
                            approvalId: approval.id,
                            action: ApprovalAction.approve,
                          ),
                          child: const Text('批准'),
                        ),
                      if (approval.actions.contains(ApprovalAction.reject))
                        OutlinedButton(
                          onPressed: () => api.resolveApproval(
                            approvalId: approval.id,
                            action: ApprovalAction.reject,
                          ),
                          child: const Text('拒绝'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  IconData _riskIcon(ApprovalRisk risk) {
    return switch (risk) {
      ApprovalRisk.high => Icons.warning_amber,
      ApprovalRisk.medium => Icons.report_problem_outlined,
      ApprovalRisk.low => Icons.check_circle_outline,
    };
  }
}
