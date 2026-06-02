import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../api/codex_mobile_api.dart';
import '../models/codex_backend.dart';
import '../models/codex_file.dart';
import '../models/codex_thread.dart';
import '../models/conversation.dart';
import '../models/project.dart';
import '../models/sync_state.dart';
import 'file_manager_screen.dart';
import 'file_preview_screen.dart';
import 'screen_frame.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({required this.api, super.key});

  final CodexMobileApi api;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  Future<_ConversationHistory>? _future;
  _ConversationHistory? _cachedHistory;

  @override
  void initState() {
    super.initState();
    _future = _loadHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadHistory();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ConversationHistory>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _cachedHistory = snapshot.data;
        }
        final history = snapshot.data ?? _cachedHistory;
        return ScreenFrame(
          title: '对话',
          icon: Icons.chat_bubble,
          actions: [
            IconButton(
              tooltip: '刷新对话',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          child: _HistoryList(api: widget.api, history: history),
        );
      },
    );
  }

  Future<_ConversationHistory> _loadHistory() async {
    final cached = _cachedHistory;
    var codexUnavailable = false;
    CodexBackendStatus? codexStatus;
    var codexGroups = cached?.codexGroups ?? const <CodexThreadGroup>[];
    var bridgeConversations =
        cached?.bridgeConversations ?? const <ConversationSummary>[];

    try {
      codexStatus = await widget.api.getCodexStatus();
    } catch (error) {
      codexStatus = cached?.codexStatus ??
          CodexBackendStatus(
            available: false,
            message: error.toString(),
            checkedAt: DateTime.now().toUtc(),
          );
    }

    try {
      codexGroups = await widget.api.listCodexThreadGroups();
    } catch (error) {
      codexUnavailable = true;
      codexGroups = cached?.codexGroups ?? const <CodexThreadGroup>[];
    }

    try {
      bridgeConversations = await widget.api.listConversations();
    } catch (_) {
      bridgeConversations =
          cached?.bridgeConversations ?? const <ConversationSummary>[];
    }

    return _ConversationHistory(
      codexGroups: codexGroups,
      bridgeConversations: bridgeConversations,
      codexUnavailable: codexUnavailable,
      codexStatus: codexStatus,
    );
  }
}

class _ConversationHistory {
  const _ConversationHistory({
    this.codexGroups = const [],
    this.bridgeConversations = const [],
    this.codexUnavailable = false,
    this.codexStatus,
  });

  final List<CodexThreadGroup> codexGroups;
  final List<ConversationSummary> bridgeConversations;
  final bool codexUnavailable;
  final CodexBackendStatus? codexStatus;
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

    if (history!.codexGroups.isEmpty &&
        history!.bridgeConversations.isEmpty) {
      return const SizedBox(
        height: 240,
        child: EmptyView(message: '还没有可显示的 Windows Codex 对话历史或 Bridge 会话。'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (history!.codexStatus != null) ...[
          _CodexBackendStatusCard(status: history!.codexStatus!),
          const SizedBox(height: 12),
        ],
        _SectionHeader(
          icon: Icons.computer_outlined,
          title: 'Windows Codex 历史',
          subtitle: history!.codexUnavailable
              ? 'Codex app-server 抖动时会保留上一次读取到的 Windows 历史。'
              : '来自 Windows Codex 的真实历史线程，点开后可继续发送到 Windows。',
        ),
        if (history!.codexGroups.isEmpty)
          const SizedBox(
            height: 120,
            child: EmptyView(message: '还没有读取到 Windows Codex 历史。'),
          )
        else
          _CodexThreadGroups(api: api, groups: history!.codexGroups),
        const SizedBox(height: 20),
        _SectionHeader(
          icon: Icons.forum_outlined,
          title: '手机发起的 Windows 会话',
          subtitle: '从手机创建的会话会绑定同一个 Windows Codex 线程，后续继续发送到 Windows。',
        ),
        _ConversationList(
          api: api,
          conversations: history!.bridgeConversations,
        ),
      ],
    );
  }
}

class _CodexBackendStatusCard extends StatelessWidget {
  const _CodexBackendStatusCard({required this.status});

  final CodexBackendStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.available
        ? const Color(0xFF166534)
        : const Color(0xFF92400E);
    final background = status.available
        ? const Color(0xFFEFFDF4)
        : const Color(0xFFFFFBEB);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status.available
                ? Icons.cloud_done_outlined
                : Icons.history_toggle_off_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Codex 后端：${status.label}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.available
                      ? status.message
                      : '${status.message}；当前读取 Windows 本机历史，发送时会自动恢复 Codex 线程。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF111827)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexThreadGroups extends StatelessWidget {
  const _CodexThreadGroups({required this.api, required this.groups});

  static const int _initialThreadLimit = 8;

  final CodexMobileApi api;
  final List<CodexThreadGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          _CodexProjectGroupTile(
            group: group,
            initialThreadLimit: _initialThreadLimit,
            onThreadTap: (thread) => _showThreadDetails(context, thread),
          ),
        ],
      ],
    );
  }

  void _showThreadDetails(BuildContext context, CodexThreadSummary thread) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ThreadDetailPage(
          api: api,
          thread: thread,
        ),
      ),
    );
  }
}

class _CodexProjectGroupTile extends StatefulWidget {
  const _CodexProjectGroupTile({
    required this.group,
    required this.initialThreadLimit,
    required this.onThreadTap,
  });

