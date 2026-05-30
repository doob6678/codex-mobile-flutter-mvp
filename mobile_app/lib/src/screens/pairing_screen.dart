import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import 'screen_frame.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Pairing',
      icon: Icons.link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect to a trusted local bridge before browsing projects or releasing approvals.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start pairing'),
          ),
        ],
      ),
    );
  }
}
