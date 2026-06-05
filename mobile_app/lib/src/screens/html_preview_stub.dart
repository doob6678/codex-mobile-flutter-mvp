import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

bool get supportsRenderedHtmlPreview {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class RenderedHtmlPreview extends StatefulWidget {
  const RenderedHtmlPreview({required this.html, super.key});

  final String html;

  @override
  State<RenderedHtmlPreview> createState() => _RenderedHtmlPreviewState();
}

class _RenderedHtmlPreviewState extends State<RenderedHtmlPreview> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setBackgroundColor(Colors.white)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_prepareHtml(widget.html));
  }

  @override
  void didUpdateWidget(RenderedHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _controller.loadHtmlString(_prepareHtml(widget.html));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!supportsRenderedHtmlPreview) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: WebViewWidget(controller: _controller),
    );
  }
}

String _prepareHtml(String source) {
  final hasViewport = RegExp(
    r'<meta\s+[^>]*name=["'']viewport["'']',
    caseSensitive: false,
  ).hasMatch(source);
  final viewport =
      '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0">';
  final fitStyle =
      '<style>html,body{margin:0;padding:8px;max-width:100%;overflow-wrap:anywhere;}'
      'img,video,canvas,svg,iframe,table{max-width:100%;height:auto;}'
      'pre{white-space:pre-wrap;}</style>';

  if (RegExp(r'<head[^>]*>', caseSensitive: false).hasMatch(source)) {
    return source.replaceFirstMapped(
      RegExp(r'<head[^>]*>', caseSensitive: false),
      (match) => '${match.group(0)}${hasViewport ? '' : viewport}$fitStyle',
    );
  }

  return '<!doctype html><html><head>$viewport$fitStyle</head><body>$source</body></html>';
}