  final CodexThreadGroup group;
  final int initialThreadLimit;
  final ValueChanged<CodexThreadSummary> onThreadTap;

  @override
  State<_CodexProjectGroupTile> createState() => _CodexProjectGroupTileState();
}

class _CodexProjectGroupTileState extends State<_CodexProjectGroupTile> {
  bool _showAllThreads = false;

  @override
  Widget build(BuildContext context) {
    final threads = widget.group.threads
        .where((thread) => !thread.isSubagent)
        .toList(growable: false);
    final visibleThreads = _showAllThreads
        ? threads
        : threads.take(widget.initialThreadLimit).toList(growable: false);
    final hiddenCount = threads.length - visibleThreads.length;

    return ExpansionTile(
      key: PageStorageKey('codex-project:${widget.group.projectPath}'),
      initiallyExpanded: false,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.folder_outlined, size: 20),
      title: Text(
        widget.group.projectName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${threads.length} 个对话',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        for (final thread in visibleThreads)
          ListTile(
            dense: true,
            leading: _ThreadStatusIcon(status: thread.status),
            title: Text(
              thread.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              thread.preview.isEmpty ? widget.group.projectPath : thread.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(_formatRelative(thread.updatedAt)),
            onTap: () => widget.onThreadTap(thread),
          ),
        if (hiddenCount > 0 || _showAllThreads)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllThreads = !_showAllThreads;
                });
              },
              icon: Icon(
                _showAllThreads
                    ? Icons.unfold_less_outlined
                    : Icons.unfold_more_outlined,
              ),
              label: Text(_showAllThreads ? '收起旧对话' : '显示其余 $hiddenCount 个旧对话'),
            ),
          ),
      ],
    );
  }
}

class _ThreadStatusIcon extends StatelessWidget {
  const _ThreadStatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    if (normalized.contains('running') || normalized.contains('busy')) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(value: 0.35, strokeWidth: 2),
      );
    }
    if (normalized.contains('complete') || normalized.contains('idle')) {
      return const Icon(Icons.check_circle_outline, size: 20);
    }
    return const Icon(Icons.radio_button_unchecked, size: 20);
  }
}

class _ThreadDetailPage extends StatefulWidget {
  const _ThreadDetailPage({required this.api, required this.thread});

  final CodexMobileApi api;
  final CodexThreadSummary thread;

  @override
  State<_ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends State<_ThreadDetailPage> {
  late Future<CodexThreadDetail> _future;
  CodexThreadDetail? _cachedDetail;

  @override
  void initState() {
    super.initState();
    _future = widget.api.readCodexThread(threadId: widget.thread.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.thread.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<CodexThreadDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _cachedDetail = snapshot.data;
            }
            final detail = snapshot.data ?? _cachedDetail;
            if (detail == null) {
              return snapshot.hasError
                  ? _ConversationErrorView(error: snapshot.error)
                  : const LoadingView();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: _ThreadDetailView(api: widget.api, detail: detail),
            );
          },
        ),
      ),
    );
  }
}

class _ThreadDetailView extends StatefulWidget {
  const _ThreadDetailView({required this.api, required this.detail});

  final CodexMobileApi api;
  final CodexThreadDetail detail;

  @override
  State<_ThreadDetailView> createState() => _ThreadDetailViewState();
}

class _ThreadDetailViewState extends State<_ThreadDetailView> {
  static const Duration _passiveRefreshInterval = Duration(seconds: 2);

