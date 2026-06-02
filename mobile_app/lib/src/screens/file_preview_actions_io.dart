import 'dart:io';

import 'package:open_filex/open_filex.dart';

Future<String> persistPreviewExport({
  required String fileName,
  required List<int> bytes,
}) async {
  final directory = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}codex-mobile',
  );
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }

  final safeName = safePreviewFileName(fileName);
  final file = File('${directory.path}${Platform.pathSeparator}$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> openPreviewExport(String path) => OpenFilex.open(path);

String previewExportSavedMessage(String path, {required bool openAfterSave}) {
  return openAfterSave ? '已保存并尝试使用其他应用打开：$path' : '已保存到本地：$path';
}

String safePreviewFileName(String value) {
  final normalized = value.replaceAll(RegExp(r'[\\/:"*?<>|]+'), '_');
  return normalized.isEmpty ? 'codex-file' : normalized;
}
