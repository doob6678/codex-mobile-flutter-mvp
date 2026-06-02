import 'package:flutter/widgets.dart';

const bool supportsRenderedHtmlPreview = false;

class RenderedHtmlPreview extends StatelessWidget {
  const RenderedHtmlPreview({required this.html, super.key});

  final String html;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