  final TextEditingController _promptController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  late CodexThreadDetail _detail;
  bool _sending = false;
  bool _showTechnicalMessages = false;
  String? _statusMessage;
  String? _error;
  String? _streamingReply;
  String? _pendingPrompt;
  CodexSyncSnapshot? _syncState;
  DateTime? _sendStartedAt;
  StreamSubscription<CodexSyncSnapshot>? _syncSubscription;
  Timer? _passiveRefreshTimer;
  bool _passiveRefreshInFlight = false;
  int _sendGeneration = 0;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    _scrollMessagesToEnd();
    _refreshThreadOnce();
    _startPassiveThreadRefresh();
  }

  @override
  void dispose() {
    _sendGeneration += 1;
    _passiveRefreshTimer?.cancel();
    _syncSubscription?.cancel();
    _promptController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetadataRow(
          icon: Icons.folder_outlined,
          text: _detail.thread.projectPath,
        ),
        const SizedBox(height: 10),
        if (_syncState != null) ...[
          _ConversationSyncStrip(
            state: _syncState!,
            threadId: _detail.thread.id,
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showTechnicalMessages = !_showTechnicalMessages;
                });
              },
              icon: Icon(
                _showTechnicalMessages
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              label: Text(
                _showTechnicalMessages ? '隐藏技术消息' : '显示技术消息',
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '已隐藏 ${_hiddenMessageCount(_detail.messages)} 条技术消息',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Stack(
            children: [
              ListView(
                controller: _messagesScrollController,
                padding: const EdgeInsets.only(bottom: 52),
                children: [
                  if (_visibleMessages(_detail.messages).isEmpty)
                    SelectableText(_detail.thread.preview)
                  else
                    for (final message in _visibleMessages(_detail.messages))
                      _ThreadMessageBubble(
                        api: widget.api,
                        workingDirectory: _detail.thread.projectPath,
                        role: message.role,
                        text: message.text,
                      ),
                  if (_sending)
                    _ThreadMessageBubble(
                      api: widget.api,
                      workingDirectory: _detail.thread.projectPath,
                      role: 'assistant',
                      text: _streamingReply?.trim().isNotEmpty == true
                          ? _streamingReply!
                          : '正在等待 Windows Codex 回复...',
                      pending: true,
                    ),
                ],
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: _ScrollToBottomButton(onPressed: _scrollMessagesToEnd),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('codex-turn-prompt-field'),
          controller: _promptController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '继续对话',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Tooltip(
              message: '发送到 Windows Codex',
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendTurn,
                icon: const Icon(Icons.send),
                label: const Text('发送到 Windows Codex'),
              ),
            ),
            const SizedBox(width: 12),
            if (_sending) const CircularProgressIndicator(),
          ],
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage!,
            style: const TextStyle(color: Color(0xFF166534)),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  List<CodexThreadMessage> _visibleMessages(List<CodexThreadMessage> messages) {
    if (_showTechnicalMessages) {
      return messages;
    }
    return messages
        .where((message) => !_isTechnicalMessage(message.role))
        .toList(growable: false);
  }

  int _hiddenMessageCount(List<CodexThreadMessage> messages) {
    return messages.where((message) => _isTechnicalMessage(message.role)).length;
  }

  bool _isTechnicalMessage(String role) {
    final normalized = role.toLowerCase();
    return normalized == 'command' ||
        normalized == 'reasoning' ||
        normalized == 'plan' ||
        normalized == 'tool' ||
        normalized == 'system';
  }

  Future<void> _refreshThreadOnce() async {
    try {
      final state = await widget.api.getSyncState();
      final refreshed = await widget.api.readCodexThread(
        threadId: _detail.thread.id,
      );
      if (!mounted) {
        return;
      }
      final messagesChanged = _threadMessagesChanged(_detail, refreshed);
      setState(() {
        _syncState = state;
        _detail = refreshed;
        _statusMessage = _latestProgressMessage(
              state,
              threadId: _detail.thread.id,
            ) ??
            _statusMessage;
      });
      if (messagesChanged) {
        _scrollMessagesToEnd();
      }
    } catch (_) {
    }
  }

  void _startPassiveThreadRefresh() {
    _passiveRefreshTimer?.cancel();
    _passiveRefreshTimer = Timer.periodic(_passiveRefreshInterval, (_) async {
      if (!mounted || _sending || _passiveRefreshInFlight) {
        return;
      }

      _passiveRefreshInFlight = true;
      try {
        await _refreshThreadOnce();
      } finally {
        _passiveRefreshInFlight = false;
      }
    });
  }

  Future<void> _sendTurn() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = '请输入要发送给 Windows Codex 的内容。');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _streamingReply = null;
      _pendingPrompt = prompt;
      _sendStartedAt = DateTime.now().toUtc();
      _statusMessage = '已提交，等待 Bridge 投递到 Windows Codex';
      _detail = CodexThreadDetail(
        thread: _detail.thread,
        messages: [
          ..._detail.messages,
          CodexThreadMessage(role: 'user', text: prompt),
        ],
      );
    });
    _scrollMessagesToEnd();
    final generation = ++_sendGeneration;
    _watchThreadSyncProgress(generation);
    _trackThreadProgress(generation);

    try {
      final updated = await widget.api.startCodexTurn(
        threadId: _detail.thread.id,
        prompt: prompt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _streamingReply = null;
        _pendingPrompt = null;
        _statusMessage = '已发送到 Windows Codex';
        _promptController.clear();
        _detail = updated;
      });
      await _syncSubscription?.cancel();
      _scrollMessagesToEnd();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _streamingReply = null;
        _pendingPrompt = null;
        _error = error.toString();
      });
      await _syncSubscription?.cancel();
    }
  }

  void _watchThreadSyncProgress(int generation) {
    _syncSubscription?.cancel();
    _syncSubscription = widget.api.watchSyncState().listen(
      (state) {
        if (!mounted || !_sending || generation != _sendGeneration) {
          return;
        }

        final message = _latestProgressMessage(
          state,
          threadId: _detail.thread.id,
        );
        final draft = _streamingAssistantDraft(
          state,
          threadId: _detail.thread.id,
          since: _sendStartedAt,
        );
        setState(() {
          _syncState = state;
          if (message != null) {
            _statusMessage = message;
          }
          if (draft.trim().isNotEmpty) {
            _streamingReply = draft;
          }
        });
        _scrollMessagesToEnd();
      },
      onError: (_) {},
    );
  }

  Future<void> _trackThreadProgress(int generation) async {
    while (mounted && _sending && generation == _sendGeneration) {
      try {
        final state = await widget.api.getSyncState();
        final message = _latestProgressMessage(
          state,
          threadId: _detail.thread.id,
        );
        final draft = _streamingAssistantDraft(
          state,
          threadId: _detail.thread.id,
          since: _sendStartedAt,
        );
        final refreshed = await widget.api.readCodexThread(
          threadId: _detail.thread.id,
        );
        final historyDraft = _assistantTextAfterPrompt(
          refreshed.messages,
          _pendingPrompt,
          textOf: (message) => message.text,
          roleOf: (message) => message.role,
        );
        if (!mounted || generation != _sendGeneration) {
          return;
        }
        setState(() {
          _syncState = state;
          if (message != null) {
            _statusMessage = message;
          }
          final displayDraft = draft.trim().isNotEmpty ? draft : historyDraft;
          if (displayDraft.trim().isNotEmpty) {
            _streamingReply = displayDraft;
          }
          _detail = displayDraft.trim().isNotEmpty
              ? CodexThreadDetail(
                  thread: refreshed.thread,
                  messages: _withoutAssistantTextAfterPrompt(
                    refreshed.messages,
                    _pendingPrompt,
                    textOf: (message) => message.text,
                    roleOf: (message) => message.role,
                  ),
                )
              : refreshed;
        });
        _scrollMessagesToEnd();
      } catch (_) {
      }

      if (!mounted || !_sending || generation != _sendGeneration) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _scrollMessagesToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) {
        return;
      }
      _messagesScrollController.jumpTo(
        _messagesScrollController.position.maxScrollExtent,
      );
    });
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.api, required this.conversations});

  final CodexMobileApi api;
  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return const SizedBox(
        height: 240,
        child: EmptyView(message: 'Bridge 里还没有可显示的 Codex 对话历史。'),
      );
    }
    return Column(
      children: [
        for (final conversation in conversations)
          Card(
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(conversation.title),
              subtitle: Text(conversation.latestMessage),
              trailing: conversation.unreadCount > 0
                  ? Badge(label: Text('${conversation.unreadCount}'))
                  : Text(_formatTime(conversation.updatedAt)),
              onTap: () => _showConversationDetails(context, conversation),
            ),
          ),
      ],
    );
  }

  void _showConversationDetails(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ConversationDetailPage(
          api: api,
          conversation: conversation,
        ),
      ),
    );
  }
}

