import 'package:flutter/material.dart';

import 'screen_frame.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        ],
      ),
    );
  }
}
