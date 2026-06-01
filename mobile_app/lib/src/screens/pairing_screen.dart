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
  final TextEditingController _bridgeUrlController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  PairingChallenge? _challenge;
  PairingResult? _result;
  String? _error;

  @override
  void dispose() {
    _bridgeUrlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: '配对',
      icon: Icons.link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '先连接 Windows Bridge，再浏览项目、读取文件、同步 Codex 对话和处理审批。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('bridge-url-field'),
            controller: _bridgeUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Bridge 地址',
              hintText: '例如 http://192.168.31.25:5010 或 Tailscale IP',
              helperText: '手机不要使用 127.0.0.1；请填写 Windows 机器的真实局域网或组网地址。',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _startPairing,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('开始配对'),
          ),
          if (_challenge != null) ...[
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.pin),
              title: Text('配对码 ${_challenge!.code}'),
              subtitle: Text('过期时间 ${_challenge!.expiresAt.toLocal()}'),
            ),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '配对码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _completePairing,
              icon: const Icon(Icons.verified_user),
              label: const Text('完成配对'),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: Text('已配对 ${_result!.pairedDeviceName}'),
              subtitle: const Text('当前会话已获得 Bridge 访问令牌。'),
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
      final bridgeUrl = _bridgeUrlController.text.trim();
      if (bridgeUrl.isEmpty) {
        setState(() => _error = '请输入 Windows Bridge 地址。');
        return;
      }
      widget.api.setBridgeUrl(bridgeUrl);
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
      final bridgeUrl = _bridgeUrlController.text.trim();
      if (bridgeUrl.isEmpty) {
        setState(() => _error = '请输入 Windows Bridge 地址。');
        return;
      }
      final result = await widget.api.completePairing(
        bridgeUrl: bridgeUrl,
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
