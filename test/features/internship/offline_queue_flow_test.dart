import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/offline/pending_writes.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

import '../../test_fixtures.dart';
import '../messaging/messaging_widget_test.dart'
    show FakeMessagingRepo;
import '../messaging/notifications_test_support.dart'
    show FakeAuthRepository;

/// T06/D12 offline queue flows: enqueue → reconnect flush applies each
/// write exactly once (server key replay), conflicts resolve by the
/// server's answer, auth failure signs out and discards with notice.
void main() {
  late FailingInternRepo internRepo;
  late FailingMessagingRepo msgRepo;

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
      internshipRepositoryProvider.overrideWithValue(internRepo),
      messagingRepositoryProvider.overrideWithValue(msgRepo),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    internRepo = FailingInternRepo();
    msgRepo = FailingMessagingRepo();
  });

  PendingWritesController queueOf(ProviderContainer c) =>
      c.read(pendingWritesProvider.notifier);

  group('task-status queue', () {
    test('enqueue collapses per task; flush applies once with the key',
        () async {
      final c = await container();
      final queue = queueOf(c);

      expect(
          await queue.enqueueStatus(
              taskId: 't1', status: TaskStatus.inProgress),
          isTrue);
      expect(
          await queue.enqueueStatus(
              taskId: 't1', status: TaskStatus.awaitingApproval),
          isTrue);
      // One pending write per task: the newer intent replaced the older.
      expect(c.read(pendingWritesProvider).count, 1);

      await queue.flushTaskStatuses();
      expect(internRepo.statusUpdates, [
        ('t1', TaskStatus.awaitingApproval),
      ]);
      expect(internRepo.statusKeys.single, isNotNull);
      expect(c.read(pendingWritesProvider).count, 0);
    });

    test('duplicate flush is safe (server replay, no second effect)',
        () async {
      final c = await container();
      final queue = queueOf(c);

      await queue.enqueueStatus(
          taskId: 't1', status: TaskStatus.inProgress);
      await queue.flushTaskStatuses();
      await queue.flushTaskStatuses();
      expect(internRepo.statusUpdates.length, 1);
    });

    test('404 answer discards the row (server resolved the conflict)',
        () async {
      final c = await container();
      internRepo.failure = const ApiException(
          kind: ApiErrorKind.notFound, message: 'gone', statusCode: 404);
      final queue = queueOf(c);

      await queue.enqueueStatus(
          taskId: 't-gone', status: TaskStatus.inProgress);
      await queue.flushTaskStatuses();
      expect(c.read(pendingWritesProvider).count, 0);
      expect(internRepo.statusUpdates, isEmpty);
    });

    test('transport failure keeps the row for the next flush', () async {
      final c = await container();
      internRepo.failure = const ApiException(
          kind: ApiErrorKind.network, message: 'down');
      final queue = queueOf(c);

      await queue.enqueueStatus(
          taskId: 't1', status: TaskStatus.inProgress);
      await queue.flushTaskStatuses();
      expect(c.read(pendingWritesProvider).count, 1);

      internRepo.failure = null;
      await queue.flushTaskStatuses();
      expect(c.read(pendingWritesProvider).count, 0);
      expect(internRepo.statusUpdates.length, 1);
    });

    test('401 signs out, discards the queue and raises the notice',
        () async {
      final c = await container();
      internRepo.failure = const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: 'expired',
          statusCode: 401);
      final queue = queueOf(c);

      await queue.enqueueStatus(
          taskId: 't1', status: TaskStatus.inProgress);
      await queue.flushTaskStatuses();

      final state = c.read(pendingWritesProvider);
      expect(state.count, 0);
      expect(state.authDiscarded, isTrue);
      final auth = c.read(authControllerProvider);
      expect(auth, isA<AuthUnauthenticated>());
      expect((auth as AuthUnauthenticated).message,
          'queue-auth-discarded');
    });

    test('logout wipes the queue (no leak into the next session)',
        () async {
      final c = await container();
      final queue = queueOf(c);

      await queue.enqueueStatus(
          taskId: 't1', status: TaskStatus.inProgress);
      expect(c.read(pendingWritesProvider).count, 1);
      await queue.clear();
      expect(c.read(pendingWritesProvider).count, 0);
    });
  });

  group('message queue', () {
    test('flush sends with keys and reports delivered localIds', () async {
      final c = await container();
      final queue = queueOf(c);

      await queue.enqueueMessage(
          conversationId: 'c1', content: 'hi', localId: 'p1');
      await queue.enqueueMessage(
          conversationId: 'c1', content: 'yo', localId: 'p2');
      final delivered = await queue.flushConversation('c1');

      expect(msgRepo.sentKeys.length, 2);
      expect(msgRepo.sentKeys.toSet().length, 2);
      expect(delivered.map((d) => d.localId), ['p1', 'p2']);
      expect(c.read(pendingWritesProvider).count, 0);
    });

    test('flushAll covers every conversation with queued writes', () async {
      final c = await container();
      final queue = queueOf(c);

      await queue.enqueueMessage(
          conversationId: 'c1', content: 'hi', localId: 'p1');
      final out = await queue.flushAll();
      expect(out['c1']?.length, 1);
    });

    test('queue survives a controller rebuild (persisted store)', () async {
      final prefs = await SharedPreferences.getInstance();
      final first = ProviderContainer(overrides: [
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        internshipRepositoryProvider.overrideWithValue(internRepo),
        messagingRepositoryProvider.overrideWithValue(msgRepo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ]);
      await first
          .read(pendingWritesProvider.notifier)
          .enqueueStatus(taskId: 't1', status: TaskStatus.inProgress);
      first.dispose();

      final second = ProviderContainer(overrides: [
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        internshipRepositoryProvider.overrideWithValue(internRepo),
        messagingRepositoryProvider.overrideWithValue(msgRepo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ]);
      addTearDown(second.dispose);
      expect(second.read(pendingWritesProvider).count, 1);
    });
  });
}

class FailingInternRepo extends FakeInternshipRepository {
  Object? failure;

  @override
  Future<InternTask> updateTaskStatus(String taskId, TaskStatus status,
      {String? idempotencyKey}) async {
    if (failure != null) throw failure!;
    return super.updateTaskStatus(taskId, status,
        idempotencyKey: idempotencyKey);
  }
}

class FailingMessagingRepo extends FakeMessagingRepo {
  Object? failure;

  @override
  Future<ChatMessage> sendRest(String conversationId, String content,
      {String? idempotencyKey}) async {
    if (failure != null) throw failure!;
    return super.sendRest(conversationId, content,
        idempotencyKey: idempotencyKey);
  }
}
