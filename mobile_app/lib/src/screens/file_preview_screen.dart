import 'package:flutter/material.dart';

import '../models/codex_file.dart';

class FilePreviewScreen extends StatelessWidget {
  const FilePreviewScreen({required this.preview, super.key});

  final FilePreview preview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(preview.path)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: preview.language == 'markdown'
                ? _MarkdownReader(content: preview.content)
                : SingleChildScrollView(
                    child: SelectableText(
                      preview.content,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownReader extends StatelessWidget {
  const _MarkdownReader({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return ListView.separated(
      shrinkWrap: true,
      itemCount: lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final line = lines[index];
        if (line.startsWith('# ')) {
          return Text(
            line.substring(2),
            style: Theme.of(context).textTheme.headlineSmall,
          );
        }
        if (line.startsWith('## ')) {
          return Text(
            line.substring(3),
            style: Theme.of(context).textTheme.titleLarge,
          );
        }
        if (line.startsWith('- ')) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(line.substring(2))),
            ],
          );
        }
        if (line.trim().isEmpty) {
          return const SizedBox(height: 8);
        }
        return SelectableText(line);
      },
    );
  }
}
