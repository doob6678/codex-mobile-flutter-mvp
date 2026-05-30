class BridgeEndpoint {
  BridgeEndpoint(String baseUrl) : baseUri = Uri.parse(_normalize(baseUrl));

  final Uri baseUri;

  Uri uri(String path, [Map<String, String?> query = const {}]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    final filteredQuery = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };

    return baseUri.replace(
      path: '$basePath$cleanPath',
      queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
    );
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'http://127.0.0.1:5010/';
    }
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }
}
