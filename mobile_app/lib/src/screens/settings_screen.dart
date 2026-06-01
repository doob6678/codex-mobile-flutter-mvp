import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/bridge_network.dart';
import 'screen_frame.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: '设置',
      icon: Icons.settings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('Bridge 安全'),
            subtitle: Text(
              '发布版应使用 HTTPS 或可信的本地 Bridge 配对，不要把 Windows Bridge 暴露到不可信网络。',
            ),
          ),
          const Divider(),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('执行命令前必须审批'),
            subtitle: const Text(
              '手机端始终保持显式审批。',
            ),
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('预览中自动隐藏本地密钥'),
            subtitle: const Text('敏感 Bridge 值不会直接显示。'),
          ),
          const Divider(),
          FutureBuilder<BridgeNetworkSummary>(
            future: api.getNetworkSummary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(
                  leading: Icon(Icons.wifi_tethering),
                  title: Text('手机可用的 Bridge 地址'),
                  subtitle: Text('正在加载本机网络接口'),
                );
              }

              return _NetworkSummaryView(summary: snapshot.data!);
            },
          ),
        ],
      ),
    );
  }
}

class _NetworkSummaryView extends StatelessWidget {
  const _NetworkSummaryView({required this.summary});

  final BridgeNetworkSummary summary;

  @override
  Widget build(BuildContext context) {
    final recommended = summary.endpoints
        .where((endpoint) => endpoint.isRecommendedForMobile)
        .toList(growable: false);
    final endpoints = recommended.isEmpty ? summary.endpoints : recommended;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          ListTile(
            leading: Icon(
              summary.publicExposureAllowed
                  ? Icons.public
                  : Icons.lock,
            ),
          title: const Text('手机可用的 Bridge 地址'),
          subtitle: Text(
            summary.publicExposureAllowed
                ? '已通过临时环境变量启用公网地址。'
                : '默认只显示本机、局域网和组网/VPN 地址。',
          ),
        ),
        for (final endpoint in endpoints)
          ListTile(
            dense: true,
            leading: Icon(_scopeIcon(endpoint.scope)),
            title: Text(endpoint.url),
            subtitle: Text(
              '${endpoint.scope} · ${endpoint.requiresPairing ? '需要配对令牌' : '无需配对令牌'}',
            ),
          ),
        for (final warning in summary.warnings)
          ListTile(
            dense: true,
            leading: const Icon(Icons.warning_amber_outlined),
            title: Text(warning),
          ),
      ],
    );
  }

  static IconData _scopeIcon(String scope) {
    return switch (scope) {
      'private-lan' => Icons.router,
      'mesh-vpn' => Icons.vpn_lock,
      'loopback' => Icons.computer,
      _ => Icons.public_off,
    };
  }
}
