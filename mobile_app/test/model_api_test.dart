import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/api/bridge_endpoint.dart';
import 'package:mobile_app/src/models/approval.dart';
import 'package:mobile_app/src/models/bridge_network.dart';
import 'package:mobile_app/src/models/codex_file.dart';
import 'package:mobile_app/src/models/conversation.dart';
import 'package:mobile_app/src/models/project.dart';
import 'package:mobile_app/src/models/sync_state.dart';

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

    test('ProjectSummary treats Bridge-authorized roots as trusted by default', () {
      final project = ProjectSummary.fromJson({
        'id': 'project_1',
        'name': 'bridge',
        'rootPath': r'C:\repo',
      });

      expect(project.trusted, isTrue);
    });

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

    test('ApprovalRequest maps pending Bridge approvals to approve reject actions', () {
      final approval = ApprovalRequest.fromJson({
        'id': 'approval_1',
        'conversationId': 'conv_1',
        'summary': 'dotnet test',
        'decision': 'pending',
      });

      expect(approval.projectId, 'conv_1');
      expect(approval.title, 'dotnet test');
      expect(approval.command, 'dotnet test');
      expect(approval.actions, [ApprovalAction.approve, ApprovalAction.reject]);
    });

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
      expect(network.endpoints.every((endpoint) => endpoint.requiresPairing), isTrue);
      expect(network.warnings.single, contains('public host'));
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
        'updatedAt': '2026-05-31T11:20:00Z',
      });

      expect(snapshot.goal?.objective, contains('Codex'));
      expect(snapshot.tasks.first.status, CodexTaskStatus.running);
      expect(snapshot.tasks.first.progressPercent, 65);
      expect(snapshot.tasks.last.isComplete, isTrue);
    });
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
  });
}
