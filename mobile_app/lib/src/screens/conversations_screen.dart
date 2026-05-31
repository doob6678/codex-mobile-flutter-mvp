import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/codex_thread.dart';
import '../models/conversation.dart';
import 'screen_frame.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ConversationHistory>(
      future: _loadHistory(),
      builder: (context, snapshot) {
        return ScreenFrame(
          title: 'Conversations',
          icon: Icons.chat_bubble,
          child: _HistoryList(api: api, history: snapshot.data),
        );
      },
    );
  }

  Future<_ConversationHistory> _loadHistory() async {
    try {
      final groups = await api.listCodexThreadGroups();
      if (groups.isNotEmpty) {
        return _ConversationHistory(codexGroups: groups);
      }
    } catch (_) {
      // Fall back to Bridge-local conversations when app-server is unavailable.
    }

    return _ConversationHistory(
      bridgeConversations: await api.listConversations(),
      codexUnavailable: true,
    );
  }
}

class _ConversationHistory {
  const _ConversationHistory({
    this.codexGroups = const [],
    this.bridgeConversations = const [],
    this.codexUnavailable = false,
  });

  final List<CodexThreadGroup> codexGroups;
  final List<ConversationSummary> bridgeConversations;
  final bool codexUnavailable;
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.api, required this.history});

  final CodexMobileApi api;
  final _ConversationHistory? history;

  @override
  Widget build(BuildContext context) {
    if (history == null) {
      return const SizedBox(height: 240, child: LoadingView());
    }

    if (history!.codexGroups.isNotEmpty) {
      return _CodexThreadGroups(api: api, groups: history!.codexGroups);
    }

    return _ConversationList(
      conversations: history!.bridgeConversations,
      codexUnavailable: history!.codexUnavailable,
    );
  }
}

class _CodexThreadGroups extends StatelessWidget {
  const _CodexThreadGroups({required this.api, required this.groups});

  final CodexMobileApi api;
  final List<CodexThreadGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.projectName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final thread in group.threads)
            Card(
              child: ListTile(
                leading: _statusIcon(thread.status),
                title: Text(
                  thread.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  thread.preview.isEmpty ? group.projectPath : thread.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(_formatRelative(thread.updatedAt)),
                onTap: () => _showThreadDetails(context, thread),
              ),
            ),
        ],
      ],
    );
  }

  Icon _statusIcon(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('running') || normalized.contains('busy')) {
      return const Icon(Icons.sync, size: 20);
    }
    if (normalized.contains('complete') || normalized.contains('idle')) {
      return const Icon(Icons.check_circle_outline, size: 20);
    }
    return const Icon(Icons.radio_button_unchecked, size: 20);
  }

  void _showThreadDetails(BuildContext context, CodexThreadSummary thread) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => FutureBuilder<CodexThreadDetail>(
        future: api.readCodexThread(threadId: thread.id),
        builder: (context, snapshot) {
          final detail = snapshot.data;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: detail == null
                  ? const LoadingView()
                  : _ThreadDetailView(detail: detail),
            ),
          );
        },
      ),
    );
  }
}

class _ThreadDetailView extends StatelessWidget {
  const _ThreadDetailView({required this.detail});

  final CodexThreadDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detail.thread.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SelectableText(detail.thread.projectPath),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              if (detail.messages.isEmpty)
                SelectableText(detail.thread.preview)
              else
                for (final message in detail.messages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.role.toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(message.text),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.codexUnavailable,
  });

  final List<ConversationSummary> conversations;
  final bool codexUnavailable;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return const SizedBox(
        height: 240,
        child: EmptyView(message: 'No Codex thread history from the bridge yet.'),
      );
    }
    return Column(
      children: [
        if (codexUnavailable)
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Codex app-server history unavailable'),
            subtitle: Text('Showing Bridge-local conversations instead.'),
          ),
        for (final conversation in conversations)
          Card(
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(conversation.title),
              subtitle: Text(conversation.latestMessage),
              trailing: conversation.unreadCount > 0
                  ? Badge(label: Text('${conversation.unreadCount}'))
                  : Text(_formatTime(conversation.updatedAt)),
            ),
          ),
      ],
    );
  }
}

String _formatRelative(DateTime value) {
  final now = DateTime.now().toUtc();
  final delta = now.difference(value.toUtc());
  if (delta.inMinutes < 1) {
    return 'now';
  }
  if (delta.inHours < 1) {
    return '${delta.inMinutes}m';
  }
  if (delta.inDays < 1) {
    return '${delta.inHours}h';
  }
  if (delta.inDays < 7) {
    return '${delta.inDays}d';
  }
  final utc = value.toUtc();
  return '${utc.year}-${_two(utc.month)}-${_two(utc.day)}';
}

String _formatTime(DateTime value) {
  final utc = value.toUtc();
  return '${utc.year}-${_two(utc.month)}-${_two(utc.day)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
