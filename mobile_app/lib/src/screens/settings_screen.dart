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
      title: 'Settings',
      icon: Icons.settings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('Bridge safety'),
            subtitle: Text(
              'Release builds require HTTPS or trusted local bridge pairing; never expose the Windows Bridge on an untrusted network.',
            ),
          ),
          const Divider(),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Require approval before command execution'),
            subtitle: const Text(
              'Command approvals remain explicit on mobile.',
            ),
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Redact local secrets in previews'),
            subtitle: const Text('Sensitive bridge values stay off screen.'),
          ),
          const Divider(),
          FutureBuilder<BridgeNetworkSummary>(
            future: api.getNetworkSummary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(
                  leading: Icon(Icons.wifi_tethering),
                  title: Text('Mobile bridge URLs'),
                  subtitle: Text('Loading local network interfaces'),
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
          title: const Text('Mobile bridge URLs'),
          subtitle: Text(
            summary.publicExposureAllowed
                ? 'Public hosts are enabled by a temporary environment variable.'
                : 'Only loopback, private LAN, and mesh/VPN addresses are shown by default.',
          ),
        ),
        for (final endpoint in endpoints)
          ListTile(
            dense: true,
            leading: Icon(_scopeIcon(endpoint.scope)),
            title: Text(endpoint.url),
            subtitle: Text(
              '${endpoint.scope} · ${endpoint.requiresPairing ? 'pairing token required' : 'no pairing token'}',
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
