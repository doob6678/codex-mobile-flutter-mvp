import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'src/api/bridge_session_store.dart';
import 'src/api/codex_mobile_api.dart';
import 'src/screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionStore = await _createSessionStore();
  final savedSession = await _loadSession(sessionStore);
  const defaultBridgeUrl = String.fromEnvironment(
    'BRIDGE_URL',
    defaultValue: '',
  );

  runApp(
    CodexMobileApp(
      api: HttpCodexMobileApi(
        resolveBridgeUrlForEndpoint(
          savedSession.hasBridgeUrl ? savedSession.bridgeUrl : defaultBridgeUrl,
          isWeb: kIsWeb,
          webOrigin: kIsWeb ? Uri.base.origin : '',
        ),
        accessToken: savedSession.accessToken,
        sessionStore: sessionStore,
      ),
    ),
  );
}

Future<BridgeSessionStore> _createSessionStore() async {
  try {
    return await createBridgeSessionStore();
  } catch (_) {
    return MemoryBridgeSessionStore();
  }
}

Future<BridgeSession> _loadSession(BridgeSessionStore sessionStore) async {
  try {
    return await sessionStore.load();
  } catch (_) {
    return const BridgeSession(bridgeUrl: '', accessToken: null);
  }
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
