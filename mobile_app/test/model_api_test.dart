import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/api/bridge_endpoint.dart';
import 'package:mobile_app/src/api/codex_mobile_api.dart';
import 'package:mobile_app/src/models/approval.dart';
import 'package:mobile_app/src/models/bridge_network.dart';
import 'package:mobile_app/src/models/codex_backend.dart';
import 'package:mobile_app/src/models/codex_file.dart';
import 'package:mobile_app/src/models/codex_thread.dart';
import 'package:mobile_app/src/models/conversation.dart';
import 'package:mobile_app/src/models/project.dart';
import 'package:mobile_app/src/models/sync_state.dart';
import 'package:mobile_app/src/screens/conversations_screen.dart';
import 'package:mobile_app/src/screens/pairing_screen.dart';

void main() {
  group('models parse bridge JSON', () {
    test('ProjectSummary keeps identity, path, and trust state', () {
      final project = ProjectSummary.fromJson({
        'id': 'proj-1',
        'name': 'codex_mobile_app',
        'rootPath': r'C:\work\codex_mobile_app',
        'trusted': true,
      });

      expect(project.id, 'proj-1');
      expect(project.name, 'codex_mobile_app');
      expect(project.rootPath, r'C:\work\codex_mobile_app');
      expect(project.trusted, isTrue);
    });

    test(
      'ProjectSummary treats Bridge-authorized roots as trusted by default',
      () {
        final project = ProjectSummary.fromJson({
          'id': 'project_1',
          'name': 'bridge',
          'rootPath': r'C:\repo',
        });

        expect(project.trusted, isTrue);
      },
    );

    test('CodexFile preserves file metadata and preview text', () {
      final file = CodexFile.fromJson({
        'name': 'main.dart',
        'path': 'lib/main.dart',
        'kind': 'file',
        'sizeBytes': 2048,
        'preview': 'void main() {}',
      });

      expect(file.name, 'main.dart');
      expect(file.isDirectory, isFalse);
      expect(file.sizeBytes, 2048);
      expect(file.preview, 'void main() {}');
    });

    test('CodexFile reads Bridge list entries', () {
      final file = CodexFile.fromJson({
        'name': 'src',
        'relativePath': 'lib/src',
        'isDirectory': true,
        'size': 0,
      });

      expect(file.path, 'lib/src');
      expect(file.isDirectory, isTrue);
    });

    test('CodexFile detects HTML files for embedded preview routing', () {
      final page = CodexFile.fromJson({
        'name': 'report.HTML',
        'path': 'docs/report.HTML',
        'kind': 'file',
      });
      final fragment = CodexFile.fromJson({
        'name': 'snippet.htm',
        'path': 'preview/snippet.htm',
        'kind': 'file',
      });

      expect(page.isHtmlFile, isTrue);
      expect(fragment.isHtmlFile, isTrue);
    });

    test('FilePreview treats html content types and language as HTML', () {
      final html = FilePreview.fromJson({
        'path': 'dist/index.html',
        'content': '<!doctype html><html><body>Phone flow</body></html>',
        'language': 'html',
        'contentType': 'text/html; charset=utf-8',
      });
      final xhtml = FilePreview.fromJson({
        'path': 'dist/index.xhtml',
        'content': '<html xmlns="http://www.w3.org/1999/xhtml" />',
        'contentType': 'application/xhtml+xml',
      });

      expect(html.isHtml, isTrue);
      expect(xhtml.isHtml, isTrue);
    });

    test('ConversationSummary reads latest message and unread count', () {
      final conversation = ConversationSummary.fromJson({
        'id': 'thread-1',
        'title': 'Bridge setup',
        'updatedAt': '2026-05-30T08:45:00Z',
        'latestMessage': 'Pairing completed',
        'unreadCount': 2,
      });

      expect(conversation.title, 'Bridge setup');
      expect(conversation.updatedAt.toUtc().year, 2026);
      expect(conversation.latestMessage, 'Pairing completed');
      expect(conversation.unreadCount, 2);
    });

    test('ConversationDetail reads conversation snapshot messages', () {
      final detail = ConversationDetail.fromJson({
        'conversation': {
          'id': 'conv-1',
          'title': 'Bridge setup',
          'projectId': 'proj-1',
          'workingDirectory': r'C:\repo',
          'createdAt': '2026-05-31T08:45:00Z',
          'updatedAt': '2026-05-31T08:50:00Z',
        },
        'messages': [
          {
            'id': 'msg-1',
            'conversationId': 'conv-1',
            'role': 'user',
            'content': '继续 Bridge 本地会话',
            'createdAt': '2026-05-31T08:46:00Z',
          },
          {
            'id': 'msg-2',
            'conversationId': 'conv-1',
            'role': 'assistant',
            'content': 'Pairing completed',
            'createdAt': '2026-05-31T08:47:00Z',
          },
        ],
      });

      expect(detail.conversation.id, 'conv-1');
      expect(detail.conversation.title, 'Bridge setup');
      expect(detail.messages.map((message) => message.role), [
        'user',
        'assistant',
      ]);
      expect(detail.messages.last.content, 'Pairing completed');
    });

    test(
      'ConversationDetail combines pending local messages with real Codex thread messages',
      () {
        final detail = ConversationDetail.fromJson({
          'conversation': {
            'id': 'conv-1',
            'title': '手机发起的 Windows 会话',
            'projectId': 'proj-1',
            'workingDirectory': r'C:\repo',
            'codexThreadId': 'thread-live-1',
            'createdAt': '2026-06-01T08:45:00Z',
            'updatedAt': '2026-06-01T08:50:00Z',
          },
          'messages': [
            {
              'id': 'msg-local-user',
              'conversationId': 'conv-1',
              'role': 'user',
              'content': '手机刚发送但 Codex 线程还没刷新',
              'createdAt': '2026-06-01T08:46:00Z',
            },
          ],
          'codexThread': {
            'thread': {
              'id': 'thread-live-1',
              'name': '真实 Windows Codex 线程',
              'cwd': r'C:\repo',
              'updatedAt': 1780207200,
              'status': 'running',
              'turns': [
                {
                  'items': [
                    {'type': 'agentMessage', 'text': 'Windows Codex 已读取真实线程内容'},
                  ],
                },
              ],
            },
          },
          'codexThreadError': 'app-server timed out once and recovered',
        });

        expect(detail.conversation.codexThreadId, 'thread-live-1');
        expect(detail.codexThreadError, contains('timed out'));
        expect(detail.messages.map((message) => message.content), [
          '手机刚发送但 Codex 线程还没刷新',
          'Windows Codex 已读取真实线程内容',
        ]);
        expect(detail.messages.map((message) => message.source), [
          'bridge-local',
          'windows-codex',
        ]);
      },
    );

    test(
      'ConversationDetail deduplicates identical local and Codex messages while keeping the Windows source',
      () {
        final detail = ConversationDetail.fromJson({
          'conversation': {
            'id': 'conv-2',
            'title': '同步去重',
            'projectId': 'proj-1',
            'workingDirectory': r'C:\repo',
            'codexThreadId': 'thread-live-2',
            'createdAt': '2026-06-01T08:45:00Z',
            'updatedAt': '2026-06-01T08:50:00Z',
          },
          'messages': [
            {
              'id': 'msg-local-user',
              'conversationId': 'conv-2',
              'role': 'assistant',
              'content': 'Codex 已接收 Bridge 会话并返回真实回复',
              'createdAt': '2026-06-01T08:46:00Z',
            },
          ],
          'codexThread': {
            'thread': {
              'id': 'thread-live-2',
              'name': '同步去重',
              'cwd': r'C:\repo',
              'updatedAt': 1780207200,
              'status': 'running',
              'turns': [
                {
                  'items': [
                    {
                      'type': 'agentMessage',
                      'text': 'Codex 已接收 Bridge 会话并返回真实回复',
                    },
                  ],
                },
              ],
            },
          },
        });

        expect(detail.messages, hasLength(1));
        expect(detail.messages.single.source, 'windows-codex');
      },
    );

    test('CodexThreadSummary reads app-server thread list entries', () {
      final thread = CodexThreadSummary.fromJson({
        'id': 'thread_123',
        'name': null,
        'preview': '整理 Java Harness 文档',
        'cwd': r'C:\Users\TestUser\Desktop\个人资料\项目收集和调研\调研Java_Harness',
        'updatedAt': 1780207200,
        'status': 'running',
      });

      expect(thread.id, 'thread_123');
      expect(thread.title, '整理 Java Harness 文档');
      expect(thread.projectName, '调研Java_Harness');
      expect(thread.projectPath, contains('调研Java_Harness'));
      expect(thread.status, 'running');
      expect(thread.updatedAt.toUtc().year, 2026);
    });

    test(
      'CodexThreadCollection groups app-server threads by project folder',
      () {
        final groups = CodexThreadCollection.fromJson({
          'method': 'thread/list',
          'json': {
            'data': [
              {
                'id': 'thread_1',
                'name': '实现手机小说 Agent',
                'preview': 'fallback',
                'cwd': r'C:\Users\TestUser\Desktop\个人资料\项目收集和调研\调研Java_Harness',
                'updatedAt': 1780207200,
                'status': 'completed',
              },
              {
                'id': 'thread_2',
                'name': null,
                'preview': '读取课程文档并转MD',
                'cwd': r'C:\Users\TestUser\Desktop\个人资料\鱼皮知识库',
                'updatedAt': 1780120800,
                'status': 'idle',
              },
            ],
          },
        }).groups;

        expect(groups.map((group) => group.projectName), [
          '调研Java_Harness',
          '鱼皮知识库',
        ]);
        expect(groups.first.threads.single.title, '实现手机小说 Agent');
        expect(groups.last.threads.single.title, '读取课程文档并转MD');
      },
    );

    test(
      'CodexThreadCollection filters subagent threads from mobile history',
      () {
        final groups = CodexThreadCollection.fromJson({
          'data': [
            {
              'id': 'main-thread',
              'name': '主对话',
              'cwd': r'C:\repo',
              'threadSource': 'user',
              'updatedAt': 1780207200,
            },
            {
              'id': 'subagent-thread',
              'name': '子 agent 对话',
              'cwd': r'C:\repo',
              'threadSource': 'subagent',
              'agentNickname': 'Fermat',
              'agentRole': 'explorer',
              'updatedAt': 1780207100,
            },
          ],
        }).groups;

        expect(groups.single.threads.map((thread) => thread.id), [
          'main-thread',
        ]);
      },
    );

    test(
      'CodexThreadDetail extracts readable messages from thread read response',
      () {
        final detail = CodexThreadDetail.fromJson({
          'method': 'thread/read',
          'json': {
            'thread': {
              'id': 'thread_1',
              'name': '实现调研目标并测试',
              'preview': 'fallback',
              'cwd': r'C:\Users\TestUser\Desktop\code\dev\codex_mobile_app',
              'updatedAt': 1780207200,
              'status': 'idle',
              'turns': [
                {
                  'items': [
                    {
                      'type': 'userMessage',
                      'content': [
                        {'type': 'text', 'text': '手机端和 Windows 端同步'},
                      ],
                    },
                    {'type': 'agentMessage', 'text': '已读取真实 Codex 线程'},
                    {
                      'type': 'commandExecution',
                      'command': 'flutter test',
                      'aggregatedOutput': 'All tests passed',
                    },
                  ],
                },
              ],
            },
          },
        });

        expect(detail.thread.title, '实现调研目标并测试');
        expect(detail.messages.map((message) => message.role), [
          'user',
          'assistant',
          'command',
        ]);
        expect(detail.messages.first.text, contains('Windows'));
        expect(detail.messages.last.text, contains('All tests passed'));
      },
    );

    test(
      'CodexThreadDetail merges adjacent assistant chunks from one turn',
      () {
        final detail = CodexThreadDetail.fromJson({
          'thread': {
            'id': 'thread_1',
            'name': '一次请求多段回复',
            'cwd': r'C:\repo',
            'turns': [
              {
                'items': [
                  {'type': 'agentMessage', 'text': '第一点'},
                  {'type': 'agentMessage', 'text': '第二点'},
                  {
                    'type': 'userMessage',
                    'content': [
                      {'type': 'text', 'text': '下一次请求'},
                    ],
                  },
                  {'type': 'agentMessage', 'text': '新的回复'},
                ],
              },
            ],
          },
        });

        expect(detail.messages.map((message) => message.role), [
          'assistant',
          'user',
          'assistant',
        ]);
        expect(detail.messages.first.text, contains('第一点'));
        expect(detail.messages.first.text, contains('第二点'));
      },
    );

    test(
      'CodexThreadDetail renders Bridge mobile user overlay as a normal user message',
      () {
        final detail = CodexThreadDetail.fromJson({
          'thread': {
            'id': 'thread_mobile_overlay',
            'name': '手机消息 overlay',
            'cwd': r'C:\repo',
            'turns': [
              {
                'items': [
                  {'type': 'agentMessage', 'text': 'Windows 旧回复'},
                  {
                    'type': 'userMessage',
                    'id': 'mobile_user_1',
                    'source': 'mobile-bridge',
                    'content': [
                      {'type': 'text', 'text': '手机端发送但 Windows 历史尚未刷新'},
                    ],
                  },
                ],
              },
            ],
          },
        });

        expect(detail.messages.map((message) => message.role), [
          'assistant',
          'user',
        ]);
        expect(detail.messages.last.text, '手机端发送但 Windows 历史尚未刷新');
      },
    );

    test('CodexThreadDetail hides instruction blocks from readable chat', () {
      final detail = CodexThreadDetail.fromJson({
        'thread': {
          'id': 'thread_1',
          'name': '过滤指令',
          'cwd': r'C:\repo',
          'turns': [
            {
              'items': [
                {
                  'type': 'agentMessage',
                  'text':
                      '<permissions instructions>\nFilesystem sandboxing defines which files can be read or written.',
                },
                {'type': 'agentMessage', 'text': '真实助手回复'},
                {
                  'type': 'userMessage',
                  'content': [
                    {'type': 'text', 'text': '真实用户问题'},
                  ],
                },
              ],
            },
          ],
        },
      });

      expect(detail.messages.map((message) => message.text), [
        '真实助手回复',
        '真实用户问题',
      ]);
    });

    test('ApprovalRequest reads commands and available actions', () {
      final approval = ApprovalRequest.fromJson({
        'id': 'approval-1',
        'projectId': 'proj-1',
        'title': 'Run tests',
        'command': 'flutter test',
        'risk': 'medium',
        'actions': ['approve', 'reject'],
      });

      expect(approval.command, 'flutter test');
      expect(approval.risk, ApprovalRisk.medium);
      expect(approval.actions, [ApprovalAction.approve, ApprovalAction.reject]);
    });

    test(
      'ApprovalRequest maps pending Bridge approvals to approve reject actions',
      () {
        final approval = ApprovalRequest.fromJson({
          'id': 'approval_1',
          'conversationId': 'conv_1',
          'summary': 'dotnet test',
          'decision': 'pending',
        });

        expect(approval.projectId, 'conv_1');
        expect(approval.title, 'dotnet test');
        expect(approval.command, 'dotnet test');
        expect(approval.actions, [
          ApprovalAction.approve,
          ApprovalAction.reject,
        ]);
      },
    );

    test('BridgeNetworkSummary reads private and mesh bridge URLs', () {
      final network = BridgeNetworkSummary.fromJson({
        'scheme': 'http',
        'port': 51870,
        'publicExposureAllowed': false,
        'endpoints': [
          {
            'host': '127.0.0.1',
            'url': 'http://127.0.0.1:51870',
            'scope': 'loopback',
            'requiresPairing': true,
            'isRecommendedForMobile': false,
          },
          {
            'host': '192.168.31.25',
            'url': 'http://192.168.31.25:51870',
            'scope': 'private-lan',
            'requiresPairing': true,
            'isRecommendedForMobile': true,
          },
          {
            'host': '100.72.10.9',
            'url': 'http://100.72.10.9:51870',
            'scope': 'mesh-vpn',
            'requiresPairing': true,
            'isRecommendedForMobile': true,
          },
        ],
        'warnings': ['Skipped public host 8.8.8.8'],
      });

      expect(network.publicExposureAllowed, isFalse);
      expect(network.endpoints.map((endpoint) => endpoint.scope), [
        'loopback',
        'private-lan',
        'mesh-vpn',
      ]);
      expect(
        network.endpoints.every((endpoint) => endpoint.requiresPairing),
        isTrue,
      );
      expect(network.warnings.single, contains('public host'));
    });

    test('PairingTokenStatus parses safe token inventory fields', () {
      final token = PairingTokenStatus.fromJson({
        'fingerprint': 'abc123def456',
        'deviceName': 'phone-a',
        'expiresAt': '2026-06-01T20:00:00Z',
        'isCurrent': true,
      });

      expect(token.fingerprint, 'abc123def456');
      expect(token.deviceName, 'phone-a');
      expect(token.isCurrent, isTrue);
    });

    test('CodexSyncSnapshot reads goal and task progress', () {
      final snapshot = CodexSyncSnapshot.fromJson({
        'goal': {
          'id': 'goal-1',
          'objective': '实现手机端查看 Codex 任务进度',
          'status': 'active',
          'source': 'mobile',
          'updatedAt': '2026-05-31T11:00:00Z',
        },
        'goals': [
          {
            'id': 'goal-1',
            'objective': '实现手机端查看 Codex 任务进度',
            'status': 'active',
            'source': 'mobile',
            'updatedAt': '2026-05-31T11:00:00Z',
          },
          {
            'id': 'goal-2',
            'objective': '同步第二个 Windows goal',
            'status': 'active',
            'source': 'windows-codex-history',
            'updatedAt': '2026-05-31T11:05:00Z',
          },
        ],
        'tasks': [
          {
            'id': 'task-1',
            'title': 'Bridge sync',
            'detail': 'Wire /sync/stream',
            'status': 'running',
            'progressPercent': 65,
            'summary': 'SSE connected',
            'updatedAt': '2026-05-31T11:10:00Z',
          },
          {
            'id': 'task-2',
            'title': 'Flutter goal panel',
            'detail': 'Show progress',
            'status': 'completed',
            'progressPercent': 100,
            'summary': 'Rendered on mobile',
            'updatedAt': '2026-05-31T11:20:00Z',
          },
        ],
        'jobs': [
          {
            'id': 'turn_job_1',
            'threadId': 'thread-3',
            'status': 'running',
            'promptPreview': '离开手机页面以后也要继续追踪这个对话',
            'lastMessage': 'Bridge 正在调用 Windows Codex app-server',
            'createdAt': '2026-05-31T11:08:00Z',
            'updatedAt': '2026-05-31T11:10:00Z',
            'startedAt': '2026-05-31T11:09:00Z',
          },
        ],
        'events': [
          {
            'type': 'goal.recovered',
            'entityId': 'goal-1',
            'timestamp': '2026-05-31T11:00:00Z',
          },
          {
            'type': 'task.updated',
            'entityId': 'task-1',
            'timestamp': '2026-05-31T11:10:00Z',
          },
        ],
        'updatedAt': '2026-05-31T11:20:00Z',
      });

      expect(snapshot.goal?.objective, contains('Codex'));
      expect(snapshot.goals.map((goal) => goal.objective), [
        '实现手机端查看 Codex 任务进度',
        '同步第二个 Windows goal',
      ]);
      expect(snapshot.tasks.first.status, CodexTaskStatus.running);
      expect(snapshot.tasks.first.progressPercent, 65);
      expect(snapshot.tasks.last.isComplete, isTrue);
      expect(snapshot.jobs.single.id, 'turn_job_1');
      expect(snapshot.jobs.single.status, CodexTurnJobStatus.running);
      expect(snapshot.jobs.single.isActive, isTrue);
      expect(snapshot.jobs.single.promptPreview, contains('离开手机页面'));
      expect(snapshot.events.map((event) => event.type), [
        'goal.recovered',
        'task.updated',
      ]);
    });

    test(
      'CodexBackendStatus explains live and fallback conversation modes',
      () {
        final live = CodexBackendStatus.fromJson({
          'available': true,
          'message': 'codex app-server reachable',
          'checkedAt': '2026-06-01T12:00:00Z',
        });
        final fallback = CodexBackendStatus.fromJson({
          'available': false,
          'message': 'codex app-server timed out',
          'checkedAt': '2026-06-01T12:01:00Z',
        });

        expect(live.label, 'Bridge 实时');
        expect(live.usesFallbackHistory, isFalse);
        expect(fallback.label, '历史兜底');
        expect(fallback.usesFallbackHistory, isTrue);
        expect(fallback.message, contains('timed out'));
      },
    );

    test('conversation file links keep existing markdown links intact', () {
      const source =
          '[C:\\Users\\doob\\Desktop\\学校提交\\2026年复习资料\\数据库\\superpowers\\plans\\2026-05-31-2024-exam-latex-render-fix.md](file-ref:C:\\Users\\doob\\Desktop\\学校提交\\2026年复习资料\\数据库\\superpowers\\plans\\2026-05-31-2024-exam-latex-render-fix.md)';

      expect(linkifyConversationFileReferences(source), source);
    });

    test('conversation file references decode encoded windows paths', () {
      final encoded =
          'file-ref:C:/Users/doob/Desktop/%E5%AD%A6%E6%A0%A1%E6%8F%90%E4%BA%A4/2026%E5%B9%B4%E5%A4%8D%E4%B9%A0%E8%B5%84%E6%96%99/%E6%95%B0%E6%8D%AE%E5%BA%93/superpowers/plans/2026-05-31-2024-exam-latex-render-fix.md';

      final decoded = normalizeConversationFileReference(encoded);

      expect(decoded, contains('学校提交'));
      expect(
        decoded,
        contains(
          '数据库/superpowers/plans/2026-05-31-2024-exam-latex-render-fix.md',
        ),
      );
      expect(decoded, isNot(contains('%E5')));
    });

    test(
      'absolute conversation file paths resolve under the longest project root',
      () {
        const projects = [
          ProjectSummary(
            id: 'desktop',
            name: 'Desktop',
            rootPath: r'C:\Users\doob\Desktop',
            trusted: true,
          ),
          ProjectSummary(
            id: 'db',
            name: '数据库',
            rootPath: r'C:\Users\doob\Desktop\学校提交\2026年复习资料\数据库',
            trusted: true,
          ),
        ];

        final match = matchProjectByAbsolutePath(
          projects,
          r'C:\Users\doob\Desktop\学校提交\2026年复习资料\数据库\superpowers\plans\2026-05-31-2024-exam-latex-render-fix.md',
        );

        expect(match?.project.id, 'db');
        expect(
          match?.basePath,
          'superpowers/plans/2026-05-31-2024-exam-latex-render-fix.md',
        );
      },
    );
  });

  group('BridgeEndpoint', () {
    test('constructs service URLs with encoded query values', () {
      final endpoint = BridgeEndpoint('http://127.0.0.1:5010/api/');

      final uri = endpoint.uri('/files/read', {
        'projectId': 'proj 1',
        'path': r'lib\main.dart',
      });

      expect(
        uri.toString(),
        'http://127.0.0.1:5010/api/files/read?projectId=proj+1&path=lib%5Cmain.dart',
      );
    });

    test('web endpoint uses current origin instead of stale saved LAN URL', () {
      final resolved = resolveBridgeUrlForEndpoint(
        'http://10.250.236.241:5010',
        isWeb: true,
        webOrigin:
            'https://reservations-subtle-fabrics-perform.trycloudflare.com',
      );

      expect(
        resolved,
        'https://reservations-subtle-fabrics-perform.trycloudflare.com',
      );
    });

    test('web QR candidates prefer current origin before private QR URLs', () {
      final candidates = bridgeCandidatesForCurrentWebOrigin(
        ['http://10.250.236.241:5010', 'https://old.trycloudflare.com'],
        isWeb: true,
        webOrigin: 'https://current.trycloudflare.com',
      );

      expect(candidates, [
        'https://current.trycloudflare.com',
        'http://10.250.236.241:5010',
        'https://old.trycloudflare.com',
      ]);
    });
  });
}