class _BridgeConversationDetailView extends StatefulWidget {
  const _BridgeConversationDetailView({required this.api, required this.detail});

  final CodexMobileApi api;
  final ConversationDetail detail;

  @override
  State<_BridgeConversationDetailView> createState() =>
      _BridgeConversationDetailViewState();
}

class _BridgeConversationDetailViewState
    extends State<_BridgeConversationDetailView> {
  static const Duration _passiveRefreshInterval = Duration(seconds: 2);

  final TextEditingController _promptController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  late ConversationDetail _detail;
  bool _sending = false;
  String? _statusMessage;
  String? _error;
  String? _streamingReply;
  String? _pendingPrompt;
  CodexSyncSnapshot? _syncState;
  DateTime? _sendStartedAt;
  StreamSubscription<CodexSyncSnapshot>? _syncSubscription;
  Timer? _passiveRefreshTimer;
  bool _passiveRefreshInFlight = false;
  int _sendGeneration = 0;

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    _scrollMessagesToEnd();
    _refreshConversationOnce();
    _startPassiveConversationRefresh();
  }

  @override
  void dispose() {
    _sendGeneration += 1;
    _passiveRefreshTimer?.cancel();
    _syncSubscription?.cancel();
    _promptController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final conversation = detail.conversation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (conversation.workingDirectory.isNotEmpty) ...[
          _MetadataRow(
            icon: Icons.folder_outlined,
            text: conversation.workingDirectory,
          ),
          const SizedBox(height: 10),
        ],
        if (_syncState != null) ...[
          _ConversationSyncStrip(
            state: _syncState!,
            threadId: conversation.codexThreadId,
            conversationId: conversation.id,
          ),
          const SizedBox(height: 10),
        ],
        if (detail.codexThreadError != null) ...[
          const SizedBox(height: 2),
          _CodexThreadErrorBanner(error: detail.codexThreadError!),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: Stack(
            children: [
              ListView(
                controller: _messagesScrollController,
                padding: const EdgeInsets.only(bottom: 52),
                children: [
                  if (detail.messages.isEmpty)
                    const SelectableText('这条 Bridge 会话还没有消息。')
                  else
                    for (final message in detail.messages)
                      _ThreadMessageBubble(
                        api: widget.api,
                        projectId: conversation.projectId,
                        workingDirectory: conversation.workingDirectory,
                        role: message.role,
                        text: message.content,
                      ),
                  if (_sending)
                    _ThreadMessageBubble(
                      api: widget.api,
                      projectId: conversation.projectId,
                      workingDirectory: conversation.workingDirectory,
                      role: 'assistant',
                      text: _streamingReply?.trim().isNotEmpty == true
                          ? _streamingReply!
                          : '正在等待 Windows Codex 回复...',
                      pending: true,
                    ),
                ],
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: _ScrollToBottomButton(onPressed: _scrollMessagesToEnd),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('bridge-conversation-prompt-field'),
          controller: _promptController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '继续 Windows 对话',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Tooltip(
              message: '发送到 Windows Codex',
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendMessage,
                icon: const Icon(Icons.send),
                label: const Text('发送到 Windows Codex'),
              ),
            ),
            const SizedBox(width: 12),
            if (_sending) const CircularProgressIndicator(),
          ],
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage!,
            style: const TextStyle(color: Color(0xFF166534)),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _sendMessage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = '请输入要发送到 Bridge 会话的内容。');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _streamingReply = null;
      _pendingPrompt = prompt;
      _sendStartedAt = DateTime.now().toUtc();
      _statusMessage = '已提交，等待 Bridge 投递到 Windows Codex';
      _detail = ConversationDetail(
        conversation: _detail.conversation,
        messages: [
          ..._detail.messages,
          ConversationMessage(
            id: 'pending_user_${DateTime.now().microsecondsSinceEpoch}',
            conversationId: _detail.conversation.id,
            role: 'user',
            content: prompt,
            createdAt: DateTime.now().toUtc(),
          ),
        ],
        codexThreadError: _detail.codexThreadError,
      );
    });
    _scrollMessagesToEnd();
    final generation = ++_sendGeneration;
    _watchConversationSyncProgress(generation);
    _trackConversationProgress(generation);

    try {
      final updated = await widget.api.sendConversationMessage(
        conversationId: _detail.conversation.id,
        content: prompt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _streamingReply = null;
        _pendingPrompt = null;
        _statusMessage = '已发送到 Windows Codex';
        _promptController.clear();
        _detail = updated;
      });
      await _syncSubscription?.cancel();
      _scrollMessagesToEnd();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _streamingReply = null;
        _pendingPrompt = null;
        _error = error.toString();
      });
      await _syncSubscription?.cancel();
    }
  }

  Future<void> _refreshConversationOnce() async {
    try {
      final state = await widget.api.getSyncState();
      final refreshed = await widget.api.readConversation(
        conversationId: _detail.conversation.id,
      );
      if (!mounted) {
        return;
      }
      final messagesChanged = _conversationMessagesChanged(_detail, refreshed);
      setState(() {
        _syncState = state;
        _detail = refreshed;
        _statusMessage = _latestProgressMessage(
              state,
              conversationId: _detail.conversation.id,
              threadId: _detail.conversation.codexThreadId,
            ) ??
            _statusMessage;
      });
      if (messagesChanged) {
        _scrollMessagesToEnd();
      }
    } catch (_) {
    }
  }

  void _startPassiveConversationRefresh() {
    _passiveRefreshTimer?.cancel();
    _passiveRefreshTimer = Timer.periodic(_passiveRefreshInterval, (_) async {
      if (!mounted || _sending || _passiveRefreshInFlight) {
        return;
      }

      _passiveRefreshInFlight = true;
      try {
        await _refreshConversationOnce();
      } finally {
        _passiveRefreshInFlight = false;
      }
    });
  }

  Future<void> _trackConversationProgress(int generation) async {
    while (mounted && _sending && generation == _sendGeneration) {
      try {
        final state = await widget.api.getSyncState();
        final message = _latestProgressMessage(
          state,
          conversationId: _detail.conversation.id,
          threadId: _detail.conversation.codexThreadId,
        );
        final draft = _streamingAssistantDraft(
          state,
          threadId: _detail.conversation.codexThreadId,
          since: _sendStartedAt,
        );
        final refreshed = await widget.api.readConversation(
          conversationId: _detail.conversation.id,
        );
        final historyDraft = _assistantTextAfterPrompt(
          refreshed.messages,
          _pendingPrompt,
          textOf: (message) => message.content,
          roleOf: (message) => message.role,
        );
        if (!mounted || generation != _sendGeneration) {
          return;
        }
        setState(() {
          _syncState = state;
          if (message != null) {
            _statusMessage = message;
          }
          final displayDraft = draft.trim().isNotEmpty ? draft : historyDraft;
          if (displayDraft.trim().isNotEmpty) {
            _streamingReply = displayDraft;
          }
          _detail = displayDraft.trim().isNotEmpty
              ? ConversationDetail(
                  conversation: refreshed.conversation,
                  messages: _withoutAssistantTextAfterPrompt(
                    refreshed.messages,
                    _pendingPrompt,
                    textOf: (message) => message.content,
                    roleOf: (message) => message.role,
                  ),
                  codexThreadError: refreshed.codexThreadError,
                )
              : refreshed;
        });
        _scrollMessagesToEnd();
      } catch (_) {
      }

      if (!mounted || !_sending || generation != _sendGeneration) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  void _watchConversationSyncProgress(int generation) {
    _syncSubscription?.cancel();
    _syncSubscription = widget.api.watchSyncState().listen(
      (state) {
        if (!mounted || !_sending || generation != _sendGeneration) {
          return;
        }

        final message = _latestProgressMessage(
          state,
          conversationId: _detail.conversation.id,
          threadId: _detail.conversation.codexThreadId,
        );
        final draft = _streamingAssistantDraft(
          state,
          threadId: _detail.conversation.codexThreadId,
          since: _sendStartedAt,
        );
        setState(() {
          _syncState = state;
          if (message != null) {
            _statusMessage = message;
          }
          if (draft.trim().isNotEmpty) {
            _streamingReply = draft;
          }
        });
        _scrollMessagesToEnd();
      },
      onError: (_) {},
    );
  }

  void _scrollMessagesToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) {
        return;
      }
      _messagesScrollController.jumpTo(
        _messagesScrollController.position.maxScrollExtent,
      );
    });
  }
}

