class BridgeNetworkSummary {
  const BridgeNetworkSummary({
    required this.scheme,
    required this.port,
    required this.publicExposureAllowed,
    required this.endpoints,
    required this.warnings,
  });

  final String scheme;
  final int port;
  final bool publicExposureAllowed;
  final List<BridgeNetworkEndpoint> endpoints;
  final List<String> warnings;

  factory BridgeNetworkSummary.fromJson(Map<String, Object?> json) {
    final rawEndpoints = json['endpoints'];
    final rawWarnings = json['warnings'];
    return BridgeNetworkSummary(
      scheme: json['scheme'] as String? ?? 'http',
      port: json['port'] as int? ?? 0,
      publicExposureAllowed: json['publicExposureAllowed'] as bool? ?? false,
      endpoints: rawEndpoints is List<Object?>
          ? rawEndpoints
                .whereType<Map<String, Object?>>()
                .map(BridgeNetworkEndpoint.fromJson)
                .toList(growable: false)
          : const [],
      warnings: rawWarnings is List<Object?>
          ? rawWarnings.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

class BridgeSecurityStatus {
  const BridgeSecurityStatus({
    required this.pairingRequiresChallengeId,
    required this.localOnlyEndpoints,
    required this.publicEndpoints,
  });

  final bool pairingRequiresChallengeId;
  final List<String> localOnlyEndpoints;
  final List<String> publicEndpoints;

  factory BridgeSecurityStatus.fromJson(Map<String, Object?> json) {
    final rawLocalOnly = json['localOnlyEndpoints'];
    final rawPublic = json['publicEndpoints'];
    return BridgeSecurityStatus(
      pairingRequiresChallengeId:
          json['pairingRequiresChallengeId'] as bool? ?? true,
      localOnlyEndpoints: rawLocalOnly is List<Object?>
          ? rawLocalOnly.whereType<String>().toList(growable: false)
          : const [],
      publicEndpoints: rawPublic is List<Object?>
          ? rawPublic.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}

class PairingTokenStatus {
  const PairingTokenStatus({
    required this.fingerprint,
    required this.deviceName,
    required this.expiresAt,
    required this.isCurrent,
  });

  final String fingerprint;
  final String deviceName;
  final DateTime expiresAt;
  final bool isCurrent;

  factory PairingTokenStatus.fromJson(Map<String, Object?> json) {
    return PairingTokenStatus(
      fingerprint: json['fingerprint'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'mobile-device',
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }
}

class BridgeNetworkEndpoint {
  const BridgeNetworkEndpoint({
    required this.host,
    required this.url,
    required this.scope,
    required this.requiresPairing,
    required this.isRecommendedForMobile,
  });

  final String host;
  final String url;
  final String scope;
  final bool requiresPairing;
  final bool isRecommendedForMobile;

  factory BridgeNetworkEndpoint.fromJson(Map<String, Object?> json) {
    return BridgeNetworkEndpoint(
      host: json['host'] as String? ?? '',
      url: json['url'] as String? ?? '',
      scope: json['scope'] as String? ?? 'unknown',
      requiresPairing: json['requiresPairing'] as bool? ?? true,
      isRecommendedForMobile: json['isRecommendedForMobile'] as bool? ?? false,
    );
  }
}
