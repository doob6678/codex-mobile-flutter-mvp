import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _pdfRendererChannel = MethodChannel(
  'codex_mobile/pdf_renderer',
);

bool get supportsRenderedPdfPreview {
  return defaultTargetPlatform == TargetPlatform.android;
}

bool get supportsEmbeddedPdfPreview => false;

class EmbeddedPdfPreview extends StatelessWidget {
  const EmbeddedPdfPreview({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

Future<List<Uint8List>> renderPdfPages(Uint8List bytes) async {
  final rendered = await _pdfRendererChannel.invokeListMethod<Uint8List>(
    'renderPdf',
    <String, Object?>{
      'bytes': bytes,
      'maxWidth': 1440,
    },
  );
  return rendered ?? const <Uint8List>[];
}
