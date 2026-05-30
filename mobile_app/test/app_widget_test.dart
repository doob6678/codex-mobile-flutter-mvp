import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/src/api/codex_mobile_api.dart';
import 'package:mobile_app/src/models/approval.dart';
import 'package:mobile_app/src/models/bridge_network.dart';
import 'package:mobile_app/src/models/codex_file.dart';
import 'package:mobile_app/src/models/conversation.dart';
import 'package:mobile_app/src/models/project.dart';
import 'package:mobile_app/src/models/sync_state.dart';

void main() {
  testWidgets('navigation exposes all MVP surfaces', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    expect(find.text('Pairing'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Files'), findsWidgets);
    expect(find.text('Conversations'), findsWidgets);
    expect(find.text('Approvals'), findsWidgets);
    expect(find.text('Goals'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('project and file lists render bridge data', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects').last);
    await tester.pumpAndSettle();
    expect(find.text('codex_mobile_app'), findsOneWidget);
    expect(find.text(r'C:\work\codex_mobile_app'), findsOneWidget);

    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);

    await tester.tap(find.text('main.dart'));
    await tester.pumpAndSettle();
    expect(find.text('void main() {}'), findsOneWidget);
  });

  testWidgets('approval actions render as explicit buttons', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approvals').last);
    await tester.pumpAndSettle();

    expect(find.text('Run Flutter tests'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
  });

  testWidgets('settings includes release bridge safety text', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Release builds require HTTPS or trusted local bridge pairing',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('never expose the Windows Bridge'),
      findsOneWidget,
    );
    expect(find.text('http://192.168.31.25:5010'), findsOneWidget);
    expect(find.textContaining('pairing token required'), findsWidgets);
    expect(find.textContaining('Skipped public host 8.8.8.8'), findsOneWidget);
  });

  testWidgets('goals screen renders goal and task progress', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Goals').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('/goal objective'), findsOneWidget);
    expect(find.text('实现手机端查看 Codex 任务进度和完成情况'), findsOneWidget);
    expect(find.text('Bridge sync'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.textContaining('Live sync connected'), findsOneWidget);
  });
}

class _FakeApi implements CodexMobileApi {
  @override
  Future<BridgeStatus> getStatus() async => const BridgeStatus(
    connected: true,
    bridgeVersion: '0.1.0',
    protocolVersion: 'v2',
  );

  @override
  Future<PairingResult> completePairing({
    required String bridgeUrl,
    required String pairingCode,
  }) async =>
      const PairingResult(token: 'token', pairedDeviceName: 'test device');

  @override
  Future<List<ProjectSummary>> listProjects() async => const [
    ProjectSummary(
      id: 'proj-1',
      name: 'codex_mobile_app',
      rootPath: r'C:\work\codex_mobile_app',
      trusted: true,
    ),
  ];

  @override
  Future<List<CodexFile>> listFiles({
    required String projectId,
    String path = '',
  }) async => const [
    CodexFile(name: 'lib', path: 'lib', kind: CodexFileKind.directory),
    CodexFile(
      name: 'main.dart',
      path: 'lib/main.dart',
      kind: CodexFileKind.file,
      sizeBytes: 32,
      preview: 'void main() {}',
    ),
  ];

  @override
  Future<FilePreview> readFile({
    required String projectId,
    required String path,
  }) async => const FilePreview(
    path: 'lib/main.dart',
    content: 'void main() {}',
    language: 'dart',
  );

  @override
  Future<List<ConversationSummary>> listConversations() async => [
    ConversationSummary(
      id: 'thread-1',
      title: 'Bridge setup',
      updatedAt: DateTime.utc(2026, 5, 30, 8, 45),
      latestMessage: 'Pairing completed',
      unreadCount: 1,
    ),
  ];

  @override
  Future<List<ApprovalRequest>> listApprovals() async => const [
    ApprovalRequest(
      id: 'approval-1',
      projectId: 'proj-1',
      title: 'Run Flutter tests',
      command: 'flutter test',
      risk: ApprovalRisk.medium,
      actions: [ApprovalAction.approve, ApprovalAction.reject],
    ),
  ];

  @override
  Future<void> resolveApproval({
    required String approvalId,
    required ApprovalAction action,
  }) async {}

  @override
  void setAccessToken(String? token) {}

  @override
  Future<PairingChallenge> startPairing() async => PairingChallenge(
    code: '123456',
    expiresAt: DateTime.utc(2026),
  );

  @override
  Future<BridgeNetworkSummary> getNetworkSummary() async =>
      const BridgeNetworkSummary(
        scheme: 'http',
        port: 5010,
        publicExposureAllowed: false,
        endpoints: [
          BridgeNetworkEndpoint(
            host: '127.0.0.1',
            url: 'http://127.0.0.1:5010',
            scope: 'loopback',
            requiresPairing: true,
            isRecommendedForMobile: false,
          ),
          BridgeNetworkEndpoint(
            host: '192.168.31.25',
            url: 'http://192.168.31.25:5010',
            scope: 'private-lan',
            requiresPairing: true,
            isRecommendedForMobile: true,
          ),
        ],
        warnings: ['Skipped public host 8.8.8.8'],
      );

  @override
  Future<CodexSyncSnapshot> getSyncState() async => CodexSyncSnapshot(
    goal: GoalRecord(
      id: 'goal-1',
      objective: '实现手机端查看 Codex 任务进度和完成情况',
      status: GoalStatus.active,
      source: 'mobile',
      updatedAt: DateTime.utc(2026),
    ),
    tasks: [
      CodexTaskRecord(
        id: 'task-1',
        title: 'Bridge sync',
        detail: 'Wire goal endpoint',
        status: CodexTaskStatus.running,
        progressPercent: 90,
        summary: 'Live sync connected',
        updatedAt: DateTime.utc(2026),
      ),
    ],
    updatedAt: DateTime.utc(2026),
  );

  @override
  Stream<CodexSyncSnapshot> watchSyncState() async* {
    yield await getSyncState();
  }

  @override
  Future<GoalRecord> updateGoal({required String objective}) async =>
      GoalRecord(
        id: 'goal-1',
        objective: objective,
        status: GoalStatus.active,
        source: 'mobile',
        updatedAt: DateTime.utc(2026),
      );

  @override
  Future<CodexTaskRecord> createTask({
    required String title,
    required String detail,
  }) async =>
      CodexTaskRecord(
        id: 'task-2',
        title: title,
        detail: detail,
        status: CodexTaskStatus.pending,
        progressPercent: 0,
        summary: detail,
        updatedAt: DateTime.utc(2026),
      );
}
