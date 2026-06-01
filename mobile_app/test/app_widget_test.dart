import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/src/api/codex_mobile_api.dart';
import 'package:mobile_app/src/models/approval.dart';
import 'package:mobile_app/src/models/bridge_network.dart';
import 'package:mobile_app/src/models/codex_file.dart';
import 'package:mobile_app/src/models/codex_thread.dart';
import 'package:mobile_app/src/models/conversation.dart';
import 'package:mobile_app/src/models/project.dart';
import 'package:mobile_app/src/models/sync_state.dart';
import 'package:mobile_app/src/screens/file_preview_screen.dart';

void main() {
  testWidgets('top menu button opens labeled drawer navigation', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('打开菜单'), findsOneWidget);
    expect(find.byTooltip('打开侧边栏'), findsNothing);
    expect(find.text('概览'), findsNothing);
    expect(find.text('项目'), findsNothing);

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    expect(find.text('配对'), findsWidgets);
    expect(find.text('概览'), findsWidgets);
    expect(find.text('项目'), findsWidgets);
    expect(find.text('文件'), findsWidgets);
    expect(find.text('对话'), findsWidgets);
    expect(find.text('审批'), findsWidgets);
    expect(find.text('目标'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('pairing uses a real bridge URL typed by the user', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(CodexMobileApp(api: api));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('bridge-url-field')),
      'http://192.168.31.25:5010',
    );
    await tester.tap(find.text('开始配对'));
    await tester.pumpAndSettle();

    expect(api.bridgeUrl, 'http://192.168.31.25:5010');
    expect(find.textContaining('配对码 123456'), findsOneWidget);
  });

  testWidgets('QR payload fallback auto-fills and completes pairing', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(CodexMobileApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('扫描 Bridge QR'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('bridge-qr-payload-field')),
      '{"type":"codex-mobile-bridge","version":"1","bridgeUrl":"http://192.168.31.25:5010","pairingCode":"654321","expiresAt":"2026-06-01T12:00:00Z"}',
    );
    await tester.tap(find.text('使用 QR 内容'));
    await tester.pumpAndSettle();

    expect(find.text('已配对 test device'), findsOneWidget);
    expect(find.text('http://192.168.31.25:5010'), findsOneWidget);
    expect(find.text('654321'), findsOneWidget);
    expect(api.bridgeUrl, 'http://192.168.31.25:5010');
    expect(api.completedBridgeUrl, 'http://192.168.31.25:5010');
    expect(api.completedPairingCode, '654321');
  });

  testWidgets('navigation exposes all MVP surfaces', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    expect(find.text('配对'), findsWidgets);
    expect(find.text('概览'), findsWidgets);
    expect(find.text('项目'), findsWidgets);
    expect(find.text('文件'), findsWidgets);
    expect(find.text('对话'), findsWidgets);
    expect(find.text('审批'), findsWidgets);
    expect(find.text('目标'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('project and file lists render bridge data', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('项目').last);
    await tester.pumpAndSettle();
    expect(find.text('codex_mobile_app'), findsOneWidget);
    expect(find.text(r'C:\work\codex_mobile_app'), findsOneWidget);

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('文件').last);
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

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('审批').last);
    await tester.pumpAndSettle();

    expect(find.text('Run Flutter tests'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '批准'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '拒绝'), findsOneWidget);
  });

  testWidgets('conversations screen renders real Codex thread history by project', (
    tester,
  ) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('对话').last);
    await tester.pumpAndSettle();

    expect(find.text('调研Java_Harness'), findsOneWidget);
    expect(find.text('实现手机小说 Agent'), findsOneWidget);
    expect(find.text('整理 Java Harness 文档'), findsOneWidget);
    expect(find.text('codex_mobile_app'), findsOneWidget);
    expect(find.text('实现调研目标并测试'), findsOneWidget);

    await tester.tap(find.text('实现调研目标并测试'));
    await tester.pumpAndSettle();

    expect(find.text('手机端和 Windows 端同步'), findsOneWidget);
    expect(find.text('已读取真实 Codex 线程'), findsOneWidget);
  });

  testWidgets('thread detail can send a mobile prompt to Windows Codex', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(CodexMobileApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('对话').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('实现调研目标并测试'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('codex-turn-prompt-field')),
      '从手机继续执行目标并汇报进度',
    );
    await tester.tap(find.byTooltip('发送到 Windows Codex'));
    await tester.pumpAndSettle();

    expect(api.lastTurnThreadId, 'thread-3');
    expect(api.lastTurnPrompt, '从手机继续执行目标并汇报进度');
    expect(find.text('已发送到 Windows Codex'), findsOneWidget);
  });

  testWidgets('conversations stay usable with many threads on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('对话').last);
    await tester.pumpAndSettle();

    expect(find.text('实现手机小说 Agent'), findsOneWidget);
    expect(find.text('整理 Java Harness 文档'), findsOneWidget);
    expect(find.text('排查超长路径和多线程同步问题'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings includes release bridge safety text', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        '发布版应使用 HTTPS 或可信的本地 Bridge 配对',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('不要把 Windows Bridge 暴露到不可信网络'),
      findsOneWidget,
    );
    expect(find.text('http://192.168.31.25:5010'), findsOneWidget);
    expect(find.textContaining('需要配对令牌'), findsWidgets);
    expect(find.textContaining('Skipped public host 8.8.8.8'), findsOneWidget);
  });

  testWidgets('goals screen renders goal and task progress', (tester) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('目标').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('/goal 目标'), findsOneWidget);
    expect(find.text('实现手机端查看 Codex 任务进度和完成情况'), findsOneWidget);
    expect(find.text('Bridge sync'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.textContaining('Live sync connected'), findsOneWidget);
  });

  testWidgets('markdown preview renders as mobile reading content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FilePreviewScreen(
          preview: FilePreview(
            path: '00-总目录.md',
            content: '# AgentScope Java Harness\n\n- 快速开始\n正文段落',
            language: 'markdown',
          ),
        ),
      ),
    );

    expect(find.text('AgentScope Java Harness'), findsOneWidget);
    expect(find.text('快速开始'), findsOneWidget);
    expect(find.text('正文段落'), findsOneWidget);
  });
}

