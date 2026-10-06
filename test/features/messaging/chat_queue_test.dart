import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/offline/pending_write_store.dart';
import 'package:stegappe/core/offline/pending_writes.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

import '../../test_fixtures.dart';
import 'messaging_widget_test.dart' show FakeMessagingRepo;
import 'notifications_test_support.dart'
    show FakeAuthRepository, FakeStompService;

/// T06/D12 chat queue: an offline send stays a visibly queued bubble (never
/// a phantom success, never lost); the flush persists it once with its key,
/// merges the server message and drops exactly that bubble.
void main() {
  late NetworkDownRepo repo;

  Future<ProviderContainer> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      internshipRepositoryProvider
          .overrideWithValue(FakeInternshipRepository()),
      messagingRepositoryProvider.overrideWithValue(repo),
      stompChatServiceProvider.overrideWithValue(FakeStompService()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repo = NetworkDownRepo();
  });

  test('offline send enqueues and keeps the bubble queued', () async {
    final c = await container();
    final controller =
        c.read(chatControllerProvider('c1').notifier);

    await controller.send('hello offline');
    expect(
        c
            .read(pendingWritesProvider)
            .items
            .where((w) =>
                w.kind == PendingWriteKind.message &&
                w.content == 'hello offline'),
        hasLength(1));
    expect(
        controller.state.pending.map((p) => p.content),
        contains('hello offline'));
    // No failure surfacing: queued is a normal offline state, not an error.
    expect(controller.state.failed, isEmpty);
  });

  test('flush persists once, merges the message and drops the bubble',
      () async {
    final c = await container();
    final controller =
        c.read(chatControllerProvider('c1').notifier);

    await controller.send('hello offline');
    repo.networkDown = false;
    await controller.flushQueued();
    await c.read(pendingWritesProvider.notifier).flushAll();

    expect(
        c.read(pendingWritesProvider).count, 0);
    expect(
        controller.state.pending
            .where((p) => p.content == 'hello offline'),
        isEmpty);
    expect(
        controller.state.messages
            .where((m) => m.sequenceNumber == 101),
        hasLength(1));
    expect(repo.sentKeys.where((k) => k != null).length, 1);
  });

  test('second flush does not duplicate (same key replays)', () async {
    final c = await container();
    final controller =
        c.read(chatControllerProvider('c1').notifier);

    await controller.send('once only');
    repo.networkDown = false;
    await controller.flushQueued();
    await controller.flushQueued();
    expect(
        c
            .read(pendingWritesProvider)
            .items
            .where((w) => w.content == 'once only'),
        isEmpty);
  });
}

class NetworkDownRepo extends FakeMessagingRepo {
  bool networkDown = true;

  @override
  Future<SentMessage?> send(String conversationId, String content) async {
    if (networkDown) {
      throw const ApiException(
          kind: ApiErrorKind.network, message: 'down');
    }
    return super.send(conversationId, content);
  }
}
