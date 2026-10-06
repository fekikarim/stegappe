import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

import 'notifications_test_support.dart';

ProviderContainer containerWith({
  FakeNotificationsRepository? repo,
  FakeStompService? stomp,
}) {
  final container = ProviderContainer(
    overrides: [
      notificationRepositoryProvider
          .overrideWithValue(repo ?? FakeNotificationsRepository()),
      stompChatServiceProvider.overrideWithValue(stomp ?? FakeStompService()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Creates the controller (auto-dispose) and awaits its first REST load.
Future<NotificationsState> boot(ProviderContainer container) async {
  container.listen(notificationsControllerProvider, (_, _) {},
      fireImmediately: true);
  await pumpEventQueue();
  return container.read(notificationsControllerProvider);
}

void main() {
  group('REST is authoritative (acceptance 4/5)', () {
    test('the controller loads the first page and the unread count', () async {
      final repo = FakeNotificationsRepository(
        unread: 2,
        items: [
          notif('n1', title: 'Journal validé',
              createdAt: DateTime(2026, 9, 15, 9)),
          notif('n2', title: 'Bienvenue', isRead: true),
        ],
      );
      final state = await boot(containerWith(repo: repo));

      expect(state.items.map((n) => n.id), ['n1', 'n2']);
      expect(state.unreadCount, 2);
      expect(state.loaded, isTrue);
      expect(state.offlineCache, isFalse);
      expect(repo.queries, isNotEmpty);
      expect(repo.queries.last.size, 20);
      expect(repo.queries.last.unreadOnly, isFalse);
    });

    test('a first load failure surfaces the error instead of an empty page',
        () async {
      final repo = FakeNotificationsRepository()..failList = true;
      final state = await boot(containerWith(repo: repo));

      expect(state.error, isNotNull);
      expect(state.items, isEmpty);
      expect(state.loading, isFalse);
      expect(state.loaded, isTrue);
    });

    test('the unread filter is a server query, not a page-local filter',
        () async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [
          notif('n1', createdAt: DateTime(2026, 9, 15, 9)),
          notif('n2', isRead: true),
        ],
      );
      final container = containerWith(repo: repo);
      await boot(container);

      await container
          .read(notificationsControllerProvider.notifier)
          .setUnreadOnly(true);

      expect(repo.queries.last.unreadOnly, isTrue);
      expect(container.read(notificationsControllerProvider).unreadOnly, isTrue);
      expect(
        container.read(notificationsControllerProvider).items.map((n) => n.id),
        ['n1'],
      );
    });
  });

  group('live frames (BR-42)', () {
    test('a frame merges once — the same notification id never duplicates',
        () async {
      final repo = FakeNotificationsRepository(unread: 0);
      final container = containerWith(repo: repo);
      await boot(container);
      final frames = container.read(notificationFramesProvider);

      frames.add(frame('live-1'));
      frames.add(frame('live-1'));
      frames.add(frame('live-2'));
      await pumpEventQueue();

      final items = container.read(notificationsControllerProvider).items;
      expect(items.map((n) => n.id).toSet(), {'live-1', 'live-2'});
      expect(items, hasLength(2), reason: 'the duplicate id collapsed');
      expect(items.first.type, NotificationType.unknown,
          reason: 'a frame without a type degrades to the generic rendering');
    });

    test('frames stay newest-first with a stable id tie-break', () async {
      final container = containerWith();
      await boot(container);
      final frames = container.read(notificationFramesProvider);
      final sameMoment = DateTime(2026, 10, 1, 12);

      frames.add(frame('b', createdAt: sameMoment));
      frames.add(frame('a', createdAt: sameMoment));
      frames.add(frame('newer', createdAt: sameMoment.add(const Duration(hours: 1))));
      await pumpEventQueue();

      expect(
        container.read(notificationsControllerProvider).items.map((n) => n.id),
        ['newer', 'b', 'a'],
      );
    });

    test('a typed frame parses into the catalogue and refetches the badge',
        () async {
      final repo = FakeNotificationsRepository(unread: 3);
      final container = containerWith(repo: repo);
      await boot(container);

      container.read(notificationFramesProvider).add(
          frame('live-task', type: 'TASK_UPDATED', title: 'Tâche modifiée'));
      await pumpEventQueue();

      final item = container.read(notificationsControllerProvider).items.single;
      expect(item.type, NotificationType.taskUpdated);
      expect(item.title, 'Tâche modifiée');
      expect(item.relatedEntityType, 'Task');
      expect(container.read(notificationsControllerProvider).unreadCount, 3);
    });

    test('a malformed or unidentifiable frame never touches REST state',
        () async {
      final repo = FakeNotificationsRepository(
        items: [notif('n1', createdAt: DateTime(2026, 9, 15))],
      );
      final container = containerWith(repo: repo);
      await boot(container);
      final frames = container.read(notificationFramesProvider);

      frames.add('not json at all');
      frames.add('{"title":"no id"}');
      await pumpEventQueue();

      expect(
        container.read(notificationsControllerProvider).items.map((n) => n.id),
        ['n1'],
      );
    });

    test('a reconnect resyncs the authoritative list', () async {
      final repo = FakeNotificationsRepository(unread: 1);
      final stomp = FakeStompService();
      final container = containerWith(repo: repo, stomp: stomp);
      await boot(container);
      final before = repo.queries.length;

      stomp.setState(ChatConnectionState.connected);
      await pumpEventQueue();

      expect(repo.queries.length, greaterThan(before));
      expect(container.read(notificationsControllerProvider).live, isTrue);
    });
  });

  group('offline degradation (acceptance 5)', () {
    test('a failed refresh keeps the last known rows and flags the banner',
        () async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [notif('n1', createdAt: DateTime(2026, 9, 15))],
      );
      final container = containerWith(repo: repo);
      await boot(container);

      repo.failList = true;
      await container.read(notificationsControllerProvider.notifier).refresh();

      final state = container.read(notificationsControllerProvider);
      expect(state.items.map((n) => n.id), ['n1']);
      expect(state.offlineCache, isTrue);
      expect(state.error, isNull,
          reason: 'a degraded but usable list is not an error screen');
    });

    test('a failed unread-count read never breaks the list', () async {
      final repo = FakeNotificationsRepository(
        items: [notif('n1', createdAt: DateTime(2026, 9, 15))],
      )..failUnreadCount = true;
      final state = await boot(containerWith(repo: repo));

      expect(state.items, hasLength(1));
      expect(state.unreadCount, 0);
      expect(state.error, isNull);
    });
  });

  group('read actions are optimistic with rollback', () {
    test('markRead flags the row first, then persists through the server',
        () async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [notif('n1', createdAt: DateTime(2026, 9, 15))],
      );
      final container = containerWith(repo: repo);
      await boot(container);
      final row = container.read(notificationsControllerProvider).items.single;

      await container
          .read(notificationsControllerProvider.notifier)
          .markRead(row);

      expect(repo.read, ['n1']);
      expect(container.read(notificationsControllerProvider).items.single.isRead,
          isTrue);
    });

    test('a refused markRead rolls the optimistic flag back', () async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [notif('n1', createdAt: DateTime(2026, 9, 15))],
      );
      final container = containerWith(repo: repo);
      await boot(container);
      final row = container.read(notificationsControllerProvider).items.single;
      repo.failRead = true;

      await expectLater(
        container.read(notificationsControllerProvider.notifier).markRead(row),
        throwsA(isA<Exception>()),
      );

      final state = container.read(notificationsControllerProvider);
      expect(state.items.single.isRead, isFalse);
      expect(state.unreadCount, 1);
    });

    test('under the unread filter a read row leaves the list', () async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [notif('n1', createdAt: DateTime(2026, 9, 15))],
      );
      final container = containerWith(repo: repo);
      await boot(container);
      await container
          .read(notificationsControllerProvider.notifier)
          .setUnreadOnly(true);
      final row = container.read(notificationsControllerProvider).items.single;

      await container
          .read(notificationsControllerProvider.notifier)
          .markRead(row);

      expect(container.read(notificationsControllerProvider).items, isEmpty);
      expect(repo.read, ['n1']);
    });

    test('a failed markRead under the filter restores the row', () async {
      final repo = FakeNotificationsRepository(
        unread: 1,
        items: [notif('n1', createdAt: DateTime(2026, 9, 15))],
      );
      final container = containerWith(repo: repo);
      await boot(container);
      await container
          .read(notificationsControllerProvider.notifier)
          .setUnreadOnly(true);
      final row = container.read(notificationsControllerProvider).items.single;
      repo.failRead = true;

      await expectLater(
        container.read(notificationsControllerProvider.notifier).markRead(row),
        throwsA(isA<Exception>()),
      );

      expect(
        container.read(notificationsControllerProvider).items.map((n) => n.id),
        ['n1'],
      );
      expect(container.read(notificationsControllerProvider).unreadCount, 1);
    });

    test('markAllRead clears the badge and rolls back when the server refuses',
        () async {
      final repo = FakeNotificationsRepository(
        unread: 2,
        items: [
          notif('n1', createdAt: DateTime(2026, 9, 15)),
          notif('n2', createdAt: DateTime(2026, 9, 14)),
        ],
      );
      final container = containerWith(repo: repo);
      await boot(container);
      final notifier =
          container.read(notificationsControllerProvider.notifier);

      await notifier.markAllRead();
      expect(repo.readAllCalls, 1);
      expect(
        container.read(notificationsControllerProvider).items.every((n) => n.isRead),
        isTrue,
      );
      expect(container.read(notificationsControllerProvider).unreadCount, 0);

      // Rollback path: a refused bulk read must not leave a false "all read".
      repo.failReadAll = true;
      repo.items = [notif('n3', createdAt: DateTime(2026, 9, 16))];
      await notifier.refresh();
      await expectLater(notifier.markAllRead(), throwsA(isA<Exception>()));
      final rolledBack = container.read(notificationsControllerProvider);
      expect(rolledBack.items.single.isRead, isFalse,
          reason: 'the optimistic "all read" was rolled back');
      expect(rolledBack.unreadCount, 2,
          reason: 'the badge is restored to the pre-action server value');
    });
  });
}