class _ConversationDetailPage extends StatefulWidget {
  const _ConversationDetailPage({
    required this.api,
    required this.conversation,
  });

  final CodexMobileApi api;
  final ConversationSummary conversation;

  @override
  State<_ConversationDetailPage> createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<_ConversationDetailPage> {
  late Future<ConversationDetail> _future;
  ConversationDetail? _cachedDetail;

  @override
  void initState() {
    super.initState();
    _future = widget.api.readConversation(conversationId: widget.conversation.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<ConversationDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _cachedDetail = snapshot.data;
            }
            final detail = snapshot.data ?? _cachedDetail;
            if (detail == null) {
              return snapshot.hasError
                  ? _ConversationErrorView(error: snapshot.error)
                  : const LoadingView();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: _BridgeConversationDetailView(api: widget.api, detail: detail),
            );
          },
        ),
      ),
    );
  }
}

class _ThreadMessageBubble extends StatelessWidget {
  const _ThreadMessageBubble({
    required this.role,
    required this.text,
    this.api,
    this.projectId,
    this.workingDirectory,
    this.pending = false,
  });

  final CodexMobileApi? api;
  final String? projectId;
  final String? workingDirectory;
  final String role;
  final String text;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final normalized = role.toLowerCase();
    final isUser = normalized == 'user';
    final label = isUser ? 'USER' : 'ASSISTANT';
    final bubbleColor = isUser ? const Color(0xFF111827) : Colors.white;
    final textColor = isUser ? Colors.white : const Color(0xFF111827);
    final borderColor = isUser ? const Color(0xFF111827) : const Color(0xFFE5E7EB);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.86,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isUser ? Colors.white70 : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MarkdownBody(
                    data: linkifyConversationFileReferences(text),
                    selectable: true,
                    onTapLink: (label, href, title) => _openReferencedFile(
                      context,
                      href?.trim().isNotEmpty == true ? href! : label,
                    ),
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: pending
                                ? const Color(0xFF6B7280)
                                : textColor,
                          ),
                          code: TextStyle(
                            color: textColor,
                            fontFamily: 'monospace',
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openReferencedFile(BuildContext context, String target) async {
    final activeApi = api;
    if (activeApi == null) {
      return;
    }

    final candidate = normalizeConversationFileReference(target);
    if (candidate.isEmpty) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final resolved = await _resolveProjectFile(activeApi, candidate);
      if (resolved == null) {
        messenger.showSnackBar(SnackBar(content: Text('没有在当前目录匹配到文件：$candidate')));
        return;
      }

      if (resolved.isDirectory) {
        if (!context.mounted) {
          return;
        }
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => FileManagerScreen(
              api: activeApi,
              initialProjectId: resolved.projectId,
            ),
          ),
        );
        return;
      }

