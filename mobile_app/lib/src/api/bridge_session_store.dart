import 'bridge_session_store_native.dart'
    if (dart.library.html) 'bridge_session_store_web.dart';

class BridgeSession {
  const BridgeSession({
    required this.bridgeUrl,
    required this.accessToken,
  });

  final String bridgeUrl;
  final String? accessToken;

  bool get hasBridgeUrl => bridgeUrl.trim().isNotEmpty;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty == true;
}

abstract interface class BridgeSessionStore {
  Future<BridgeSession> load();

  Future<void> save(BridgeSession session);

  Future<void> clear();
}

Future<BridgeSessionStore> createBridgeSessionStore() {
  return createPlatformBridgeSessionStore();
}

class MemoryBridgeSessionStore implements BridgeSessionStore {
  BridgeSession _session = const BridgeSession(bridgeUrl: '', accessToken: null);

  @override
  Future<BridgeSession> load() async => _session;

  @override
  Future<void> save(BridgeSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = const BridgeSession(bridgeUrl: '', accessToken: null);
  }
}
