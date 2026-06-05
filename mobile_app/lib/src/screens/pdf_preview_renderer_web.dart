// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

const bool supportsRenderedPdfPreview = false;
const bool supportsEmbeddedPdfPreview = true;

class EmbeddedPdfPreview extends StatefulWidget {
  const EmbeddedPdfPreview({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  State<EmbeddedPdfPreview> createState() => _EmbeddedPdfPreviewState();
}

class _EmbeddedPdfPreviewState extends State<EmbeddedPdfPreview> {
  late String _viewType;
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _viewType = _newViewType();
    _registerView();
  }

  @override
  void didUpdateWidget(EmbeddedPdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
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

    final blob = html.Blob([widget.bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    _objectUrl = url;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return html.IFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }
}

Future<List<Uint8List>> renderPdfPages(Uint8List bytes) async {
  return const <Uint8List>[];
}

String _newViewType() =>
    'codex-pdf-preview-${DateTime.now().microsecondsSinceEpoch}';
