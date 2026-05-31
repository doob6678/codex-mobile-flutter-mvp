import 'dart:convert';
import 'dart:io';

import '../models/approval.dart';
import '../models/bridge_network.dart';
import '../models/codex_file.dart';
import '../models/codex_thread.dart';
import '../models/conversation.dart';
import '../models/project.dart';
import '../models/sync_state.dart';
import 'bridge_endpoint.dart';

abstract interface class CodexMobileApi {
  Future<BridgeStatus> getStatus();

  void setAccessToken(String? token);

  Future<PairingChallenge> startPairing();

  Future<PairingResult> completePairing({
    required String bridgeUrl,
    required String pairingCode,
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

  Future<List<ConversationSummary>> listConversations();

  Future<List<CodexThreadGroup>> listCodexThreadGroups();

  Future<CodexThreadDetail> readCodexThread({required String threadId});

  Future<List<ApprovalRequest>> listApprovals();

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
  const PairingChallenge({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  factory PairingChallenge.fromJson(Map<String, Object?> json) {
    return PairingChallenge(
      code: json['code'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class HttpCodexMobileApi implements CodexMobileApi {
  HttpCodexMobileApi(this.endpoint, {HttpClient? client})
    : _client = client ?? HttpClient();

  final BridgeEndpoint endpoint;
  final HttpClient _client;
  String? _accessToken;

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
  Future<PairingChallenge> startPairing() async {
    final json = await _postObject('/pairing/start', const {});
    return PairingChallenge.fromJson(json);
  }

  @override
  Future<PairingResult> completePairing({
    required String bridgeUrl,
    required String pairingCode,
  }) async {
    final json = await _postObject('/pairing/complete', {
      'code': pairingCode,
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
  Future<List<ConversationSummary>> listConversations() async {
    final json = await _getJson('/conversations');
    return _readList(
      json,
      'conversations',
    ).map(ConversationSummary.fromJson).toList();
  }

  @override
  Future<List<CodexThreadGroup>> listCodexThreadGroups() async {
    final json = await _getJson('/codex/threads');
    return CodexThreadCollection.fromJson(json).groups;
  }

  @override
  Future<CodexThreadDetail> readCodexThread({required String threadId}) async {
    final json = await _getJson('/codex/threads/$threadId');
    return CodexThreadDetail.fromJson(json);
  }

  @override
  Future<List<ApprovalRequest>> listApprovals() async {
    final json = await _getJson('/approvals');
    return _readList(json, 'approvals').map(ApprovalRequest.fromJson).toList();
  }

  @override
  Future<BridgeNetworkSummary> getNetworkSummary() async {
    final json = await _getObject('/network/interfaces');
    return BridgeNetworkSummary.fromJson(json);
  }

  @override
  Future<CodexSyncSnapshot> getSyncState() async {
    final json = await _getObject('/sync/state');
    return CodexSyncSnapshot.fromJson(json);
  }

  @override
  Stream<CodexSyncSnapshot> watchSyncState() async* {
    final request = await _client.getUrl(endpoint.uri('/sync/stream'));
    _applyCommonHeaders(request);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decoder.bind(response).join();
      throw HttpException('Bridge returned ${response.statusCode}: $body');
    }

    var dataBuffer = StringBuffer();
    await for (final line in response
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.startsWith('data:')) {
        dataBuffer.write(line.substring(5).trimLeft());
        continue;
      }

      if (line.isEmpty && dataBuffer.isNotEmpty) {
        final decoded = jsonDecode(dataBuffer.toString());
        dataBuffer = StringBuffer();
        if (decoded is Map<String, Object?>) {
          yield CodexSyncSnapshot.fromJson(decoded);
        }
      }
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
    final request = await _client.getUrl(endpoint.uri(path, query));
    _applyCommonHeaders(request);
    return _sendJsonRequest(request);
  }

  Future<Map<String, Object?>> _postObject(
    String path,
    Map<String, Object?> body,
  ) async {
    final request = await _client.postUrl(endpoint.uri(path));
    _applyCommonHeaders(request);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
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

  void _applyCommonHeaders(HttpClientRequest request) {
    if (_accessToken case final token?) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
  }

  List<Map<String, Object?>> _readList(
    Object? json,
    String field,
  ) {
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
