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
  late final Future<List<ProjectSummary>> _projectsFuture;
  String? _selectedProjectId;
  String _currentPath = '';
  bool _foldersExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    _projectsFuture = widget.api.listProjects();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProjectSummary>>(
      future: _projectsFuture,
      builder: (context, snapshot) {
        final projects = snapshot.data;
        if (projects == null) {
          return const ScreenFrame(
            title: '文件',
            icon: Icons.folder_copy,
            child: SizedBox(height: 260, child: LoadingView()),
          );
        }
        if (projects.isEmpty) {
          return const ScreenFrame(
            title: '文件',
            icon: Icons.folder_copy,
            child: SizedBox(
              height: 260,
              child: EmptyView(message: '还没有可访问的受信任项目。'),
            ),
          );
        }

        final selectedProject = _selectedProject(projects);
        return ScreenFrame(
          title: '文件',
          icon: Icons.folder_copy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProjectPicker(
                projects: projects,
                selectedProject: selectedProject,
                onSelected: _selectProject,
              ),
              const SizedBox(height: 12),
              _PathHeader(
                path: _currentPath,
                canGoUp: _currentPath.isNotEmpty,
                onGoUp: _goUp,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.68,
                child: _DirectoryBrowser(
                  key: ValueKey('${selectedProject.id}:$_currentPath'),
                  api: widget.api,
                  projectId: selectedProject.id,
                  path: _currentPath,
                  foldersExpanded: _foldersExpanded,
                  onFoldersExpanded: (expanded) =>
                      setState(() => _foldersExpanded = expanded),
                  onFolderSelected: _openFolder,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ProjectSummary _selectedProject(List<ProjectSummary> projects) {
    final selectedId = _selectedProjectId;
    if (selectedId != null) {
      for (final project in projects) {
        if (project.id == selectedId) {
          return project;
        }
      }
    }
    return projects.first;
  }

  void _selectProject(ProjectSummary project) {
    setState(() {
      _selectedProjectId = project.id;
      _currentPath = '';
      _foldersExpanded = false;
    });
  }

  void _openFolder(CodexFile folder) {
    setState(() {
      _currentPath = folder.path;
      _foldersExpanded = false;
    });
  }

  void _goUp() {
    setState(() {
      _currentPath = _parentPath(_currentPath);
      _foldersExpanded = false;
    });
  }

  static String _parentPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index == -1 ? '' : normalized.substring(0, index);
  }
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({
    required this.projects,
    required this.selectedProject,
    required this.onSelected,
  });

  final List<ProjectSummary> projects;
  final ProjectSummary selectedProject;
  final ValueChanged<ProjectSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.folder_open_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedProject.id,
                      items: [
                        for (final project in projects)
                          DropdownMenuItem(
                            value: project.id,
                            child: Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (projectId) {
                        if (projectId == null) {
                          return;
                        }
                        onSelected(
                          projects.firstWhere(
                            (project) => project.id == projectId,
                          ),
                        );
                      },
                    ),
                  ),
                  Text(
                    selectedProject.rootPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathHeader extends StatelessWidget {
  const _PathHeader({
    required this.path,
    required this.canGoUp,
    required this.onGoUp,
  });

  final String path;
  final bool canGoUp;
  final VoidCallback onGoUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: '返回上级',
          onPressed: canGoUp ? onGoUp : null,
          icon: const Icon(Icons.arrow_upward),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              path.isEmpty ? '根目录' : path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _DirectoryBrowser extends StatelessWidget {
  const _DirectoryBrowser({
    required this.api,
    required this.projectId,
    required this.path,
    required this.foldersExpanded,
    required this.onFoldersExpanded,
    required this.onFolderSelected,
    super.key,
  });

  final CodexMobileApi api;
  final String projectId;
  final String path;
  final bool foldersExpanded;
  final ValueChanged<bool> onFoldersExpanded;
  final ValueChanged<CodexFile> onFolderSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CodexFile>>(
      future: api.listFiles(projectId: projectId, path: path),
      builder: (context, snapshot) {
        final entries = snapshot.data;
        if (entries == null) {
          return const LoadingView();
        }
        if (entries.isEmpty) {
          return const EmptyView(message: '当前目录没有可预览文件。');
        }

        final folders = entries.where((entry) => entry.isDirectory).toList()
          ..sort(_compareEntries);
        final files = entries.where((entry) => !entry.isDirectory).toList()
          ..sort(_compareEntries);

        return ListView(
          children: [
            _FolderGroup(
              folders: folders,
              expanded: foldersExpanded,
              onExpansionChanged: onFoldersExpanded,
              onFolderSelected: onFolderSelected,
            ),
            const SizedBox(height: 8),
            _FilesGroup(api: api, projectId: projectId, files: files),
          ],
        );
      },
    );
  }

  static int _compareEntries(CodexFile a, CodexFile b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

class _FolderGroup extends StatelessWidget {
  const _FolderGroup({
    required this.folders,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onFolderSelected,
  });

  final List<CodexFile> folders;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<CodexFile> onFolderSelected;

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: PageStorageKey('folders:${folders.map((f) => f.path).join("|")}'),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        leading: const Icon(Icons.folder_outlined),
        title: Text('文件夹 (${folders.length})'),
        children: [
          for (final folder in folders)
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: folder.path == folder.name
                  ? null
                  : Text(
                      folder.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onFolderSelected(folder),
            ),
        ],
      ),
    );
  }
}

class _FilesGroup extends StatelessWidget {
  const _FilesGroup({
    required this.api,
    required this.projectId,
    required this.files,
  });

  final CodexMobileApi api;
  final String projectId;
  final List<CodexFile> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SizedBox(
        height: 180,
        child: EmptyView(message: '当前目录没有文件。'),
      );
    }

    return Column(
      children: [
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FileTile(api: api, projectId: projectId, file: file),
          ),
      ],
    );
  }
}

class _FileTile extends StatefulWidget {
  const _FileTile({
    required this.api,
    required this.projectId,
    required this.file,
  });

  final CodexMobileApi api;
  final String projectId;
  final CodexFile file;

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(_iconFor(widget.file)),
        title: Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: widget.file.preview == null
            ? null
            : Text(
                widget.file.preview!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: _opening
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: _opening ? null : () => _openFile(context),
      ),
    );
  }

  IconData _iconFor(CodexFile file) {
    if (file.isImageFile) {
      return Icons.image_outlined;
    }
    if (file.isHtmlFile) {
      return Icons.html_outlined;
    }
    if (file.isPdfFile) {
      return Icons.picture_as_pdf_outlined;
    }
    if (file.isMarkdownFile) {
      return Icons.article_outlined;
    }
    return Icons.description_outlined;
  }

  Future<void> _openFile(BuildContext context) async {
    if (_opening) {
      return;
    }

    final navigator = Navigator.of(context);
    setState(() => _opening = true);
    try {
      if (widget.file.isImageFile || widget.file.isPdfFile) {
        final downloaded = await widget.api.downloadFile(
          projectId: widget.projectId,
          path: widget.file.path,
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
            builder: (_) =>
                FilePreviewScreen(preview: preview, downloadedFile: downloaded),
          ),
        );
        return;
      }

      final preview = await widget.api.readFile(
        projectId: widget.projectId,
        path: widget.file.path,
      );
      if (!context.mounted) {
        return;
      }
      await navigator.push(
        MaterialPageRoute(builder: (_) => FilePreviewScreen(preview: preview)),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }
}
