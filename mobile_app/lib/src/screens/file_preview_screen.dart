import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/codex_file.dart';

class FilePreviewScreen extends StatefulWidget {
  const FilePreviewScreen({
    required this.preview,
    this.downloadedFile,
    super.key,
  });

  final FilePreview preview;
  final DownloadedFile? downloadedFile;

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  String? _message;
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final file = widget.downloadedFile;
    final isImage = file?.isImage ?? widget.preview.isImage;
    final isHtml = file?.isHtml ?? widget.preview.isHtml;
    final isPdf = file?.isPdf ?? widget.preview.isPdf;
    final html = file == null
        ? widget.preview.content
        : utf8.decode(file.bytes, allowMalformed: true);
    final bytes = file?.bytes ?? utf8.encode(widget.preview.content);
    final content = _PreviewContent(
      preview: widget.preview,
      downloadedFile: file,
      bytes: bytes,
      isImage: isImage,
      isHtml: isHtml,
      isPdf: isPdf,
      html: html,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.preview.path),
        actions: [
          if (isHtml || isPdf)
            IconButton(
              tooltip: '全屏查看',
              onPressed: () => _openFullscreen(content),
              icon: const Icon(Icons.fullscreen),
            ),
          IconButton(
            tooltip: '下载到本地',
            onPressed: _working
                ? null
                : () => _persist(bytes, openAfterSave: false),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: '下载并用其他应用打开',
            onPressed: _working
                ? null
                : () => _persist(bytes, openAfterSave: true),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _PreviewBody(content: content)),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF166534)),
                ),
              ],
              if (_working) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFullscreen(_PreviewContent content) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPreviewScreen(content: content),
      ),
    );
  }

  Future<void> _persist(List<int> bytes, {required bool openAfterSave}) async {
    setState(() {
      _working = true;
      _message = null;
    });

    try {
      final path = await persistPreviewExport(
        fileName: widget.downloadedFile?.fileName ?? widget.preview.path,
        bytes: bytes,
      );
      if (openAfterSave) {
        await OpenFilex.open(path);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _working = false;
        _message = openAfterSave ? '已保存并尝试使用其他应用打开：$path' : '已保存到本地：$path';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _working = false;
        _message = error.toString();
      });
    }
  }
}

class _PreviewContent {
  const _PreviewContent({
    required this.preview,
    required this.downloadedFile,
    required this.bytes,
    required this.isImage,
    required this.isHtml,
    required this.isPdf,
    required this.html,
  });

  final FilePreview preview;
  final DownloadedFile? downloadedFile;
  final List<int> bytes;
  final bool isImage;
  final bool isHtml;
  final bool isPdf;
  final String html;
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.content});

  final _PreviewContent content;

  @override
  Widget build(BuildContext context) {
    if (content.isPdf) {
      return _PdfPreview(
        sourceName: content.downloadedFile?.fileName ?? content.preview.path,
      );
    }
    if (content.isImage) {
      return _ImagePreview(bytes: content.bytes);
    }
    if (content.isHtml) {
      return _HtmlPreview(html: content.html);
    }
    if (content.preview.isMarkdown) {
      return _MarkdownPreview(content: content.preview.content);
    }
    return _PlainTextPreview(content: content.preview.content);
  }
}

class _FullscreenPreviewScreen extends StatelessWidget {
  const _FullscreenPreviewScreen({required this.content});

  final _PreviewContent content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(content.preview.path),
        actions: [
          IconButton(
            tooltip: '退出全屏',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.fullscreen_exit),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: _PreviewBody(content: content),
        ),
      ),
    );
  }
}

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

  final safeName = _safeFileName(fileName);
  final file = File('${directory.path}${Platform.pathSeparator}$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

String _safeFileName(String value) {
  final normalized = value.replaceAll(RegExp(r'[\\/:"*?<>|]+'), '_');
  return normalized.isEmpty ? 'codex-file' : normalized;
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: Theme.of(context).textTheme.bodyLarge,
          code: const TextStyle(fontFamily: 'monospace'),
          codeblockDecoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
        ),
      ),
    );
  }
}

class _PlainTextPreview extends StatelessWidget {
  const _PlainTextPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SelectableText(
        content,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      ),
    );
  }
}

class _HtmlPreview extends StatefulWidget {
  const _HtmlPreview({required this.html});

  final String html;

  @override
  State<_HtmlPreview> createState() => _HtmlPreviewState();
}

class _HtmlPreviewState extends State<_HtmlPreview> {
  late final WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (!_supportsEmbeddedHtmlPreview) {
      _controller = null;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadHtmlString(_prepareHtml(widget.html));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return _HtmlFallback(content: widget.html);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: WebViewWidget(controller: controller),
    );
  }
}

String _prepareHtml(String html) {
  final hasViewport = RegExp(
    r'<meta\s+[^>]*name=["'']viewport["'']',
    caseSensitive: false,
  ).hasMatch(html);
  final viewport =
      '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0">';
  final fitStyle =
      '<style>html,body{margin:0;padding:0;max-width:100%;overflow-wrap:anywhere;}'
      'img,video,canvas,svg,table{max-width:100%;height:auto;}'
      'pre{white-space:pre-wrap;}</style>';

  if (RegExp(r'<head[^>]*>', caseSensitive: false).hasMatch(html)) {
    return html.replaceFirstMapped(
      RegExp(r'<head[^>]*>', caseSensitive: false),
      (match) => '${match.group(0)}${hasViewport ? '' : viewport}$fitStyle',
    );
  }

  return '<!doctype html><html><head>$viewport$fitStyle</head><body>$html</body></html>';
}

bool get _supportsEmbeddedHtmlPreview {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => false,
  };
}

class _HtmlFallback extends StatelessWidget {
  const _HtmlFallback({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'HTML 预览在当前平台不可用，已显示源文件内容。',
          style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Expanded(child: _PlainTextPreview(content: content)),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes});

  final List<int> bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes.isEmpty) {
      return const Center(child: Text('图片数据为空。'));
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: Center(
        child: Image.memory(
          Uint8List.fromList(bytes),
          gaplessPlayback: true,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.sourceName});

  final String sourceName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 56,
              color: Color(0xFF991B1B),
            ),
            const SizedBox(height: 16),
            Text(
              sourceName.isEmpty ? 'PDF 文件' : sourceName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'PDF 已按二进制读取，不再当文本渲染。用右上角按钮下载或交给系统 PDF 应用打开，避免乱码。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
