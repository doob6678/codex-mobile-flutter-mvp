import 'package:flutter/material.dart';

import 'src/api/bridge_session_store.dart';
import 'src/api/codex_mobile_api.dart';
import 'src/screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionStore = await SharedPreferencesBridgeSessionStore.create();
  final savedSession = await sessionStore.load();
  const defaultBridgeUrl = String.fromEnvironment(
    'BRIDGE_URL',
    defaultValue: '',
  );

  runApp(
    CodexMobileApp(
      api: HttpCodexMobileApi(
        savedSession.hasBridgeUrl ? savedSession.bridgeUrl : defaultBridgeUrl,
        accessToken: savedSession.accessToken,
        sessionStore: sessionStore,
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
      title: 'Codex 移动端',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF111827),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF111827),
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: AppShell(api: api),
    );
  }
}
