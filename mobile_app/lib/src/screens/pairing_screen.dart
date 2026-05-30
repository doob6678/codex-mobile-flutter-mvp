import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import 'screen_frame.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _codeController = TextEditingController();
  PairingChallenge? _challenge;
  PairingResult? _result;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

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
            onPressed: _startPairing,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start pairing'),
          ),
          if (_challenge != null) ...[
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.pin),
              title: Text('Pairing code ${_challenge!.code}'),
              subtitle: Text('Expires at ${_challenge!.expiresAt.toLocal()}'),
            ),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Pairing code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _completePairing,
              icon: const Icon(Icons.verified_user),
              label: const Text('Complete pairing'),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: Text('Paired with ${_result!.pairedDeviceName}'),
              subtitle: const Text('Bridge token is active for this session.'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Future<void> _startPairing() async {
    try {
      final challenge = await widget.api.startPairing();
      setState(() {
        _challenge = challenge;
        _codeController.text = challenge.code;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _completePairing() async {
    try {
      final result = await widget.api.completePairing(
        bridgeUrl: '',
        pairingCode: _codeController.text,
      );
      setState(() {
        _result = result;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }
}
