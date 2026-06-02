import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/codex_file.dart';
import '../models/project.dart';
import 'file_preview_screen.dart';
import 'screen_frame.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({
    required this.api,
    this.initialProjectId,
    super.key,
  });

  final CodexMobileApi api;
  final String? initialProjectId;

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProjectSummary>>(
      future: widget.api.listProjects(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? const <ProjectSummary>[];
        _selectedProjectId ??= projects.isNotEmpty ? projects.first.id : null;

        return ScreenFrame(
          title: '文件',
          icon: Icons.description,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (projects.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final project in projects) ...[
                        _ProjectTab(
                          project: project,
                          selected: _selectedProjectId == project.id,
                          onTap: () =>
                              setState(() => _selectedProjectId = project.id),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (_selectedProjectId == null)
                const SizedBox(
                  height: 260,
                  child: EmptyView(message: '请选择一个项目。'),
                )
              else
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.74,
                  child: _ProjectTree(
                    api: widget.api,
                    projectId: _selectedProjectId!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectTab extends StatelessWidget {
  const _ProjectTab({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final ProjectSummary project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(project.name, overflow: TextOverflow.ellipsis),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _ProjectTree extends StatelessWidget {
  const _ProjectTree({required this.api, required this.projectId});

  final CodexMobileApi api;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CodexFile>>(
      future: api.listFiles(projectId: projectId, path: ''),
      builder: (context, snapshot) {
        final entries = snapshot.data;
        if (entries == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (entries.isEmpty) {
          return const EmptyView(message: '当前项目根目录没有文件。');
        }

        return ListView(
          children: [
            for (final entry in entries)
              _FileTreeNode(
                api: api,
                projectId: projectId,
                entry: entry,
                depth: 0,
              ),
          ],
        );
      },
    );
  }
}

class _FileTreeNode extends StatelessWidget {
  const _FileTreeNode({
    required this.api,
    required this.projectId,
    required this.entry,
    required this.depth,
  });

  final CodexMobileApi api;
  final String projectId;
  final CodexFile entry;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsetsDirectional.only(
      start: 8.0 + depth * 16.0,
      end: 8,
      top: 4,
      bottom: 4,
    );

    if (entry.isDirectory) {
      return Padding(
        padding: padding,
        child: ExpansionTile(
          key: PageStorageKey('folder:${entry.path}'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.folder_outlined),
          title: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            FutureBuilder<List<CodexFile>>(
              future: api.listFiles(projectId: projectId, path: entry.path),
              builder: (context, snapshot) {
                final children = snapshot.data;
                if (children == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }
                if (children.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('文件夹为空。'),
                  );
                }
                return Column(
                  children: [
                    for (final child in children)
                      _FileTreeNode(
                        api: api,
                        projectId: projectId,
                        entry: child,
                        depth: depth + 1,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          leading: Icon(
            entry.isImageFile
                ? Icons.image_outlined
                : entry.isHtmlFile
                ? Icons.html_outlined
                : entry.isPdfFile
                ? Icons.picture_as_pdf_outlined
                : Icons.description_outlined,
          ),
          title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final navigator = Navigator.of(context);
            try {
              if (entry.isImageFile || entry.isPdfFile) {
                final downloaded = await api.downloadFile(
                  projectId: projectId,
                  path: entry.path,
                );
                final preview = FilePreview(
                  path: downloaded.path,
                  content: '',
                  language: downloaded.language,
                  contentType: downloaded.contentType,
                );
                if (!context.mounted) {
                  return;
                }
                await navigator.push(
                  MaterialPageRoute(
                    builder: (_) => FilePreviewScreen(
                      preview: preview,
                      downloadedFile: downloaded,
                    ),
                  ),
                );
                return;
              }

              final preview = await api.readFile(
                projectId: projectId,
                path: entry.path,
              );
              if (!context.mounted) {
                return;
              }
              await navigator.push(
                MaterialPageRoute(
                  builder: (_) => FilePreviewScreen(preview: preview),
                ),
              );
            } catch (error) {
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          },
        ),
      ),
    );
  }
}
