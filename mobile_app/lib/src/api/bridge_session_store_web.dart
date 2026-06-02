// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'bridge_session_store.dart';

class WebLocalStorageBridgeSessionStore implements BridgeSessionStore {
  static const String _bridgeUrlKey = 'codexMobile.bridgeUrl';
  static const String _accessTokenKey = 'codexMobile.accessToken';

  @override
  Future<BridgeSession> load() async {
    return BridgeSession(
      bridgeUrl: html.window.localStorage[_bridgeUrlKey] ?? '',
      accessToken: html.window.localStorage[_accessTokenKey],
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

    html.window.localStorage[_bridgeUrlKey] = bridgeUrl;
    if (accessToken == null || accessToken.isEmpty) {
      html.window.localStorage.remove(_accessTokenKey);
    } else {
      html.window.localStorage[_accessTokenKey] = accessToken;
    }
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_bridgeUrlKey);
    html.window.localStorage.remove(_accessTokenKey);
  }
}

Future<BridgeSessionStore> createPlatformBridgeSessionStore() async {
  return WebLocalStorageBridgeSessionStore();
}
