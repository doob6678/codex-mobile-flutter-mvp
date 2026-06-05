import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/src/api/codex_mobile_api.dart';
import 'package:mobile_app/src/models/approval.dart';
import 'package:mobile_app/src/models/bridge_network.dart';
import 'package:mobile_app/src/models/codex_backend.dart';
import 'package:mobile_app/src/models/codex_file.dart';
import 'package:mobile_app/src/models/codex_thread.dart';
import 'package:mobile_app/src/models/conversation.dart';
import 'package:mobile_app/src/models/project.dart';
import 'package:mobile_app/src/models/sync_state.dart';
import 'package:mobile_app/src/screens/file_preview_screen.dart';

void main() {
  testWidgets('top menu button opens labeled drawer navigation', (
    tester,
  ) async {
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

  testWidgets('pairing uses a real bridge URL typed by the user', (
    tester,
  ) async {
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
    expect(find.text('code'), findsOneWidget);
    expect(find.text('123456'), findsWidgets);
    expect(find.textContaining('challenge-start'), findsOneWidget);
    expect(find.textContaining('challengeId'), findsWidgets);
    expect(find.textContaining('挑战秘钥'), findsWidgets);
    expect(find.textContaining('手动配对'), findsWidgets);
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
      '{"type":"codex-mobile-bridge","version":"1","challengeId":"challenge-1","bridgeUrl":"http://192.168.31.25:5010","pairingCode":"654321","expiresAt":"2026-06-01T12:00:00Z"}',
    );
    await tester.tap(find.text('使用 QR 内容'));
    await tester.pumpAndSettle();

    expect(find.text('已配对 test device'), findsOneWidget);
    expect(find.text('http://192.168.31.25:5010'), findsOneWidget);
    expect(find.text('完成配对'), findsNothing);
    expect(find.textContaining('challenge-1'), findsNothing);
    expect(find.text('654321'), findsNothing);
    expect(api.bridgeUrl, 'http://192.168.31.25:5010');
    expect(api.completedBridgeUrl, 'http://192.168.31.25:5010');
    expect(api.completedPairingCode, '654321');
    expect(api.completedChallengeId, 'challenge-1');
  });

  testWidgets(
    'QR auto-pairing does not leave a one-time challenge to submit again',
    (tester) async {
      final api = _FakeApi(
        projectRoot: r'C:\Users\TestUser\Desktop\code\dev\codex_mobile_app',
      );
      await tester.pumpWidget(CodexMobileApp(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('扫描 Bridge QR'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('bridge-qr-payload-field')),
        '{"type":"codex-mobile-bridge","version":"1","challengeId":"challenge-used-once","bridgeUrl":"https://wrist-seriously-occasion-src.trycloudflare.com","pairingCode":"620688","expiresAt":"2026-06-01T12:00:00Z"}',
      );
      await tester.tap(find.text('使用 QR 内容'));
      await tester.pumpAndSettle();

      expect(find.text('已配对 test device'), findsOneWidget);
      expect(find.text('完成配对'), findsNothing);
      expect(
        find.textContaining('Pairing challenge was not found'),
        findsNothing,
      );
      expect(api.attemptedBridgeUrls, [
        'https://wrist-seriously-occasion-src.trycloudflare.com',
      ]);
    },
  );

  testWidgets('QR payload can fall back across bridge URLs on mobile data', (
    tester,
  ) async {
    final api = _FakeApi()
      ..failFirstBridgeUrlOnce('http://10.250.236.241:5010');
    await tester.pumpWidget(CodexMobileApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('扫描 Bridge QR'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('bridge-qr-payload-field')),
      '{"type":"codex-mobile-bridge","version":"1","challengeId":"challenge-2","bridgeUrl":"http://10.250.236.241:5010","bridgeUrls":["http://10.250.236.241:5010","http://192.168.31.25:5010"],"pairingCode":"777888","expiresAt":"2026-06-01T12:00:00Z"}',
    );
    await tester.tap(find.text('使用 QR 内容'));
    await tester.pumpAndSettle();

    expect(api.attemptedBridgeUrls, [
      'http://10.250.236.241:5010',
      'http://192.168.31.25:5010',
    ]);
    expect(api.completedBridgeUrl, 'http://192.168.31.25:5010');
    expect(find.text('已配对 test device'), findsOneWidget);
  });

  testWidgets('pairing explains private IP failures on mobile data', (
    tester,
  ) async {
    final api = _FakeApi()..failBridgeUrlAlways('http://10.250.236.241:5010');
    await tester.pumpWidget(CodexMobileApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('扫描 Bridge QR'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('bridge-qr-payload-field')),
      '{"type":"codex-mobile-bridge","version":"1","challengeId":"challenge-3","bridgeUrl":"http://10.250.236.241:5010","bridgeUrls":["http://10.250.236.241:5010"],"pairingCode":"777888","expiresAt":"2026-06-01T12:00:00Z"}',
    );
    await tester.tap(find.text('使用 QR 内容'));
    await tester.pumpAndSettle();

    expect(find.textContaining('无法路由到 Windows 内网地址'), findsOneWidget);
    expect(
      find.textContaining('CODEX_MOBILE_EXTERNAL_BRIDGE_URLS'),
      findsOneWidget,
    );
  });

  testWidgets('desktop shell keeps the sidebar collapsed until opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    expect(find.text('概览'), findsNothing);
    expect(find.byTooltip('打开菜单'), findsOneWidget);

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();

    expect(find.text('Codex Console'), findsOneWidget);
    expect(find.text('Bridge Monitor'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Goal Monitor'), findsOneWidget);
    expect(find.text('Task Progress'), findsOneWidget);
    expect(find.text('Live sync connected'), findsOneWidget);
    expect(find.textContaining('windows-codex-history'), findsOneWidget);
    expect(find.textContaining('challengeId + 6 位 code'), findsOneWidget);
    expect(find.text('90%'), findsWidgets);
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
    expect(find.text('lib'), findsWidgets);
    await tester.tap(find.text('lib').first);
    await tester.pumpAndSettle();
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

  testWidgets(
    'conversations screen renders Windows history and Bridge conversations together',
    (tester) async {
      await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开菜单'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('对话').last);
      await tester.pumpAndSettle();

      expect(find.text('Windows Codex 历史'), findsOneWidget);
      expect(find.text('Codex 后端：Bridge 实时'), findsOneWidget);
      expect(find.textContaining('codex app-server reachable'), findsOneWidget);
      expect(find.text('手机发起的 Windows 会话'), findsOneWidget);
      expect(find.text('调研Java_Harness'), findsOneWidget);
      expect(find.text('codex_mobile_app'), findsOneWidget);
      expect(find.text('实现手机小说 Agent'), findsNothing);
      expect(find.text('整理 Java Harness 文档'), findsNothing);
      expect(find.text('子 agent 分析线程'), findsNothing);
      expect(find.text('Bridge setup'), findsOneWidget);

      await tester.tap(find.text('codex_mobile_app'));
      await tester.pumpAndSettle();
      expect(find.text('实现调研目标并测试'), findsOneWidget);

      await tester.tap(find.text('实现调研目标并测试'));
      await tester.pumpAndSettle();

      expect(find.text('手机端和 Windows 端同步'), findsOneWidget);
      expect(find.text('已读取真实 Codex 线程'), findsOneWidget);
      expect(find.text('/goal'), findsOneWidget);
      expect(find.text('实现手机端查看 Codex 任务进度和完成情况'), findsOneWidget);
      expect(find.text('任务'), findsOneWidget);
    },
  );

  testWidgets('thread detail does not show unrelated global goal', (
    tester,
  ) async {
    await tester.pumpWidget(CodexMobileApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('对话').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('调研Java_Harness'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('整理 Java Harness 文档'));
    await tester.pumpAndSettle();

    expect(find.text('/goal'), findsNothing);
    expect(find.text('实现手机端查看 Codex 任务进度和完成情况'), findsNothing);
  });

  testWidgets('thread detail labels paused goal without raw enum text', (
    tester,
  ) async {
    final api = _FakeApi(threadGoalStatus: GoalStatus.paused);
    await tester.pumpWidget(CodexMobileApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('对话').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('codex_mobile_app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('实现调研目标并测试'));
    await tester.pumpAndSettle();

    expect(find.text('/goal'), findsOneWidget);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('paused'), findsNothing);
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

    await tester.tap(find.text('codex_mobile_app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('实现调研目标并测试'));
    await tester.pumpAndSettle();

    expect(find.text('flutter test\nAll tests passed'), findsNothing);
    expect(find.text('已隐藏 1 条技术消息'), findsOneWidget);

    await tester.tap(find.text('显示技术消息'));
    await tester.pumpAndSettle();

    expect(find.textContaining('flutter test'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('codex-turn-prompt-field')),
      '从手机继续执行目标并汇报进度',
    );
    await tester.tap(find.byTooltip('发送到 Windows Codex'));
    await tester.pumpAndSettle();

    expect(api.lastTurnThreadId, 'thread-3');
    expect(api.lastTurnPrompt, '从手机继续执行目标并汇报进度');
    expect(find.text('已发送到 Windows Codex'), findsOneWidget);
    expect(find.text('Windows Codex 已继续执行手机发送的消息'), findsOneWidget);
  });

  testWidgets(
    'thread detail streams assistant delta without thread id while sending',
    (tester) async {
      final api = _FakeApi();
      api.holdCodexTurn = true;
      api.syncEvents = [
        CodexSyncEvent(
          type: 'codex.appserver.notification',
          entityId: 'item/agentMessage/delta',
          timestamp: DateTime.now().toUtc().add(const Duration(minutes: 1)),
          payload: const {
            'method': 'item/agentMessage/delta',
            'delta': 'Windows 正在流式输出',
            'message': 'Windows Codex 正在生成回复',
          },
        ),
      ];
      await tester.pumpWidget(CodexMobileApp(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开菜单'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('对话').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('codex_mobile_app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('实现调研目标并测试'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('codex-turn-prompt-field')),
        '触发手机端流式显示',
      );
      await tester.tap(find.byTooltip('发送到 Windows Codex'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Windows 正在流式输出'), findsOneWidget);
      expect(find.text('正在等待 Windows Codex 回复...'), findsNothing);

      api.completeHeldCodexTurn();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'thread detail updates pending bubble from sync stream without waiting for polling',
    (tester) async {
      final api = _FakeApi();
      api.holdCodexTurn = true;
      api.enableSyncStream();
      await tester.pumpWidget(CodexMobileApp(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开菜单'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('对话').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('codex_mobile_app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('实现调研目标并测试'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('codex-turn-prompt-field')),
        '触发 sync stream 立即显示',
      );
      await tester.tap(find.byTooltip('发送到 Windows Codex'));
      await tester.pump();

      api.emitSyncEvents([
        CodexSyncEvent(
          type: 'codex.appserver.notification',
          entityId: 'item/agentMessage/delta',
          timestamp: DateTime.now().toUtc().add(const Duration(minutes: 1)),
          payload: const {
            'method': 'item/agentMessage/delta',
            'delta': 'SSE 立即推送的 ASSISTANT 片段',
            'message': 'Windows Codex 正在生成回复',
          },
        ),
      ]);
      await tester.pump();

      expect(find.text('SSE 立即推送的 ASSISTANT 片段'), findsOneWidget);
      expect(find.text('正在等待 Windows Codex 回复...'), findsNothing);

      api.completeHeldCodexTurn();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'thread detail streams assistant text discovered by polling history',
    (tester) async {
      final api = _FakeApi();
      api.holdCodexTurn = true;
      api.assistantDuringHeldTurn = '轮询历史时读到的 ASSISTANT 片段';
      await tester.pumpWidget(CodexMobileApp(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开菜单'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('对话').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('codex_mobile_app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('实现调研目标并测试'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('codex-turn-prompt-field')),
        '触发历史轮询显示',
      );
      await tester.tap(find.byTooltip('发送到 Windows Codex'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('轮询历史时读到的 ASSISTANT 片段'), findsOneWidget);
      expect(find.text('正在等待 Windows Codex 回复...'), findsNothing);

      api.completeHeldCodexTurn();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('thread detail passively refreshes Windows-side messages', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(CodexMobileApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('对话').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('codex_mobile_app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('实现调研目标并测试'));
    await tester.pumpAndSettle();

    expect(find.text('在Windows发送时候手机没有收到'), findsNothing);

    api.externalThreadMessages = const [
      CodexThreadMessage(role: 'user', text: '在Windows发送时候手机没有收到'),
      CodexThreadMessage(role: 'assistant', text: 'Windows 后续写入也会被手机轮询刷新'),
    ];
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('在Windows发送时候手机没有收到'), findsOneWidget);
    expect(find.text('Windows 后续写入也会被手机轮询刷新'), findsOneWidget);
  });

  testWidgets(
    'thread detail renders Bridge mobile-user overlay after refresh',
    (tester) async {
      final api = _FakeApi();
      api.externalThreadMessages = const [
        CodexThreadMessage(role: 'user', text: '手机端 overlay 的 USER 消息'),
      ];
      await tester.pumpWidget(CodexMobileApp(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开菜单'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('对话').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('codex_mobile_app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('实现调研目标并测试'));
      await tester.pumpAndSettle();

      expect(find.text('手机端 overlay 的 USER 消息'), findsOneWidget);
      expect(find.text('已隐藏 1 条技术消息'), findsOneWidget);
    },
  );

  testWidgets('thread detail keeps long titles out of the chat body', (
    tester,
  ) async {
    const longTitle = '实现调研目标并测试，同时保留非常长的 Windows Codex 标题但不能挤占手机对话空间';
    await tester.pumpWidget(
      CodexMobileApp(api: _FakeApi(threadTitle: longTitle)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('对话').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('codex_mobile_app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(longTitle));
    await tester.pumpAndSettle();

    expect(find.text(longTitle), findsOneWidget);
    expect(find.text('USER'), findsOneWidget);
    expect(find.text('ASSISTANT'), findsOneWidget);
    expect(find.text('手机端和 Windows 端同步'), findsOneWidget);
  });

  testWidgets(
    'thread file links open rendered preview and ignore duplicate taps',
    (tester) async {
      final api = _FakeApi(
        projectRoot: r'C:\Users\TestUser\Desktop\code\dev\codex_mobile_app',
      );
      api.externalThreadMessages = const [
        CodexThreadMessage(role: 'assistant', text: '00-总目录.md'),
      ];
      api.holdReadFile('00-总目录.md');

      await tester.pumpWidget(CodexMobileApp(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开菜单'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('对话').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('codex_mobile_app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('实现调研目标并测试'));
      await tester.pumpAndSettle();

      final link = find.byWidgetPredicate(
        (widget) => widget is MarkdownBody && widget.data.contains('00-总目录.md'),
      );
      expect(link, findsWidgets);

      await tester.tap(link.last);
      await tester.pump();
      await tester.tap(link.last);
      await tester.pump();

      expect(api.readFileCallCount, 1);
      expect(find.textContaining('正在打开 00-总目录.md'), findsOneWidget);

      api.completeHeldReadFile();
      await tester.pumpAndSettle();

      expect(find.byType(FilePreviewScreen), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.textContaining('AgentScope Java Harness'), findsOneWidget);
    },
  );

  testWidgets(
    'conversation history keeps cached Windows threads during jitter',
    (tester) async {
      final api = _FakeApi();
      await tester.pumpWidget(CodexMobileApp(api: api));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开菜单'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('对话').last);
      await tester.pumpAndSettle();

      expect(find.text('codex_mobile_app'), findsOneWidget);

      api.failConversationHistory = true;
      await tester.tap(find.byTooltip('刷新对话'));
      await tester.pumpAndSettle();

      expect(find.text('codex_mobile_app'), findsOneWidget);
      expect(find.text('Bridge setup'), findsOneWidget);
      expect(find.textContaining('codex app-server reachable'), findsOneWidget);
    },
  );

  testWidgets('bridge conversation detail can continue a local conversation', (
    tester,
  ) async {
    final api = _FakeApi();
    await tester.pumpWidget(CodexMobileApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('对话').last);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bridge setup').last);
    await tester.pumpAndSettle();

    expect(find.text('Pairing completed'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('bridge-conversation-prompt-field')),
      '继续 Bridge 本地会话',
    );
    await tester.tap(find.byTooltip('发送到 Windows Codex'));
    await tester.pumpAndSettle();

    expect(api.lastBridgeConversationId, 'thread-1');
    expect(api.lastBridgeMessage, '继续 Bridge 本地会话');
    expect(find.text('已发送到 Windows Codex'), findsOneWidget);
    expect(find.textContaining('Codex 线程读取失败，已切换到 Bridge 暂存消息'), findsNothing);
    expect(find.textContaining('手机本地'), findsNothing);
    expect(find.textContaining('Windows Codex'), findsWidgets);
    expect(find.text('Codex 已接收 Bridge 会话并返回真实回复'), findsOneWidget);
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

    expect(find.text('实现手机小说 Agent'), findsNothing);
    await tester.tap(find.text('调研Java_Harness'));
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
      find.textContaining('发布版应使用 HTTPS 或可信的本地 Bridge 配对'),
      findsOneWidget,
    );
    expect(find.textContaining('不要把 Windows Bridge 暴露到不可信网络'), findsOneWidget);
    expect(find.text('http://192.168.31.25:5010'), findsOneWidget);
    expect(find.textContaining('需要配对令牌'), findsWidgets);
    expect(find.textContaining('Skipped public host 8.8.8.8'), findsOneWidget);
    expect(find.text('已配对设备密钥'), findsOneWidget);
    expect(find.textContaining('abc123def456'), findsOneWidget);
    expect(find.textContaining('不会显示原始 token'), findsOneWidget);
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
    expect(find.text('真实同步 Windows Codex 对话发送和回复'), findsOneWidget);
    expect(find.textContaining('Windows goals · 共 2 个'), findsOneWidget);
    expect(find.text('Bridge sync'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.textContaining('Live sync connected'), findsOneWidget);
  });

  testWidgets('markdown preview renders as mobile reading content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FilePreviewScreen(
          preview: FilePreview(
            path: '00-总目录.md',
            content: '# AgentScope Java Harness\n\n- 快速开始\n正文段落',
            language: 'markdown',
            contentType: 'text/markdown; charset=utf-8',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final preview = tester.widget<FilePreviewScreen>(
      find.byType(FilePreviewScreen),
    );
    expect(preview.preview.content, contains('AgentScope Java Harness'));
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets(
    'html preview routes away from markdown and falls back on desktop',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await tester.pumpWidget(
          const MaterialApp(
            home: FilePreviewScreen(
              preview: FilePreview(
                path: 'dist/index.html',
                content:
                    '<!doctype html><html><body><h1>HTML Flow</h1></body></html>',
                language: 'html',
                contentType: 'text/html; charset=utf-8',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MarkdownBody), findsNothing);
        expect(find.textContaining('HTML 预览在当前平台不可用'), findsOneWidget);
        expect(find.textContaining('<!doctype html>'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  test('file preview export writes content to the temp export folder', () async {
    final exportFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}codex-mobile${Platform.pathSeparator}download-test.md',
    );
    if (exportFile.existsSync()) {
      exportFile.deleteSync();
    }

    final path = await persistPreviewExport(
      fileName: 'download-test.md',
      bytes: utf8.encode('# Downloaded\n正文'),
    );

    expect(path, exportFile.path);
    expect(exportFile.existsSync(), isTrue);
    expect(exportFile.readAsStringSync(), contains('Downloaded'));
  });
}

class _FakeApi implements CodexMobileApi {
  _FakeApi({
    this.threadTitle = '实现调研目标并测试',
    this.threadGoalStatus = GoalStatus.active,
    this.projectRoot = r'C:\work\codex_mobile_app',
  });

  final String threadTitle;
  final GoalStatus threadGoalStatus;
  final String projectRoot;
  String bridgeUrl = '';
  String? accessToken;
  String? completedBridgeUrl;
  String? completedPairingCode;
  String? completedChallengeId;
  final List<String> attemptedBridgeUrls = <String>[];
  final Set<String> _failBridgeUrlsOnce = <String>{};
  String? lastTurnThreadId;
  String? lastTurnPrompt;
  String? lastBridgeConversationId;
  String? lastBridgeMessage;
  bool _bridgeConversationSent = false;
  bool _codexTurnSent = false;
  bool failConversationHistory = false;
  bool holdCodexTurn = false;
  Completer<CodexThreadDetail>? _heldCodexTurn;
  String? assistantDuringHeldTurn;
  List<CodexThreadMessage> externalThreadMessages = const [];
  List<CodexSyncEvent> syncEvents = const [];
  StreamController<CodexSyncSnapshot>? _syncStreamController;
  final Set<String> _alwaysFailBridgeUrls = <String>{};
  String? _heldReadFilePath;
  Completer<FilePreview>? _heldReadFile;
  int readFileCallCount = 0;

  @override
  String get configuredBridgeUrl => bridgeUrl;

  @override
  bool get hasAccessToken => accessToken != null;

  void failFirstBridgeUrlOnce(String bridgeUrl) {
    _failBridgeUrlsOnce.add(bridgeUrl);
  }

  void failBridgeUrlAlways(String bridgeUrl) {
    _alwaysFailBridgeUrls.add(bridgeUrl);
  }

  void enableSyncStream() {
    _syncStreamController ??= StreamController<CodexSyncSnapshot>.broadcast();
  }

  void emitSyncEvents(List<CodexSyncEvent> events) {
    syncEvents = events;
    _syncStreamController?.add(_syncSnapshot());
  }

  void holdReadFile(String path) {
    _heldReadFilePath = path;
    _heldReadFile = Completer<FilePreview>();
  }

  void completeHeldReadFile() {
    final path = _heldReadFilePath;
    if (path == null || _heldReadFile == null || _heldReadFile!.isCompleted) {
      return;
    }
    _heldReadFile!.complete(_previewForPath(path));
  }

  @override
  Future<BridgeStatus> getStatus() async => const BridgeStatus(
    connected: true,
    bridgeVersion: '0.1.0',
    protocolVersion: 'v2',
  );

  @override
  Future<CodexBackendStatus> getCodexStatus() async {
    if (failConversationHistory) {
      throw const SocketException('Connection reset by peer');
    }
    return CodexBackendStatus(
      available: true,
      message: 'codex app-server reachable',
      checkedAt: DateTime.utc(2026, 6, 1, 12),
    );
  }

  @override
  Future<PairingResult> completePairing({
    required String bridgeUrl,
    required String pairingCode,
    String? challengeId,
  }) async {
    attemptedBridgeUrls.add(bridgeUrl);
    if (_alwaysFailBridgeUrls.contains(bridgeUrl)) {
      throw const SocketException('No route to host');
    }
    if (_failBridgeUrlsOnce.remove(bridgeUrl)) {
      throw const SocketException('No route to host');
    }
    completedBridgeUrl = bridgeUrl;
    completedPairingCode = pairingCode;
    completedChallengeId = challengeId;
    setBridgeUrl(bridgeUrl);
    return const PairingResult(token: 'token', pairedDeviceName: 'test device');
  }

  @override
  Future<List<ProjectSummary>> listProjects() async => [
    ProjectSummary(
      id: 'proj-1',
      name: 'codex_mobile_app',
      rootPath: projectRoot,
      trusted: true,
    ),
    const ProjectSummary(
      id: 'knowledge-1',
      name: 'AgentScope Java Harness 知识库',
      rootPath:
          r'C:\Users\TestUser\Desktop\个人资料\项目收集和调研\调研Java_Harness\AgentScope-Java-Harness-知识库',
      trusted: true,
    ),
  ];

  @override
  Future<List<CodexFile>> listFiles({
    required String projectId,
    String path = '',
  }) async {
    if (path.isEmpty) {
      return const [
        CodexFile(name: 'lib', path: 'lib', kind: CodexFileKind.directory),
        CodexFile(
          name: '00-总目录.md',
          path: '00-总目录.md',
          kind: CodexFileKind.file,
          sizeBytes: 256,
          preview: '# AgentScope Java Harness',
        ),
      ];
    }
    if (path == 'lib') {
      return const [
        CodexFile(
          name: 'main.dart',
          path: 'lib/main.dart',
          kind: CodexFileKind.file,
          sizeBytes: 32,
          preview: 'void main() {}',
        ),
      ];
    }
    return const [];
  }

  @override
  Future<FilePreview> readFile({
    required String projectId,
    required String path,
  }) async {
    readFileCallCount += 1;
    if (_heldReadFilePath == path && _heldReadFile != null) {
      return _heldReadFile!.future;
    }
    return _previewForPath(path);
  }

  @override
  Future<DownloadedFile> downloadFile({
    required String projectId,
    required String path,
  }) async => const DownloadedFile(
    projectId: 'proj-1',
    path: 'assets/s03_image2.png',
    fileName: 's03_image2.png',
    contentType: 'image/png',
    sizeBytes: 4,
    bytes: [0, 1, 2, 3],
    language: 'text',
  );

  FilePreview _previewForPath(String path) => path == '00-总目录.md'
      ? const FilePreview(
          path: '00-总目录.md',
          content: '# AgentScope Java Harness\n\n- 快速开始\n正文段落',
          language: 'markdown',
          contentType: 'text/markdown; charset=utf-8',
        )
      : const FilePreview(
          path: 'lib/main.dart',
          content: 'void main() {}',
          language: 'dart',
          contentType: 'text/plain; charset=utf-8',
        );

  @override
  Future<List<ConversationSummary>> listConversations() async {
    if (failConversationHistory) {
      throw const SocketException('Connection reset by peer');
    }
    return [
      ConversationSummary(
        id: 'thread-1',
        title: 'Bridge setup',
        updatedAt: DateTime.utc(2026, 5, 30, 8, 45),
        latestMessage: 'Pairing completed',
        unreadCount: 1,
      ),
    ];
  }

  @override
  Future<ConversationDetail> readConversation({
    required String conversationId,
  }) async {
    return ConversationDetail(
      conversation: ConversationRecord(
        id: conversationId,
        title: 'Bridge setup',
        projectId: 'proj-1',
        workingDirectory: r'C:\work\codex_mobile_app',
        createdAt: DateTime.utc(2026, 5, 30, 8, 45),
        updatedAt: DateTime.utc(2026, 5, 30, 8, 50),
        codexThreadId: 'thread-relay-1',
      ),
      messages: [
        ConversationMessage(
          id: 'msg-1',
          conversationId: conversationId,
          role: 'assistant',
          content: 'Pairing completed',
          createdAt: DateTime.utc(2026, 5, 30, 8, 46),
        ),
        if (_bridgeConversationSent)
          ConversationMessage(
            id: 'msg-2',
            conversationId: conversationId,
            role: 'assistant',
            content: 'Codex 已接收 Bridge 会话并返回真实回复',
            createdAt: DateTime.utc(2026, 5, 30, 8, 47),
          ),
      ],
      codexThreadError: null,
    );
  }

  @override
  Future<ConversationDetail> sendConversationMessage({
    required String conversationId,
    required String content,
  }) async {
    lastBridgeConversationId = conversationId;
    lastBridgeMessage = content;
    _bridgeConversationSent = true;
    return readConversation(conversationId: conversationId);
  }

  @override
  Future<List<CodexThreadGroup>> listCodexThreadGroups() async {
    if (failConversationHistory) {
      throw const SocketException('Connection reset by peer');
    }
    return [
      CodexThreadGroup(
        projectName: '调研Java_Harness',
        projectPath: r'C:\Users\TestUser\Desktop\个人资料\项目收集和调研\调研Java_Harness',
        threads: [
          CodexThreadSummary(
            id: 'thread-1',
            title: '实现手机小说 Agent',
            preview: '移动端小说 Agent 功能继续实现',
            projectName: '调研Java_Harness',
            projectPath:
                r'C:\Users\TestUser\Desktop\个人资料\项目收集和调研\调研Java_Harness',
            status: 'running',
            updatedAt: DateTime.utc(2026, 5, 31, 10),
          ),
          CodexThreadSummary(
            id: 'thread-2',
            title: '整理 Java Harness 文档',
            preview: '离线讲义和知识库整理',
            projectName: '调研Java_Harness',
            projectPath:
                r'C:\Users\TestUser\Desktop\个人资料\项目收集和调研\调研Java_Harness',
            status: 'completed',
            updatedAt: DateTime.utc(2026, 5, 30, 12),
          ),
          CodexThreadSummary(
            id: 'thread-subagent',
            title: '子 agent 分析线程',
            preview: '不应该插入主对话列表',
            projectName: '调研Java_Harness',
            projectPath:
                r'C:\Users\TestUser\Desktop\个人资料\项目收集和调研\调研Java_Harness',
            status: 'idle',
            updatedAt: DateTime.utc(2026, 5, 30, 11),
            threadSource: 'subagent',
            agentNickname: 'Fermat',
            agentRole: 'explorer',
          ),
          CodexThreadSummary(
            id: 'thread-4',
            title: '排查超长路径和多线程同步问题',
            preview: '窄屏也要能快速区分多个会话',
            projectName: '调研Java_Harness',
            projectPath:
                r'C:\Users\TestUser\Desktop\个人资料\项目收集和调研\调研Java_Harness',
            status: 'idle',
            updatedAt: DateTime.utc(2026, 5, 30, 9),
          ),
        ],
      ),
      CodexThreadGroup(
        projectName: 'codex_mobile_app',
        projectPath: r'C:\Users\TestUser\Desktop\code\dev\codex_mobile_app',
        threads: [
          CodexThreadSummary(
            id: 'thread-3',
            title: threadTitle,
            preview: '手机端和 Windows Bridge 同步开发',
            projectName: 'codex_mobile_app',
            projectPath: r'C:\Users\TestUser\Desktop\code\dev\codex_mobile_app',
            status: 'running',
            updatedAt: DateTime.utc(2026, 5, 31, 11),
          ),
        ],
      ),
    ];
  }

  @override
  Future<CodexThreadDetail> readCodexThread({required String threadId}) async {
    return CodexThreadDetail(
      thread: CodexThreadSummary(
        id: threadId,
        title: threadTitle,
        preview: '手机端和 Windows Bridge 同步开发',
        projectName: 'codex_mobile_app',
        projectPath: r'C:\Users\TestUser\Desktop\code\dev\codex_mobile_app',
        status: 'idle',
        updatedAt: DateTime.utc(2026, 5, 31, 11),
      ),
      messages: [
        const CodexThreadMessage(role: 'user', text: '手机端和 Windows 端同步'),
        const CodexThreadMessage(role: 'assistant', text: '已读取真实 Codex 线程'),
        const CodexThreadMessage(
          role: 'command',
          text: 'flutter test\nAll tests passed',
        ),
        if (_heldCodexTurn != null &&
            !_heldCodexTurn!.isCompleted &&
            lastTurnPrompt != null)
          CodexThreadMessage(role: 'user', text: lastTurnPrompt!),
        if (_heldCodexTurn != null &&
            !_heldCodexTurn!.isCompleted &&
            assistantDuringHeldTurn != null)
          CodexThreadMessage(role: 'assistant', text: assistantDuringHeldTurn!),
        if (_codexTurnSent)
          const CodexThreadMessage(
            role: 'assistant',
            text: 'Windows Codex 已继续执行手机发送的消息',
          ),
        ...externalThreadMessages,
      ],
    );
  }

  @override
  Future<CodexThreadDetail> startCodexTurn({
    required String threadId,
    required String prompt,
  }) async {
    lastTurnThreadId = threadId;
    lastTurnPrompt = prompt;
    if (holdCodexTurn) {
      _heldCodexTurn = Completer<CodexThreadDetail>();
      return _heldCodexTurn!.future;
    }

    _codexTurnSent = true;
    return readCodexThread(threadId: threadId);
  }

  void completeHeldCodexTurn() {
    final completer = _heldCodexTurn;
    if (completer == null || completer.isCompleted) {
      return;
    }

    _codexTurnSent = true;
    readCodexThread(
      threadId: lastTurnThreadId ?? 'thread-3',
    ).then(completer.complete);
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
  void setAccessToken(String? token) {
    accessToken = token?.trim().isEmpty == true ? null : token?.trim();
  }

  @override
  void setBridgeUrl(String bridgeUrl) {
    this.bridgeUrl = bridgeUrl;
  }

  @override
  Future<PairingChallenge> startPairing() async => PairingChallenge(
    id: 'challenge-start',
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
  Future<BridgeSecurityStatus> getSecurityStatus() async =>
      const BridgeSecurityStatus(
        pairingRequiresChallengeId: true,
        localOnlyEndpoints: ['/connect', '/pairing/start'],
        publicEndpoints: ['/health', '/pairing/complete'],
      );

  @override
  Future<List<PairingTokenStatus>> listPairingTokens() async => [
    PairingTokenStatus(
      fingerprint: 'abc123def456',
      deviceName: 'phone-a',
      expiresAt: DateTime.utc(2026, 6, 1, 20),
      isCurrent: true,
    ),
  ];

  @override
  Future<void> revokePairingToken({required String fingerprint}) async {}

  @override
  Future<CodexSyncSnapshot> getSyncState() async => _syncSnapshot();

  CodexSyncSnapshot _syncSnapshot() => CodexSyncSnapshot(
    goal: GoalRecord(
      id: 'goal-1',
      objective: '实现手机端查看 Codex 任务进度和完成情况',
      status: threadGoalStatus,
      source: 'windows-codex-history',
      threadId: 'thread-3',
      updatedAt: DateTime.utc(2026),
    ),
    goals: [
      GoalRecord(
        id: 'goal-1',
        objective: '实现手机端查看 Codex 任务进度和完成情况',
        status: threadGoalStatus,
        source: 'windows-codex-history',
        threadId: 'thread-3',
        updatedAt: DateTime.utc(2026),
      ),
      GoalRecord(
        id: 'goal-2',
        objective: '真实同步 Windows Codex 对话发送和回复',
        status: GoalStatus.active,
        source: 'windows-codex-history',
        updatedAt: DateTime.utc(2026, 6, 1, 1),
      ),
    ],
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
    events: syncEvents,
    updatedAt: DateTime.utc(2026),
  );

  @override
  Stream<CodexSyncSnapshot> watchSyncState() async* {
    final controller = _syncStreamController;
    if (controller != null) {
      yield* controller.stream;
      return;
    }

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
  }) async => CodexTaskRecord(
    id: 'task-2',
    title: title,
    detail: detail,
    status: CodexTaskStatus.pending,
    progressPercent: 0,
    summary: detail,
    updatedAt: DateTime.utc(2026),
  );
}
