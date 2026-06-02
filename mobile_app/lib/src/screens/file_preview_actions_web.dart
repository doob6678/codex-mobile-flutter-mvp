// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<String> persistPreviewExport({
  required String fileName,
  required List<int> bytes,
}) async {
  final safeName = safePreviewFileName(fileName);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = safeName
      ..style.display = 'none'
      ..click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
  return safeName;
}

Future<void> openPreviewExport(String path) async {
  // Browser downloads are already opened through the user's download shelf or
  // Files app on iPadOS. There is no stable Web API for opening another app.
}

String previewExportSavedMessage(String path, {required bool openAfterSave}) {
  return '浏览器已开始下载：$path';
}

String safePreviewFileName(String value) {
  final normalized = value.replaceAll(RegExp(r'[\\/:"*?<>|]+'), '_');
  return normalized.isEmpty ? 'codex-file' : normalized;
}
