import 'dart:convert';
import 'dart:io';

import '../models/approval.dart';
import '../models/bridge_network.dart';
import '../models/codex_backend.dart';
import '../models/codex_file.dart';
import '../models/codex_thread.dart';
import '../models/conversation.dart';
import '../models/project.dart';
import '../models/sync_state.dart';
import 'bridge_endpoint.dart';

abstract interface class CodexMobileApi {
  Future<BridgeStatus> getStatus();

  Future<CodexBackendStatus> getCodexStatus();

  void setBridgeUrl(String bridgeUrl);

  void setAccessToken(String? token);

  Future<PairingChallenge> startPairing();

  Future<PairingResult> completePairing({
    required String bridgeUrl,
    required String pairingCode,
    String? challengeId,
  });

  Future<List<ProjectSummary>> listProjects();

  Future<List<CodexFile>> listFiles({
    required String projectId,
    String path = '',
  });

  Future<FilePreview> readFile({
    required String projectId,
    required String path,
  });

  Future<DownloadedFile> downloadFile({
    required String projectId,
    required String path,
  });

  Future<List<ConversationSummary>> listConversations();

  Future<ConversationDetail> readConversation({required String conversationId});

  Future<ConversationDetail> sendConversationMessage({
    required String conversationId,
    required String content,
  });

  Future<List<CodexThreadGroup>> listCodexThreadGroups();

  Future<CodexThreadDetail> readCodexThread({required String threadId});

  Future<CodexThreadDetail> startCodexTurn({
    required String threadId,
    required String prompt,
  });

  Future<List<ApprovalRequest>> listApprovals();

  Future<BridgeSecurityStatus> getSecurityStatus();

  Future<List<PairingTokenStatus>> listPairingTokens();

  Future<void> revokePairingToken({required String fingerprint});

  Future<BridgeNetworkSummary> getNetworkSummary();

  Future<CodexSyncSnapshot> getSyncState();

  Stream<CodexSyncSnapshot> watchSyncState();

  Future<GoalRecord> updateGoal({required String objective});

  Future<CodexTaskRecord> createTask({
    required String title,
    required String detail,
  });

  Future<void> resolveApproval({
    required String approvalId,
    required ApprovalAction action,
  });
}

class BridgeStatus {
  const BridgeStatus({
    required this.connected,
    required this.bridgeVersion,
    required this.protocolVersion,
  });

  final bool connected;
  final String bridgeVersion;
  final String protocolVersion;

  factory BridgeStatus.fromJson(Map<String, Object?> json) {
    return BridgeStatus(
      connected:
          json['connected'] as bool? ?? json['status'] == 'ok' || json.isEmpty,
      bridgeVersion: json['bridgeVersion'] as String? ?? 'unknown',
      protocolVersion: json['protocolVersion'] as String? ?? 'unknown',
    );
  }
}

class PairingResult {
  const PairingResult({required this.token, required this.pairedDeviceName});

  final String token;
  final String pairedDeviceName;

  factory PairingResult.fromJson(Map<String, Object?> json) {
    return PairingResult(
      token: json['token'] as String? ?? json['accessToken'] as String? ?? '',
      pairedDeviceName: json['pairedDeviceName'] as String? ?? 'Mobile device',
    );
  }
}

