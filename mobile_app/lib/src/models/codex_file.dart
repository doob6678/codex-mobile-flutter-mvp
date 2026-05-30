enum CodexFileKind { file, directory }

class CodexFile {
  const CodexFile({
    required this.name,
    required this.path,
    required this.kind,
    this.sizeBytes = 0,
    this.preview,
  });

  final String name;
  final String path;
  final CodexFileKind kind;
  final int sizeBytes;
  final String? preview;

  bool get isDirectory => kind == CodexFileKind.directory;

  factory CodexFile.fromJson(Map<String, Object?> json) {
    return CodexFile(
      name: json['name'] as String? ?? '',
      path:
          json['path'] as String? ??
          json['relativePath'] as String? ??
          json['name'] as String? ??
          '',
      kind: _kindFromJson(json),
      sizeBytes:
          json['sizeBytes'] as int? ??
          json['size'] as int? ??
          (json['size'] as num?)?.toInt() ??
          0,
      preview: json['preview'] as String?,
    );
  }

  static CodexFileKind _kindFromJson(Map<String, Object?> json) {
    if (json['isDirectory'] == true) {
      return CodexFileKind.directory;
    }
    return json['kind'] == 'directory'
        ? CodexFileKind.directory
        : CodexFileKind.file;
  }
}

class FilePreview {
  const FilePreview({required this.path, required this.content, this.language});

  final String path;
  final String content;
  final String? language;

  factory FilePreview.fromJson(Map<String, Object?> json) {
    return FilePreview(
      path: json['path'] as String? ?? '',
      content: json['content'] as String? ?? '',
      language: json['language'] as String?,
    );
  }
}
