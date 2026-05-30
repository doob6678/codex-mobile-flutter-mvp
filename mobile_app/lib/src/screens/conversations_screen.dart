import 'package:flutter/material.dart';

import '../api/codex_mobile_api.dart';
import '../models/conversation.dart';
import 'screen_frame.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConversationSummary>>(
      future: api.listConversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data;
        return ScreenFrame(
          title: 'Conversations',
          icon: Icons.chat_bubble,
          child: _ConversationList(conversations: conversations),
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.conversations});

  final List<ConversationSummary>? conversations;

  @override
  Widget build(BuildContext context) {
    if (conversations == null) {
      return const SizedBox(height: 240, child: LoadingView());
    }
    if (conversations!.isEmpty) {
      return const SizedBox(
        height: 240,
        child: EmptyView(message: 'No conversations from the bridge yet.'),
      );
    }
    return Column(
      children: [
        for (final conversation in conversations!)
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

  String _formatTime(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year}-${_two(utc.month)}-${_two(utc.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