      if (resolved.isBinaryPreview) {
        final downloaded = await activeApi.downloadFile(
          projectId: resolved.projectId,
          path: resolved.path,
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

      final preview = await activeApi.readFile(
        projectId: resolved.projectId,
        path: resolved.path,
      );
      if (!context.mounted) {
        return;
      }
      await navigator.push(
        MaterialPageRoute(builder: (_) => FilePreviewScreen(preview: preview)),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<_ResolvedConversationFile?> _resolveProjectFile(
    CodexMobileApi activeApi,
    String candidate,
  ) async {
    final projects = await activeApi.listProjects();
    ProjectSummary? project;
    var basePath = '';
    var target = candidate;

    final absolute = matchProjectByAbsolutePath(projects, candidate);
    if (absolute != null) {
      project = absolute.project;
      target = absolute.basePath;
    }

    if (project == null && projectId != null && projectId!.trim().isNotEmpty) {
      for (final item in projects) {
        if (item.id == projectId) {
          project = item;
          break;
        }
      }
    }

    if (project == null) {
      final matched = matchProjectByWorkingDirectory(projects, workingDirectory);
      project = matched?.project;
      basePath = matched?.basePath ?? '';
    }

    if (project == null) {
      return null;
    }

    if (basePath.isEmpty) {
      final matched = matchProjectByWorkingDirectory([project], workingDirectory);
      basePath = matched?.basePath ?? '';
    }

    for (final path in _candidatePaths(basePath, target)) {
      final listed = await _tryListPath(activeApi, project.id, path);
      if (listed != null && (listed.isNotEmpty || !_hasKnownFileExtension(path))) {
        return _ResolvedConversationFile(
          projectId: project.id,
          path: path,
          isDirectory: true,
          isBinaryPreview: false,
        );
      }

      try {
        if (_looksLikeBinaryPreview(path)) {
          await activeApi.downloadFile(projectId: project.id, path: path);
          return _ResolvedConversationFile(
            projectId: project.id,
            path: path,
            isDirectory: false,
            isBinaryPreview: true,
          );
        }

        await activeApi.readFile(projectId: project.id, path: path);
        return _ResolvedConversationFile(
          projectId: project.id,
          path: path,
          isDirectory: false,
          isBinaryPreview: false,
        );
      } catch (_) {
      }
    }

    return null;
  }
}

String linkifyConversationFileReferences(String source) {
  if (source.contains('](')) {
    return source;
  }

  final pattern = RegExp(
    r'(^|[\s:：])([^\s\[\]()<>"`]+(?:\.html|\.htm|\.md|\.markdown|\.pdf|\.png|\.jpg|\.jpeg|\.webp|\.gif|\.txt|_assets))(?=$|[\s，。；;、])',
    caseSensitive: false,
    multiLine: true,
  );
  return source.replaceAllMapped(pattern, (match) {
    final prefix = match.group(1) ?? '';
    final token = match.group(2) ?? '';
    if (token.startsWith('http://') ||
        token.startsWith('https://') ||
        token.startsWith('file-ref:')) {
      return match.group(0) ?? token;
    }
    return '$prefix[$token](file-ref:$token)';
  });
}

String normalizeConversationFileReference(String target) {
  var value = target.trim();
  if (value.startsWith('file-ref:')) {
    value = value.substring('file-ref:'.length);
  }
  value = _decodeFileReference(value);
  return value
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'^\./+'), '')
      .replaceAll(RegExp(r'[，。；;:：、]+$'), '')
      .trim();
}

String _decodeFileReference(String value) {
  try {
    return Uri.decodeFull(value);
  } catch (_) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }
}

