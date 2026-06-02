Future<String> persistPreviewExport({
  required String fileName,
  required List<int> bytes,
}) {
  throw UnsupportedError('当前平台不支持文件导出。');
}

Future<void> openPreviewExport(String path) {
  throw UnsupportedError('当前平台不支持用其他应用打开文件。');
}

String previewExportSavedMessage(String path, {required bool openAfterSave}) {
  return '已准备文件：$path';
}

String safePreviewFileName(String value) {
  final normalized = value.replaceAll(RegExp(r'[\\/:"*?<>|]+'), '_');
  return normalized.isEmpty ? 'codex-file' : normalized;
}
