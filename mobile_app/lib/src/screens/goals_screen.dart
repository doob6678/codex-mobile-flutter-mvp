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
        final state = snapshot.data;
        return ScreenFrame(
          title: 'Goals',
          icon: Icons.track_changes,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snapshot.hasError)
                const ListTile(
                  leading: Icon(Icons.link),
                  title: Text('Pair the bridge to load live goal state.'),
                ),
              TextField(
                controller: _goalController,
                decoration: const InputDecoration(
                  labelText: '/goal objective',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final objective = _goalController.text.trim();
                  if (objective.isEmpty) {
                    return;
                  }
                  await widget.api.updateGoal(objective: objective);
                  if (mounted) {
                    _goalController.clear();
                  }
                },
                icon: const Icon(Icons.flag),
                label: const Text('Set /goal'),
              ),
              const SizedBox(height: 20),
              _GoalSummary(goal: state?.goal),
              const SizedBox(height: 20),
              _TaskList(tasks: state?.tasks ?? const []),
            ],
          ),
        );
      },
    );
  }
}

class _GoalSummary extends StatelessWidget {
  const _GoalSummary({required this.goal});

  final GoalRecord? goal;

  @override
  Widget build(BuildContext context) {
    if (goal == null) {
      return const SizedBox(
        height: 120,
        child: EmptyView(message: 'No /goal set yet.'),
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag),
        title: Text(goal!.objective),
        subtitle: Text('${goal!.status.name} · ${goal!.source}'),
        trailing: Text(goal!.updatedAt.toLocal().toString()),
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
        child: EmptyView(message: 'No task progress has been reported yet.'),
      );
    }

    return Column(
      children: [
        for (final task in tasks)
          Card(
            child: ListTile(
              leading: Icon(
                task.isComplete ? Icons.check_circle : Icons.timelapse,
              ),
              title: Text(task.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.summary),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: task.progressPercent / 100.0),
                ],
              ),
              trailing: Text('${task.progressPercent}%'),
            ),
          ),
      ],
    );
  }
}