class _FakeApi implements CodexMobileApi {
  String bridgeUrl = '';
  String? completedBridgeUrl;
  String? completedPairingCode;
  String? lastTurnThreadId;
  String? lastTurnPrompt;

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
  }) async {
    completedBridgeUrl = bridgeUrl;
    completedPairingCode = pairingCode;
    setBridgeUrl(bridgeUrl);
    return const PairingResult(token: 'token', pairedDeviceName: 'test device');
  }

  @override
  Future<List<ProjectSummary>> listProjects() async => const [
    ProjectSummary(
      id: 'proj-1',
      name: 'codex_mobile_app',
      rootPath: r'C:\work\codex_mobile_app',
      trusted: true,
    ),
    ProjectSummary(
      id: 'knowledge-1',
      name: 'AgentScope Java Harness 知识库',
      rootPath:
          r'C:\Users\doob\Desktop\个人资料\项目收集和调研\调研Java_Harness\AgentScope-Java-Harness-知识库',
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
    CodexFile(
      name: '00-总目录.md',
      path: '00-总目录.md',
      kind: CodexFileKind.file,
      sizeBytes: 256,
      preview: '# AgentScope Java Harness',
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
  Future<List<CodexThreadGroup>> listCodexThreadGroups() async => [
    CodexThreadGroup(
      projectName: '调研Java_Harness',
      projectPath:
          r'C:\Users\doob\Desktop\个人资料\项目收集和调研\调研Java_Harness',
      threads: [
        CodexThreadSummary(
          id: 'thread-1',
          title: '实现手机小说 Agent',
          preview: '移动端小说 Agent 功能继续实现',
          projectName: '调研Java_Harness',
          projectPath:
              r'C:\Users\doob\Desktop\个人资料\项目收集和调研\调研Java_Harness',
          status: 'running',
          updatedAt: DateTime.utc(2026, 5, 31, 10),
        ),
        CodexThreadSummary(
          id: 'thread-2',
          title: '整理 Java Harness 文档',
          preview: '离线讲义和知识库整理',
          projectName: '调研Java_Harness',
          projectPath:
              r'C:\Users\doob\Desktop\个人资料\项目收集和调研\调研Java_Harness',
          status: 'completed',
          updatedAt: DateTime.utc(2026, 5, 30, 12),
        ),
        CodexThreadSummary(
          id: 'thread-4',
          title: '排查超长路径和多线程同步问题',
          preview: '窄屏也要能快速区分多个会话',
          projectName: '调研Java_Harness',
          projectPath:
              r'C:\Users\doob\Desktop\个人资料\项目收集和调研\调研Java_Harness',
          status: 'idle',
          updatedAt: DateTime.utc(2026, 5, 30, 9),
        ),
      ],
    ),
    CodexThreadGroup(
      projectName: 'codex_mobile_app',
      projectPath: r'C:\Users\doob\Desktop\code\dev\codex_mobile_app',
      threads: [
        CodexThreadSummary(
          id: 'thread-3',
          title: '实现调研目标并测试',
          preview: '手机端和 Windows Bridge 同步开发',
          projectName: 'codex_mobile_app',
          projectPath: r'C:\Users\doob\Desktop\code\dev\codex_mobile_app',
          status: 'running',
          updatedAt: DateTime.utc(2026, 5, 31, 11),
        ),
      ],
    ),
  ];

  @override
  Future<CodexThreadDetail> readCodexThread({required String threadId}) async =>
      CodexThreadDetail(
        thread: CodexThreadSummary(
          id: threadId,
          title: '实现调研目标并测试',
          preview: '手机端和 Windows Bridge 同步开发',
          projectName: 'codex_mobile_app',
          projectPath: r'C:\Users\doob\Desktop\code\dev\codex_mobile_app',
          status: 'idle',
          updatedAt: DateTime.utc(2026, 5, 31, 11),
        ),
        messages: const [
          CodexThreadMessage(role: 'user', text: '手机端和 Windows 端同步'),
          CodexThreadMessage(role: 'assistant', text: '已读取真实 Codex 线程'),
        ],
      );

  @override
  Future<void> startCodexTurn({
    required String threadId,
    required String prompt,
  }) async {
    lastTurnThreadId = threadId;
    lastTurnPrompt = prompt;
  }

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
  void setBridgeUrl(String bridgeUrl) {
    this.bridgeUrl = bridgeUrl;
  }

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
