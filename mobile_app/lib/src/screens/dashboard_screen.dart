import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
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
    return FutureBuilder<BridgeStatus>(
      future: api.getStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data;
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
                    label: '项目',
                    icon: Icons.folder_outlined,
                    onTap: () => onNavigate(2),
                  ),
                  _SurfaceButton(
                    label: '文件',
                    icon: Icons.description_outlined,
                    onTap: () => onNavigate(3),
                  ),
                  _SurfaceButton(
                    label: '对话',
                    icon: Icons.chat_bubble_outline,
                    onTap: () => onNavigate(4),
                  ),
                  _SurfaceButton(
                    label: '审批',
                    icon: Icons.verified_user_outlined,
                    onTap: () => onNavigate(5),
                  ),
                  _SurfaceButton(
                    label: '目标',
                    icon: Icons.track_changes_outlined,
                    onTap: () => onNavigate(6),
                  ),
                  _SurfaceButton(
                    label: '设置',
                    icon: Icons.settings_outlined,
                    onTap: () => onNavigate(7),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.computer),
                  title: Text(
                    status?.connected == true
                        ? 'Bridge 已连接'
                        : 'Bridge 未连接',
                  ),
                  subtitle: Text(
                    status == null
                        ? '等待 Bridge 状态'
                        : 'Bridge ${status.bridgeVersion} · 协议 ${status.protocolVersion}',
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
