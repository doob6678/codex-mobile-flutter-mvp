import 'package:flutter/material.dart';

import 'src/api/bridge_endpoint.dart';
import 'src/api/codex_mobile_api.dart';
import 'src/screens/app_shell.dart';

void main() {
  runApp(
    CodexMobileApp(
      api: HttpCodexMobileApi(
        BridgeEndpoint(
          const String.fromEnvironment(
            'BRIDGE_URL',
            defaultValue: 'http://127.0.0.1:5010',
          ),
        ),
      ),
    ),
  );
}

class CodexMobileApp extends StatelessWidget {
  const CodexMobileApp({required this.api, super.key});

  final CodexMobileApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codex Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
      ),
      home: AppShell(api: api),
    );
  }
}
