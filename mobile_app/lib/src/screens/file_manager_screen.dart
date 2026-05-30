import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/codex_file.dart';
import '../models/project.dart';
import 'file_preview_screen.dart';
import 'screen_frame.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  String? _selectedProjectId;
  String _selectedPath = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProjectSummary>>(
      future: widget.api.listProjects(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? const <ProjectSummary>[];
        _selectedProjectId ??= projects.isNotEmpty ? projects.first.id : null;

        return ScreenFrame(
          title: 'Files',
          icon: Icons.description,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (projects.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final project in projects)
                      ChoiceChip(
                        label: Text(project.name),
                        selected: _selectedProjectId == project.id,
                        onSelected: (_) => setState(() {
                          _selectedProjectId = project.id;
                          _selectedPath = '';
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              if (_selectedProjectId == null)
                const SizedBox(
                  height: 240,
                  child: EmptyView(message: 'No project selected.'),
                )
              else
                FutureBuilder<List<CodexFile>>(
                  future: widget.api.listFiles(
                    projectId: _selectedProjectId!,
                    path: _selectedPath,
                  ),
                  builder: (context, filesSnapshot) {
                    final files = filesSnapshot.data;
                    if (files == null) {
                      return const SizedBox(height: 240, child: LoadingView());
                    }
                    if (files.isEmpty) {
                      return const SizedBox(
                        height: 240,
                        child: EmptyView(message: 'Folder is empty.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final file in files)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                file.isDirectory
                                    ? Icons.folder
                                    : Icons.description,
                              ),
                              title: Text(file.name),
                              subtitle: Text(
                                file.isDirectory
                                    ? 'Folder'
                                    : '${file.sizeBytes} bytes · ${file.path}',
                              ),
                              onTap: file.isDirectory
                                  ? () => setState(() {
                                      _selectedPath = file.path;
                                    })
                                  : () async {
                                      final navigator = Navigator.of(context);
                                      final preview = await widget.api.readFile(
                                        projectId: _selectedProjectId!,
                                        path: file.path,
                                      );
                                      if (!mounted) {
                                        return;
                                      }
                                      await navigator.push(
                                        MaterialPageRoute(
                                          builder: (_) => FilePreviewScreen(
                                            preview: preview,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