Iterable<String> _candidatePaths(String basePath, String candidate) sync* {
  final normalizedCandidate = candidate.replaceAll('\\', '/');
  final normalizedBase = basePath.replaceAll('\\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
  if (normalizedBase.isNotEmpty) {
    yield '$normalizedBase/$normalizedCandidate';
  }
  yield normalizedCandidate;
}

Future<List<CodexFile>?> _tryListPath(
  CodexMobileApi api,
  String projectId,
  String path,
) async {
  try {
    return await api.listFiles(projectId: projectId, path: path);
  } catch (_) {
    return null;
  }
}

bool _looksLikeBinaryPreview(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.pdf') ||
      lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.svg');
}

bool _hasKnownFileExtension(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.html') ||
      lower.endsWith('.htm') ||
      lower.endsWith('.md') ||
      lower.endsWith('.markdown') ||
      lower.endsWith('.pdf') ||
      lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.svg') ||
      lower.endsWith('.txt');
}

ConversationProjectMatch? matchProjectByWorkingDirectory(
  List<ProjectSummary> projects,
  String? workingDirectory,
) {
  final cwd = _normalizeWindowsPath(workingDirectory ?? '');
  if (cwd.isEmpty) {
    return null;
  }

  for (final project in projects) {
    final root = _normalizeWindowsPath(project.rootPath);
    if (root.isEmpty) {
      continue;
    }

    if (cwd == root) {
      return ConversationProjectMatch(project, '');
    }

    if (cwd.startsWith('$root/')) {
      return ConversationProjectMatch(project, cwd.substring(root.length + 1));
    }
  }

  return null;
}

ConversationProjectMatch? matchProjectByAbsolutePath(
  List<ProjectSummary> projects,
  String target,
) {
  final normalized = _normalizeWindowsPath(target);
  if (!_looksLikeAbsolutePath(normalized)) {
    return null;
  }

  ConversationProjectMatch? best;
  var bestRootLength = -1;
  for (final project in projects) {
    final root = _normalizeWindowsPath(project.rootPath);
    if (root.isEmpty) {
      continue;
    }

    if (normalized == root || normalized.startsWith('$root/')) {
      final relative = normalized == root ? '' : normalized.substring(root.length + 1);
      if (root.length > bestRootLength) {
        best = ConversationProjectMatch(project, relative);
        bestRootLength = root.length;
      }
    }
  }

  return best;
}

bool _looksLikeAbsolutePath(String path) {
  return RegExp(r'^[a-z]:/').hasMatch(path) || path.startsWith('/');
}

String _normalizeWindowsPath(String path) {
  return path
      .trim()
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '')
      .toLowerCase();
}

String? _latestProgressMessage(
  CodexSyncSnapshot state, {
  String? threadId,
  String? conversationId,
}) {
  for (final event in state.events.reversed) {
    if (!_eventMatches(event, threadId: threadId, conversationId: conversationId)) {
      continue;
    }

    final message = event.message.trim();
    if (message.isNotEmpty) {
      return message;
    }
  }

  return null;
}

String _streamingAssistantDraft(
  CodexSyncSnapshot state, {
  String? threadId,
  DateTime? since,
}) {
  final buffer = StringBuffer();
  for (final event in state.events) {
    if (event.type != 'codex.appserver.notification') {
      continue;
    }

    if (since != null && event.timestamp.isBefore(since)) {
      continue;
    }

    final method = (event.payload['method'] ?? '').toString();
    if (method != 'item/agentMessage/delta') {
      continue;
    }

    final payloadThreadId = (event.payload['threadId'] ?? '').toString();
    if (threadId != null &&
        threadId.isNotEmpty &&
        payloadThreadId.isNotEmpty &&
        payloadThreadId != threadId) {
      continue;
    }
    if (threadId != null &&
        threadId.isNotEmpty &&
        payloadThreadId.isEmpty &&
        since == null) {
      continue;
    }

    final delta = (event.payload['delta'] ?? '').toString();
    if (delta.isNotEmpty) {
      buffer.write(delta);
    }
  }

  return buffer.toString();
}

String _assistantTextAfterPrompt<T>(
  List<T> messages,
  String? prompt, {
  required String Function(T message) textOf,
  required String Function(T message) roleOf,
}) {
  if (prompt == null || prompt.trim().isEmpty) {
    return '';
  }

  var sawPrompt = false;
  var latestAssistant = '';
  for (final message in messages) {
    final role = roleOf(message).trim().toLowerCase();
    final text = textOf(message).trim();
    if (!sawPrompt && role == 'user' && _matchesPromptText(text, prompt)) {
      sawPrompt = true;
      continue;
    }
    if (sawPrompt && role == 'assistant' && text.isNotEmpty) {
      latestAssistant = text;
    }
  }

  return latestAssistant;
}

List<T> _withoutAssistantTextAfterPrompt<T>(
  List<T> messages,
  String? prompt, {
  required String Function(T message) textOf,
  required String Function(T message) roleOf,
}) {
  if (prompt == null || prompt.trim().isEmpty) {
    return messages;
  }

  var sawPrompt = false;
  var removeIndex = -1;
  for (var index = 0; index < messages.length; index += 1) {
    final message = messages[index];
    final role = roleOf(message).trim().toLowerCase();
    final text = textOf(message).trim();
    if (!sawPrompt && role == 'user' && _matchesPromptText(text, prompt)) {
      sawPrompt = true;
      continue;
    }
    if (sawPrompt && role == 'assistant' && text.isNotEmpty) {
      removeIndex = index;
    }
  }

  if (removeIndex < 0) {
    return messages;
  }

  return [
    for (var index = 0; index < messages.length; index += 1)
      if (index != removeIndex) messages[index],
  ];
}

