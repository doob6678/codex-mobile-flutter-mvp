// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

const bool supportsRenderedHtmlPreview = true;

class RenderedHtmlPreview extends StatefulWidget {
  const RenderedHtmlPreview({required this.html, super.key});

  final String html;

  @override
  State<RenderedHtmlPreview> createState() => _RenderedHtmlPreviewState();
}

class _RenderedHtmlPreviewState extends State<RenderedHtmlPreview> {
  late String _viewType;
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _viewType = _newViewType();
    _registerView();
  }

  @override
  void didUpdateWidget(RenderedHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _viewType = _newViewType();
      _registerView();
      setState(() {});
    }
  }

  @override
  void dispose() {
    final url = _objectUrl;
    if (url != null) {
      html.Url.revokeObjectUrl(url);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }

  void _registerView() {
    final previousUrl = _objectUrl;
    if (previousUrl != null) {
      html.Url.revokeObjectUrl(previousUrl);
    }

    final blob = html.Blob([_prepareHtml(widget.html)], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    _objectUrl = url;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return html.IFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..sandbox?.add('allow-same-origin')
        ..sandbox?.add('allow-scripts');
    });
  }
}

String _newViewType() =>
    'codex-html-preview-${DateTime.now().microsecondsSinceEpoch}';

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
