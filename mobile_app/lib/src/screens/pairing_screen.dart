import 'dart:convert';
import 'dart:io';

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
          const SizedBox(height: 14),
          const _PairingExplainer(),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.key_outlined),
                        const SizedBox(width: 10),
                        Text(
                          '挑战秘钥',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ChallengeValue(
                      label: 'challengeId',
                      value: _challenge!.id,
                    ),
                    const SizedBox(height: 10),
                    _ChallengeValue(label: 'code', value: _challenge!.code),
                    const SizedBox(height: 10),
                    Text('过期时间 ${_challenge!.expiresAt.toLocal()}'),
                    const SizedBox(height: 8),
                    const Text(
                      '手动配对时需要同时使用 Bridge 地址、challengeId 和 6 位 code；扫码会自动填入这些字段并完成配对。',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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
        _result = null;
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
      if (_result != null) {
        setState(() => _error = null);
        return;
      }
      final bridgeUrl = _bridgeUrlController.text.trim();
      if (bridgeUrl.isEmpty) {
        setState(() => _error = '请输入 Windows Bridge 地址。');
        return;
      }
      await _completePairingAcrossUrls(
        [bridgeUrl],
        pairingCode: _codeController.text,
        challengeId: _challenge?.id,
      );
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
    setState(() {
      _result = null;
      _error = null;
      _challenge = PairingChallenge(
        id: payload.challengeId,
        code: payload.pairingCode,
        expiresAt: payload.expiresAt,
      );
    });
    await _completePairingAcrossUrls(
      payload.bridgeUrls,
      pairingCode: payload.pairingCode,
      challengeId: payload.challengeId,
    );
  }

  Future<void> _completePairingAcrossUrls(
    List<String> bridgeUrls, {
    required String pairingCode,
    String? challengeId,
  }) async {
    final candidates = bridgeUrls
        .map((bridgeUrl) => bridgeUrl.trim())
        .where((bridgeUrl) => bridgeUrl.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      setState(() => _error = '请输入 Windows Bridge 地址。');
      return;
    }

    Object? lastError;
    for (final bridgeUrl in candidates) {
      try {
        widget.api.setBridgeUrl(bridgeUrl);
        _bridgeUrlController.text = bridgeUrl;
        final result = await widget.api.completePairing(
          bridgeUrl: bridgeUrl,
          pairingCode: pairingCode,
          challengeId: challengeId,
        );
        setState(() {
          _result = result;
          _challenge = null;
          _codeController.clear();
          _error = null;
        });
        return;
      } on SocketException catch (error) {
        lastError = error;
      } on HttpException catch (error) {
        lastError = error;
        break;
      }
    }

    setState(() {
      _error = _buildConnectionError(
        candidates,
        lastError,
      );
    });
  }

  String _buildConnectionError(List<String> candidates, Object? lastError) {
    final privateCandidates = candidates.where(_looksLikePrivateBridgeUrl).toList(growable: false);
    final message = lastError.toString();
    if (message.contains('Pairing challenge was not found') ||
        message.contains('Pairing challenge expired')) {
      return '这个二维码配对挑战已使用或过期。请刷新 Windows 上的 /connect 页面，重新扫码。';
    }

    if (lastError is SocketException && privateCandidates.isNotEmpty) {
      final first = privateCandidates.first;
      return '当前手机网络无法路由到 Windows 内网地址 $first。请改用 Cloudflare/Tailscale/ZeroTier/WireGuard 等跨网地址，或在 Windows 端设置 CODEX_MOBILE_EXTERNAL_BRIDGE_URLS 后重新扫码。';
    }

    if (lastError == null) {
      return '连接 Bridge 失败。';
    }

    return '连接 Bridge 失败。${lastError.toString()}';
  }

  bool _looksLikePrivateBridgeUrl(String bridgeUrl) {
    final uri = Uri.tryParse(bridgeUrl);
    final host = uri?.host.trim() ?? '';
    if (host.isEmpty) {
      return false;
    }

    if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
      return true;
    }

    if (host.startsWith('10.')) {
      return true;
    }

    if (host.startsWith('192.168.')) {
      return true;
    }

    if (host.startsWith('172.')) {
      final parts = host.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? -1;
        return second >= 16 && second <= 31;
      }
    }

    return false;
  }
}

class _PairingExplainer extends StatelessWidget {
  const _PairingExplainer();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security_outlined),
                const SizedBox(width: 10),
                Text(
                  'QR / 手动配对',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '在 Windows Bridge 的 /connect 页面扫码最直接；如果不能扫码，就手动输入 Bridge 地址，然后用页面显示的 challengeId 和 code 完成同一次挑战。',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeValue extends StatelessWidget {
  const _ChallengeValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class BridgeQrPayload {
  const BridgeQrPayload({
    required this.challengeId,
    required this.bridgeUrl,
    required this.bridgeUrls,
    required this.pairingCode,
    required this.expiresAt,
  });

  final String challengeId;
  final String bridgeUrl;
  final List<String> bridgeUrls;
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
    final normalizedVersion = version is num
        ? version.toInt().toString()
        : '$version';
    if (normalizedVersion != '1') {
      throw FormatException('不支持的 Bridge QR 版本：$version');
    }
    final bridgeUrl = decoded['bridgeUrl'] as String? ?? '';
    final bridgeUrls = _readBridgeUrls(decoded['bridgeUrls']);
    final pairingCode = decoded['pairingCode'] as String? ?? '';
    final challengeId = decoded['challengeId'] as String? ?? '';
    final expiresAt = DateTime.tryParse(decoded['expiresAt'] as String? ?? '');
    final candidateBridgeUrls = bridgeUrls.isNotEmpty ? bridgeUrls : [bridgeUrl];
    if (candidateBridgeUrls.first.isEmpty ||
        pairingCode.isEmpty ||
        challengeId.isEmpty ||
        expiresAt == null) {
      throw const FormatException('QR 内容缺少 Bridge 地址、配对码、挑战秘钥或过期时间。');
    }
    return BridgeQrPayload(
      challengeId: challengeId,
      bridgeUrl: candidateBridgeUrls.first,
      bridgeUrls: candidateBridgeUrls,
      pairingCode: pairingCode,
      expiresAt: expiresAt,
    );
  }

  static List<String> _readBridgeUrls(Object? rawBridgeUrls) {
    if (rawBridgeUrls is! List<Object?>) {
      return const [];
    }

    final seen = <String>{};
    final urls = <String>[];
    for (final rawUrl in rawBridgeUrls) {
      final url = rawUrl as String?;
      if (url == null) {
        continue;
      }
      final trimmed = url.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      urls.add(trimmed);
    }

    return urls;
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
              Text(
                '扫描 Bridge QR',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Windows Bridge 的 /connect 页面会显示二维码；也可以粘贴页面里的 JSON 内容。',
              ),
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
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