class PairingChallenge {
  const PairingChallenge({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  final String id;
  final String code;
  final DateTime expiresAt;

  factory PairingChallenge.fromJson(Map<String, Object?> json) {
    return PairingChallenge(
      id: json['challengeId'] as String? ?? json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class HttpCodexMobileApi implements CodexMobileApi {
  HttpCodexMobileApi(String bridgeUrl, {HttpClient? client})
    : _endpoint = _createEndpoint(bridgeUrl),
      _client = client ?? HttpClient();

  static const int _turnReplyPollAttempts = 90;
  static const Duration _turnReplyPollDelay = Duration(seconds: 2);

  BridgeEndpoint? _endpoint;
  final HttpClient _client;
  String? _accessToken;
  List<ConversationSummary>? _conversationCache;
  final Map<String, ConversationDetail> _conversationDetailCache = {};
  List<CodexThreadGroup>? _threadGroupCache;
  final Map<String, CodexThreadDetail> _threadDetailCache = {};
  CodexBackendStatus? _codexStatusCache;
  CodexSyncSnapshot? _syncStateCache;

  @override
  void setBridgeUrl(String bridgeUrl) {
    _endpoint = _createEndpoint(bridgeUrl);
    _conversationCache = null;
    _conversationDetailCache.clear();
    _threadGroupCache = null;
    _threadDetailCache.clear();
    _codexStatusCache = null;
    _syncStateCache = null;
  }

  @override
  void setAccessToken(String? token) {
    _accessToken = token?.trim().isEmpty == true ? null : token?.trim();
  }

  @override
  Future<BridgeStatus> getStatus() async {
    final json = await _getObject('/health');
    return BridgeStatus.fromJson(json);
  }

  @override
  Future<CodexBackendStatus> getCodexStatus() async {
    try {
      final json = await _getObject('/codex/status');
      final status = CodexBackendStatus.fromJson(json);
      _codexStatusCache = status;
      return status;
    } catch (_) {
      final cached = _codexStatusCache;
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<PairingChallenge> startPairing() async {
    final json = await _postObject('/pairing/start', const {});
    return PairingChallenge.fromJson(json);
  }

  @override
  Future<PairingResult> completePairing({
    required String bridgeUrl,
    required String pairingCode,
    String? challengeId,
  }) async {
    setBridgeUrl(bridgeUrl);
    final json = await _postObject('/pairing/complete', {
      'code': pairingCode,
      if (challengeId != null) 'challengeId': challengeId,
    });
    final result = PairingResult.fromJson(json);
    setAccessToken(result.token);
    return result;
  }

  @override
  Future<List<ProjectSummary>> listProjects() async {
    final json = await _getJson('/projects');
    return _readList(json, 'projects').map(ProjectSummary.fromJson).toList();
  }

  @override
  Future<List<CodexFile>> listFiles({
    required String projectId,
    String path = '',
  }) async {
    final json = await _getJson('/files/list', {
      'projectId': projectId,
      'path': path,
    });
    return _readList(json, 'files').map(CodexFile.fromJson).toList();
  }

  @override
  Future<FilePreview> readFile({
    required String projectId,
    required String path,
  }) async {
    final json = await _getObject('/files/read', {
      'projectId': projectId,
      'path': path,
    });
    return FilePreview.fromJson(json);
  }

  @override
  Future<DownloadedFile> downloadFile({
    required String projectId,
    required String path,
  }) async {
    final json = await _getObject('/files/download', {
      'projectId': projectId,
      'path': path,
    });
    return DownloadedFile.fromJson(json);
  }

  @override
  Future<List<ConversationSummary>> listConversations() async {
    try {
      final json = await _getJson('/conversations');
      final conversations = _readList(
        json,
        'conversations',
      ).map(ConversationSummary.fromJson).toList();
      _conversationCache = conversations;
      return conversations;
    } catch (_) {
      final cached = _conversationCache;
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<ConversationDetail> readConversation({
    required String conversationId,
  }) async {
    try {
      final json = await _getObject('/conversations/$conversationId');
      final detail = ConversationDetail.fromJson(json);
      _conversationDetailCache[conversationId] = detail;
      return detail;
    } catch (_) {
      final cached = _conversationDetailCache[conversationId];
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<ConversationDetail> sendConversationMessage({
    required String conversationId,
    required String content,
  }) async {
    final json = await _postObject('/conversations/$conversationId/messages', {
      'role': 'user',
      'content': content,
    });
    _throwIfBridgeFailure(json);
    final detail = json['detail'];
    ConversationDetail current;
    if (detail is Map<String, Object?>) {
      current = ConversationDetail.fromJson(detail);
    } else {
      current = ConversationDetail.fromJson(json);
    }
    if (_hasConversationAssistantReplyAfterPrompt(current.messages, content)) {
      return current;
    }
    return _waitForConversationReply(
      conversationId: conversationId,
      prompt: content,
    );
  }

  @override
  Future<List<CodexThreadGroup>> listCodexThreadGroups() async {
    try {
      final json = await _getJson('/codex/threads');
      final groups = CodexThreadCollection.fromJson(json).groups;
      _threadGroupCache = groups;
      return groups;
    } catch (_) {
      final cached = _threadGroupCache;
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<CodexThreadDetail> readCodexThread({required String threadId}) async {
    try {
      final json = await _getJson('/codex/threads/$threadId');
      final detail = CodexThreadDetail.fromJson(json);
      _threadDetailCache[threadId] = detail;
      return detail;
    } catch (_) {
      final cached = _threadDetailCache[threadId];
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<CodexThreadDetail> startCodexTurn({
    required String threadId,
    required String prompt,
  }) async {
    final result = await _postObject('/codex/turns', {
      'threadId': threadId,
      'prompt': prompt,
    });
    _throwIfBridgeFailure(result);
    return _waitForThreadReply(threadId: threadId, prompt: prompt);
  }

  @override
  Future<List<ApprovalRequest>> listApprovals() async {
    final json = await _getJson('/approvals');
    return _readList(json, 'approvals').map(ApprovalRequest.fromJson).toList();
  }

  @override
  Future<BridgeSecurityStatus> getSecurityStatus() async {
    final json = await _getObject('/security/status');
    return BridgeSecurityStatus.fromJson(json);
  }

  @override
  Future<List<PairingTokenStatus>> listPairingTokens() async {
    final json = await _getJson('/pairing/tokens');
    return _readList(
      json,
      'tokens',
    ).map(PairingTokenStatus.fromJson).toList(growable: false);
  }

  @override
  Future<void> revokePairingToken({required String fingerprint}) async {
    await _postObject('/pairing/tokens/$fingerprint/revoke', const {});
  }

  @override
  Future<BridgeNetworkSummary> getNetworkSummary() async {
    final json = await _getObject('/network/interfaces');
    return BridgeNetworkSummary.fromJson(json);
  }

  @override
  Future<CodexSyncSnapshot> getSyncState() async {
    try {
      final json = await _getObject('/sync/state');
      final state = CodexSyncSnapshot.fromJson(json);
      _syncStateCache = state;
      return state;
    } catch (_) {
      final cached = _syncStateCache;
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Stream<CodexSyncSnapshot> watchSyncState() async* {
    try {
      final request = await _client.getUrl(
        _requireEndpoint().uri('/sync/stream'),
      );
      _applyCommonHeaders(request);
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decoder.bind(response).join();
        throw HttpException('Bridge returned ${response.statusCode}: $body');
      }

      var dataBuffer = StringBuffer();
      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data:')) {
          dataBuffer.write(line.substring(5).trimLeft());
          continue;
        }

        if (line.isEmpty && dataBuffer.isNotEmpty) {
          final decoded = jsonDecode(dataBuffer.toString());
          dataBuffer = StringBuffer();
          if (decoded is Map<String, Object?>) {
            final state = CodexSyncSnapshot.fromJson(decoded);
            _syncStateCache = state;
            yield state;
          }
        }
      }
    } catch (_) {
      final cached = _syncStateCache;
      if (cached != null) {
        yield cached;
        return;
      }
      rethrow;
    }
  }

  @override
  Future<GoalRecord> updateGoal({required String objective}) async {
    final json = await _postObject('/goal', {
      'objective': objective,
      'status': 'active',
      'source': 'mobile',
    });
    return GoalRecord.fromJson(json);
  }

  @override
  Future<CodexTaskRecord> createTask({
    required String title,
    required String detail,
  }) async {
    final json = await _postObject('/tasks', {
      'title': title,
      'detail': detail,
    });
    return CodexTaskRecord.fromJson(json);
  }

  @override
  Future<void> resolveApproval({
    required String approvalId,
    required ApprovalAction action,
  }) async {
    await _postObject('/approvals/$approvalId/resolve', {
      'decision': switch (action) {
        ApprovalAction.approve => 'approved',
        ApprovalAction.reject => 'rejected',
      },
    });
  }

  Future<Map<String, Object?>> _getObject(
    String path, [
    Map<String, String?> query = const {},
  ]) async {
    final decoded = await _getJson(path, query);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    throw const FormatException('Bridge response must be a JSON object');
  }

  Future<Object?> _getJson(
    String path, [
    Map<String, String?> query = const {},
  ]) async {
    final request = await _client.getUrl(_requireEndpoint().uri(path, query));
    _applyCommonHeaders(request);
    return _sendJsonRequest(request);
  }

  Future<Map<String, Object?>> _postObject(
    String path,
    Map<String, Object?> body,
  ) async {
    final request = await _client.postUrl(_requireEndpoint().uri(path));
    _applyCommonHeaders(request);
    request.headers.contentType = ContentType.json;
    final encoded = utf8.encode(jsonEncode(body));
    request.contentLength = encoded.length;
    request.add(encoded);
    final decoded = await _sendJsonRequest(request);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    throw const FormatException('Bridge response must be a JSON object');
  }

  Future<Object?> _sendJsonRequest(HttpClientRequest request) async {
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Bridge returned ${response.statusCode}: $body');
    }
    return jsonDecode(body);
  }

  Future<CodexThreadDetail> _waitForThreadReply({
    required String threadId,
    required String prompt,
  }) async {
    CodexThreadDetail? latest;
    for (var attempt = 0; attempt < _turnReplyPollAttempts; attempt += 1) {
      latest = await readCodexThread(threadId: threadId);
      if (_hasAssistantReplyAfterPrompt(latest.messages, prompt)) {
        return latest;
      }
      await Future<void>.delayed(_turnReplyPollDelay);
    }

    throw StateError('Windows Codex 已接收请求，但手机端没有读到新的 ASSISTANT 回复。');
  }

  bool _hasAssistantReplyAfterPrompt(
    List<CodexThreadMessage> messages,
    String prompt,
  ) {
    var sawPrompt = false;
    for (final message in messages) {
      final role = message.role.toLowerCase();
      if (role == 'user' && _matchesPrompt(message.text, prompt)) {
        sawPrompt = true;
        continue;
      }
      if (sawPrompt && role == 'assistant' && message.text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<ConversationDetail> _waitForConversationReply({
    required String conversationId,
    required String prompt,
  }) async {
    ConversationDetail? latest;
    for (var attempt = 0; attempt < _turnReplyPollAttempts; attempt += 1) {
      latest = await readConversation(conversationId: conversationId);
      if (_hasConversationAssistantReplyAfterPrompt(latest.messages, prompt)) {
        return latest;
      }
      await Future<void>.delayed(_turnReplyPollDelay);
    }

    throw StateError('Windows Codex 已接收请求，但手机端没有读到新的 ASSISTANT 回复。');
  }

  bool _hasConversationAssistantReplyAfterPrompt(
    List<ConversationMessage> messages,
    String prompt,
  ) {
    var sawPrompt = false;
    for (final message in messages) {
      final role = message.role.toLowerCase();
      if (role == 'user' && _matchesPrompt(message.content, prompt)) {
        sawPrompt = true;
        continue;
      }
      if (sawPrompt && role == 'assistant' && message.content.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _matchesPrompt(String messageText, String prompt) {
    final message = messageText.trim();
    final value = prompt.trim();
    return message == value || message.contains(value) || value.contains(message);
  }

  void _throwIfBridgeFailure(Map<String, Object?> json) {
    final ok = json['ok'] ?? json['Ok'];
    final sent = json['sent'] ?? json['Sent'];
    if (ok == false || sent == false) {
      final error = json['error'] ?? json['Error'] ?? 'Windows Codex 没有接受这次发送。';
      throw StateError(error.toString());
    }
  }

  void _applyCommonHeaders(HttpClientRequest request) {
    if (_accessToken case final token?) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
  }

  static BridgeEndpoint? _createEndpoint(String bridgeUrl) {
    final value = bridgeUrl.trim();
    if (value.isEmpty) {
      return null;
    }
    return BridgeEndpoint(value);
  }

  BridgeEndpoint _requireEndpoint() {
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw StateError('请输入 Bridge 地址后再连接。');
    }
    return endpoint;
  }

  List<Map<String, Object?>> _readList(Object? json, String field) {
    if (json is List<Object?>) {
      return json.whereType<Map<String, Object?>>().toList(growable: false);
    }
    if (json is! Map<String, Object?>) {
      return const [];
    }
    final raw = json[field];
    if (raw is! List<Object?>) {
      return const [];
    }
    return raw.whereType<Map<String, Object?>>().toList(growable: false);
  }
}
