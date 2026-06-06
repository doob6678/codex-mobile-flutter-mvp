import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/bridge_network.dart';
import '../models/sync_state.dart';
import 'screen_frame.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.api,
    required this.onNavigate,
    super.key,
  });

  final CodexMobileApi api;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return ScreenFrame(
          title: '概览',
          icon: Icons.dashboard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SurfaceButton(
                    label: '文件',
                    icon: Icons.folder_copy_outlined,
                    onTap: () => onNavigate(2),
                  ),
                  _SurfaceButton(
                    label: '对话',
                    icon: Icons.chat_bubble_outline,
                    onTap: () => onNavigate(3),
                  ),
                  _SurfaceButton(
                    label: '审批',
                    icon: Icons.verified_user_outlined,
                    onTap: () => onNavigate(4),
                  ),
                  _SurfaceButton(
                    label: '目标',
                    icon: Icons.track_changes_outlined,
                    onTap: () => onNavigate(5),
                  ),
                  _SurfaceButton(
                    label: '设置',
                    icon: Icons.settings_outlined,
                    onTap: () => onNavigate(6),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Codex Console',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final cards = [
                    _BridgeMonitorCard(status: data?.status),
                    _SecurityCard(
                      securityStatus: data?.securityStatus,
                      network: data?.network,
                    ),
                    _GoalCard(
                      state: data?.syncState,
                      onOpenGoals: () => onNavigate(5),
                    ),
                    _TaskProgressCard(state: data?.syncState),
                  ];
                  if (!wide) {
                    return Column(
                      children: [
                        for (final card in cards) ...[
                          card,
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        Expanded(child: cards[index]),
                        if (index != cards.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_DashboardData> _load() async {
    final status = await api.getStatus();
    BridgeSecurityStatus? securityStatus;
    try {
      securityStatus = await api.getSecurityStatus();
    } catch (_) {
      securityStatus = null;
    }
    BridgeNetworkSummary? network;
    try {
      network = await api.getNetworkSummary();
    } catch (_) {
      network = null;
    }
    CodexSyncSnapshot? syncState;
    try {
      syncState = await api.getSyncState();
    } catch (_) {
      syncState = null;
    }
    return _DashboardData(
      status: status,
      securityStatus: securityStatus,
      network: network,
      syncState: syncState,
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.status,
    required this.securityStatus,
    required this.network,
    required this.syncState,
  });

  final BridgeStatus status;
  final BridgeSecurityStatus? securityStatus;
  final BridgeNetworkSummary? network;
  final CodexSyncSnapshot? syncState;
}

class _BridgeMonitorCard extends StatelessWidget {
  const _BridgeMonitorCard({required this.status});

  final BridgeStatus? status;

  @override
  Widget build(BuildContext context) {
    final connected = status?.connected == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(icon: Icons.computer, title: 'Bridge Monitor'),
            const SizedBox(height: 12),
            Text(
              connected ? 'Bridge 已连接' : 'Bridge 未连接',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              status == null
                  ? '等待 Bridge 状态'
                  : 'Bridge ${status!.bridgeVersion} · 协议 ${status!.protocolVersion}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.securityStatus, required this.network});

  final BridgeSecurityStatus? securityStatus;
  final BridgeNetworkSummary? network;

  @override
  Widget build(BuildContext context) {
    final requiresChallenge =
        securityStatus?.pairingRequiresChallengeId == true;
    final endpointCount = network?.endpoints.length ?? 0;
    final recommendedCount =
        network?.endpoints
            .where((endpoint) => endpoint.isRecommendedForMobile)
            .length ??
        0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(icon: Icons.shield_outlined, title: 'Security'),
            const SizedBox(height: 12),
            Text(
              requiresChallenge
                  ? 'Pairing 需要 challengeId + 6 位 code'
                  : 'Pairing 还没有启用 challengeId 校验',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              network == null
                  ? '等待网络摘要'
                  : '${network!.port} 端口 · $endpointCount 个可用地址 · $recommendedCount 个推荐给手机',
            ),
            const SizedBox(height: 6),
            Text(
              securityStatus == null
                  ? '局域网和公网策略暂不可用。'
                  : '本地限制: ${securityStatus!.localOnlyEndpoints.join(", ")}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.state, required this.onOpenGoals});

  final CodexSyncSnapshot? state;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    final goal = state?.goal;
    final goals = state?.goals ?? const <GoalRecord>[];
    final visibleGoals = goals.isNotEmpty
        ? goals
        : goal == null
        ? const <GoalRecord>[]
        : [goal];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              icon: Icons.track_changes_outlined,
              title: 'Goal Monitor',
            ),
            const SizedBox(height: 10),
            Text('/goal', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            if (visibleGoals.isEmpty)
              const Text('还没有同步到 /goal。')
            else ...[
              for (final item in visibleGoals.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onOpenGoals,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.objective,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.status.label} · ${item.source}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (goals.length > 1) ...[
                TextButton(
                  onPressed: onOpenGoals,
                  child: Text('查看全部 ${goals.length} 个目标'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskProgressCard extends StatelessWidget {
  const _TaskProgressCard({required this.state});

  final CodexSyncSnapshot? state;

  @override
  Widget build(BuildContext context) {
    final tasks = state?.tasks ?? const <CodexTaskRecord>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PanelHeader(
              icon: Icons.monitor_heart_outlined,
              title: 'Task Progress',
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              const Text('还没有任务进度。')
            else
              for (final task in tasks.take(4)) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(task.title, overflow: TextOverflow.ellipsis),
                    ),
                    Text('${task.progressPercent}%'),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: task.progressPercent / 100),
                if (task.summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _SurfaceButton extends StatelessWidget {
  const _SurfaceButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
