import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/project.dart';
import 'screen_frame.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProjectSummary>>(
      future: api.listProjects(),
      builder: (context, snapshot) {
        final projects = snapshot.data;
        return ScreenFrame(
          title: '项目',
          icon: Icons.folder,
          child: _ProjectList(projects: projects),
        );
      },
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.projects});

  final List<ProjectSummary>? projects;

  @override
  Widget build(BuildContext context) {
    if (projects == null) {
      return const SizedBox(height: 240, child: LoadingView());
    }
    if (projects!.isEmpty) {
      return const SizedBox(
        height: 240,
        child: EmptyView(message: '还没有可访问的受信任项目。'),
      );
    }
    return Column(
      children: [
        for (final project in projects!)
          Card(
            child: ListTile(
              leading: Icon(
                project.trusted ? Icons.verified : Icons.lock_outline,
              ),
              title: Text(project.name),
              subtitle: Text(project.rootPath),
              trailing: project.trusted
                  ? const Text('已信任')
                  : const Text('只读'),
            ),
          ),
      ],
    );
  }
}
