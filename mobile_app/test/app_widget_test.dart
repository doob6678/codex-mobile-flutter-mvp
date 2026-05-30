import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/src/api/codex_mobile_api.dart';
import 'package:mobile_app/src/models/approval.dart';
import 'package:mobile_app/src/models/codex_file.dart';
import 'package:mobile_app/src/models/conversation.dart';
import 'package:mobile_app/src/models/project.dart';

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
}