bool _matchesPromptText(String messageText, String prompt) {
  final message = messageText.trim();
  final value = prompt.trim();
  return message == value || message.contains(value) || value.contains(message);
}

bool _threadMessagesChanged(
  CodexThreadDetail previous,
  CodexThreadDetail next,
) {
  if (previous.messages.length != next.messages.length) {
    return true;
  }

  for (var index = 0; index < previous.messages.length; index += 1) {
    final left = previous.messages[index];
    final right = next.messages[index];
    if (left.role != right.role || left.text != right.text) {
      return true;
    }
  }

  return false;
}

bool _conversationMessagesChanged(
  ConversationDetail previous,
  ConversationDetail next,
) {
  if (previous.messages.length != next.messages.length) {
    return true;
  }

  for (var index = 0; index < previous.messages.length; index += 1) {
    final left = previous.messages[index];
    final right = next.messages[index];
    if (left.role != right.role || left.content != right.content) {
      return true;
    }
  }

  return false;
}

bool _eventMatches(
  CodexSyncEvent event, {
  String? threadId,
  String? conversationId,
}) {
  final payloadThreadId = (event.payload['threadId'] ?? '').toString();
  final payloadConversationId = (event.payload['conversationId'] ?? '').toString();
  if (threadId != null && threadId.isNotEmpty && payloadThreadId == threadId) {
    return true;
  }
  if (conversationId != null &&
      conversationId.isNotEmpty &&
      payloadConversationId == conversationId) {
    return true;
  }
  return event.type.startsWith('codex.appserver.notification') &&
      (threadId == null || threadId.isEmpty);
}

class _ConversationSyncStrip extends StatelessWidget {
  const _ConversationSyncStrip({
    required this.state,
    this.threadId,
    this.conversationId,
  });

  final CodexSyncSnapshot state;
  final String? threadId;
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final goal = _currentThreadGoal(state, threadId);
    final task = _currentRunningTask(state, threadId: threadId, conversationId: conversationId);
    if (goal == null && task == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (goal != null)
          _CompactStatusRow(
            icon: Icons.flag_outlined,
            label: '/goal',
            text: goal.objective,
            trailing: goal.status.name,
          ),
        if (goal != null && task != null) const SizedBox(height: 6),
        if (task != null)
          _CompactStatusRow(
            icon: _taskIsActive(task)
                ? Icons.radio_button_checked
                : Icons.task_alt_outlined,
            label: '任务',
            text: task.title,
            trailing: '${task.progressPercent}%',
            busy: _taskIsActive(task),
          ),
      ],
    );
  }
}

class _CompactStatusRow extends StatelessWidget {
  const _CompactStatusRow({
    required this.icon,
    required this.label,
    required this.text,
    required this.trailing,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final String text;
  final String trailing;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(value: 0.35, strokeWidth: 2),
            )
          else
            Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
        ],
      ),
    );
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: '移动到底部',
        onPressed: onPressed,
        icon: const Icon(Icons.keyboard_double_arrow_down),
      ),
    );
  }
}

GoalRecord? _currentThreadGoal(CodexSyncSnapshot state, String? threadId) {
  final normalizedThreadId = threadId?.trim();
  if (normalizedThreadId == null || normalizedThreadId.isEmpty) {
    return null;
  }

  for (final goal in state.goals) {
    if (_goalMatchesThread(goal, normalizedThreadId)) {
      return goal;
    }
  }

  final primary = state.goal;
  if (primary != null && _goalMatchesThread(primary, normalizedThreadId)) {
    return primary;
  }

  return null;
}

bool _goalMatchesThread(GoalRecord goal, String threadId) {
  final goalThreadId = goal.threadId?.trim();
  if (goalThreadId != null && goalThreadId == threadId) {
    return true;
  }
  return goal.id == 'windows_goal_$threadId' || goal.id.endsWith(threadId);
}

CodexTaskRecord? _currentRunningTask(
  CodexSyncSnapshot state, {
  String? threadId,
  String? conversationId,
}) {
  final candidates = state.tasks.where((task) {
    if (!_taskIsActive(task)) {
      return false;
    }
    if (conversationId != null &&
        conversationId.isNotEmpty &&
        task.conversationId == conversationId) {
      return true;
    }
    return task.conversationId == null || task.conversationId!.trim().isEmpty;
  }).toList();

  candidates.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  return candidates.isEmpty ? null : candidates.first;
}

bool _taskIsActive(CodexTaskRecord task) {
  return task.status == CodexTaskStatus.running ||
      task.status == CodexTaskStatus.pending;
}

class _ResolvedConversationFile {
  const _ResolvedConversationFile({
    required this.projectId,
    required this.path,
    required this.isDirectory,
    required this.isBinaryPreview,
  });

  final String projectId;
  final String path;
  final bool isDirectory;
  final bool isBinaryPreview;
}

class ConversationProjectMatch {
  const ConversationProjectMatch(this.project, this.basePath);

  final ProjectSummary project;
  final String basePath;
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _CodexThreadErrorBanner extends StatelessWidget {
  const _CodexThreadErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sync_problem_outlined,
            size: 20,
            color: Color(0xFF92400E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Codex 线程读取失败，已切换到 Bridge 暂存消息：$error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationErrorView extends StatelessWidget {
  const _ConversationErrorView({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '读取 Bridge 会话失败：$error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
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
