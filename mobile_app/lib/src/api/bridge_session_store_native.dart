import 'package:shared_preferences/shared_preferences.dart';

import 'bridge_session_store.dart';

class SharedPreferencesBridgeSessionStore implements BridgeSessionStore {
  SharedPreferencesBridgeSessionStore._(this._preferences);

  static const String _bridgeUrlKey = 'codexMobile.bridgeUrl';
  static const String _accessTokenKey = 'codexMobile.accessToken';

  final SharedPreferences _preferences;

  static Future<SharedPreferencesBridgeSessionStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesBridgeSessionStore._(preferences);
  }

  @override
  Future<BridgeSession> load() async {
    return BridgeSession(
      bridgeUrl: _preferences.getString(_bridgeUrlKey) ?? '',
      accessToken: _preferences.getString(_accessTokenKey),
    );
  }

  @override
  Future<void> save(BridgeSession session) async {
    final bridgeUrl = session.bridgeUrl.trim();
    final accessToken = session.accessToken?.trim();
    if (bridgeUrl.isEmpty) {
      await clear();
      return;
    }

    await _preferences.setString(_bridgeUrlKey, bridgeUrl);
    if (accessToken == null || accessToken.isEmpty) {
      await _preferences.remove(_accessTokenKey);
    } else {
      await _preferences.setString(_accessTokenKey, accessToken);
    }
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_bridgeUrlKey);
    await _preferences.remove(_accessTokenKey);
  }
}

Future<BridgeSessionStore> createPlatformBridgeSessionStore() {
  return SharedPreferencesBridgeSessionStore.create();
}
