import 'dart:convert';

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
  bool get isMarkdownFile {
    final lower = path.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.markdown');
  }

  bool get isHtmlFile {
    final lower = path.toLowerCase();
    return lower.endsWith('.html') || lower.endsWith('.htm');
  }

  bool get isImageFile {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.svg');
  }

  bool get isPdfFile => path.toLowerCase().endsWith('.pdf');

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
  const FilePreview({
    required this.path,
    required this.content,
    this.language,
    this.contentType,
  });

  final String path;
  final String content;
  final String? language;
  final String? contentType;

  factory FilePreview.fromJson(Map<String, Object?> json) {
    return FilePreview(
      path: json['path'] as String? ?? '',
      content: json['content'] as String? ?? '',
      language: json['language'] as String?,
      contentType: json['contentType'] as String?,
    );
  }

  bool get isMarkdown =>
      language?.toLowerCase() == 'markdown' ||
      _normalizedContentType.startsWith('text/markdown');
  bool get isHtml {
    final lowerLanguage = language?.toLowerCase();
    return lowerLanguage == 'html' ||
        lowerLanguage == 'xhtml' ||
        _normalizedContentType.startsWith('text/html') ||
        _normalizedContentType.startsWith('application/xhtml+xml');
  }

  bool get isImage => contentType?.startsWith('image/') == true;
  bool get isPdf =>
      _normalizedContentType.startsWith('application/pdf') ||
      path.toLowerCase().endsWith('.pdf');

  String get _normalizedContentType => contentType?.toLowerCase().trim() ?? '';
}

class DownloadedFile {
  const DownloadedFile({
    required this.projectId,
    required this.path,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.bytes,
    this.language,
  });

  final String projectId;
  final String path;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final List<int> bytes;
  final String? language;

  factory DownloadedFile.fromJson(Map<String, Object?> json) {
    final rawBytes = json['bytes'];
    final decoded = rawBytes is String ? base64Decode(rawBytes) : const <int>[];
    return DownloadedFile(
      projectId: json['projectId'] as String? ?? '',
      path: json['path'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['size'] as num?)?.toInt() ?? decoded.length,
      bytes: decoded,
      language: json['language'] as String?,
    );
  }

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf =>
      contentType.toLowerCase().trim().startsWith('application/pdf') ||
      path.toLowerCase().endsWith('.pdf') ||
      fileName.toLowerCase().endsWith('.pdf');
  bool get isHtml {
    final lowerLanguage = language?.toLowerCase();
    final lowerContentType = contentType.toLowerCase().trim();
    return lowerLanguage == 'html' ||
        lowerLanguage == 'xhtml' ||
        lowerContentType.startsWith('text/html') ||
        lowerContentType.startsWith('application/xhtml+xml');
  }
}
