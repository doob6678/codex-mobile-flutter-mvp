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
      isRecommendedForMobile:
          json['isRecommendedForMobile'] as bool? ?? false,
    );
  }
}
