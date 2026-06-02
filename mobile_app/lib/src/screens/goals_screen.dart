import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/sync_state.dart';
import 'screen_frame.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final TextEditingController _goalController = TextEditingController();
  CodexSyncSnapshot? _cachedState;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CodexSyncSnapshot>(
      stream: widget.api.watchSyncState(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _cachedState = snapshot.data;
        }
        final state = snapshot.data ?? _cachedState;
        return ScreenFrame(
          title: '目标',
          icon: Icons.track_changes,
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
          child: _GoalPageBody(
            api: widget.api,
            controller: _goalController,
            snapshot: snapshot,
            state: state,
            onRefresh: () => setState(() {}),
          ),
        );
      },
    );
  }
}

class _GoalPageBody extends StatelessWidget {
  const _GoalPageBody({
    required this.api,
    required this.controller,
    required this.snapshot,
    required this.state,
    required this.onRefresh,
  });

  final CodexMobileApi api;
  final TextEditingController controller;
  final AsyncSnapshot<CodexSyncSnapshot> snapshot;
  final CodexSyncSnapshot? state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.hasError)
          const ListTile(
            leading: Icon(Icons.link),
            title: Text('请先完成 Bridge 配对，再加载实时目标状态。'),
          ),
        _GoalComposer(api: api, controller: controller, onRefresh: onRefresh),
        const SizedBox(height: 16),
        _GoalSummary(
          goal: state?.goal,
          goals: state?.goals ?? const [],
          syncState: state,
        ),
        const SizedBox(height: 16),
        _TaskList(tasks: state?.tasks ?? const []),
      ],
    );
  }
}

class _GoalComposer extends StatelessWidget {
  const _GoalComposer({
    required this.api,
    required this.controller,
    required this.onRefresh,
  });

  final CodexMobileApi api;
  final TextEditingController controller;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置 /goal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '/goal 目标',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final objective = controller.text.trim();
                    if (objective.isEmpty) {
                      return;
                    }
                    await api.updateGoal(objective: objective);
                    if (context.mounted) {
                      controller.clear();
                      onRefresh();
                    }
                  },
                  icon: const Icon(Icons.flag),
                  label: const Text('同步到 Windows'),
                ),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新状态'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSummary extends StatelessWidget {
  const _GoalSummary({
    required this.goal,
    required this.goals,
    required this.syncState,
  });

  final GoalRecord? goal;
  final List<GoalRecord> goals;
  final CodexSyncSnapshot? syncState;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag),
                const SizedBox(width: 10),
                Text('实时目标', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (syncState != null)
                  Text(
                    syncState!.updatedAt.toLocal().toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (goals.isEmpty && goal == null)
              const Text('还没有设置 /goal。')
            else ...[
              if (goals.length > 1) ...[
                Text(
                  'Windows goals · 共 ${goals.length} 个',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              for (final item in goals.isEmpty ? [goal!] : goals) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.objective,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${item.status.name} · ${item.source}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks});

  final List<CodexTaskRecord> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox(
        height: 120,
        child: EmptyView(message: '还没有任务进度。'),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('任务进度', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          task.isComplete
                              ? Icons.check_circle
                              : Icons.timelapse,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(task.title)),
                        Text('${task.progressPercent}%'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(task.summary),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: task.progressPercent / 100.0,
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
