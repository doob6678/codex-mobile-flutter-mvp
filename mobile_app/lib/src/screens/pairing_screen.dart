import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _openQrScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫描 Bridge QR'),
              ),
              OutlinedButton.icon(
                onPressed: _startPairing,
                icon: const Icon(Icons.pin),
                label: const Text('开始配对'),
              ),
            ],
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

  Future<void> _openQrScanner() async {
    final payload = await showModalBottomSheet<BridgeQrPayload>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _QrPairingSheet(),
    );
    if (payload == null) {
      return;
    }

    _bridgeUrlController.text = payload.bridgeUrl;
    _codeController.text = payload.pairingCode;
    widget.api.setBridgeUrl(payload.bridgeUrl);
    setState(() {
      _challenge = PairingChallenge(
        code: payload.pairingCode,
        expiresAt: payload.expiresAt,
      );
    });
    await _completePairing();
  }
}

class BridgeQrPayload {
  const BridgeQrPayload({
    required this.bridgeUrl,
    required this.pairingCode,
    required this.expiresAt,
  });

  final String bridgeUrl;
  final String pairingCode;
  final DateTime expiresAt;

  static BridgeQrPayload parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('QR 内容不是 Bridge JSON。');
    }
    if (decoded['type'] != 'codex-mobile-bridge') {
      throw const FormatException('QR 内容不是 Codex Mobile Bridge。');
    }
    final version = decoded['version'];
    final normalizedVersion = version is num ? version.toInt().toString() : '$version';
    if (normalizedVersion != '1') {
      throw FormatException('不支持的 Bridge QR 版本：$version');
    }
    final bridgeUrl = decoded['bridgeUrl'] as String? ?? '';
    final pairingCode = decoded['pairingCode'] as String? ?? '';
    final expiresAt = DateTime.tryParse(decoded['expiresAt'] as String? ?? '');
    if (bridgeUrl.isEmpty || pairingCode.isEmpty || expiresAt == null) {
      throw const FormatException('QR 内容缺少 Bridge 地址、配对码或过期时间。');
    }
    return BridgeQrPayload(
      bridgeUrl: bridgeUrl,
      pairingCode: pairingCode,
      expiresAt: expiresAt,
    );
  }
}

class _QrPairingSheet extends StatefulWidget {
  const _QrPairingSheet();

  @override
  State<_QrPairingSheet> createState() => _QrPairingSheetState();
}

class _QrPairingSheetState extends State<_QrPairingSheet> {
  final TextEditingController _payloadController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('扫描 Bridge QR', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Windows Bridge 的 /connect 页面会显示二维码；也可以粘贴页面里的 JSON 内容。'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _openCameraScanner,
                icon: const Icon(Icons.photo_camera),
                label: const Text('打开相机扫码'),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('bridge-qr-payload-field'),
                controller: _payloadController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Bridge QR 内容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _usePayload,
                icon: const Icon(Icons.check),
                label: const Text('使用 QR 内容'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCameraScanner() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _CameraQrScannerScreen()),
    );
    if (raw == null) {
      return;
    }
    _payloadController.text = raw;
    _usePayload();
  }

  void _usePayload() {
    try {
      Navigator.of(context).pop(BridgeQrPayload.parse(_payloadController.text));
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }
}

class _CameraQrScannerScreen extends StatefulWidget {
  const _CameraQrScannerScreen();

  @override
  State<_CameraQrScannerScreen> createState() => _CameraQrScannerScreenState();
}

class _CameraQrScannerScreenState extends State<_CameraQrScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描 Bridge QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) {
            return;
          }
          final values = capture.barcodes
              .map((barcode) => barcode.rawValue)
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false);
          if (values.isEmpty) {
            return;
          }
          _handled = true;
          Navigator.of(context).pop(values.first);
        },
      ),
    );
  }
}
