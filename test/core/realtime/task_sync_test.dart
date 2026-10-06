import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/realtime/realtime_sync.dart';
import 'package:stegappe/core/realtime/task_sync.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

/// A task-class frame must invalidate exactly the task providers; anything
/// else (unknown, malformed, message frames) must not touch task state.
/// Frames are triggers, never state — so duplicates are harmless.
void main() {
  NotificationItem sampleItem(NotificationType type) => NotificationItem(
        id: 'n-${type.name}',
        title: 't',
        message: 'm',
        priority: 'NORMAL',
        createdAt: DateTime.utc(2026, 1, 1),
        isRead: false,
        type: type,
      );

  group('taskSyncCategoryFor', () {
    test('every task-class type maps to the tasks category', () {
      for (final type in [
        NotificationType.taskAssigned,
        NotificationType.taskUpdated,
        NotificationType.taskDeleted,
        NotificationType.taskStatusChanged,
        NotificationType.scheduledTaskVisible,
      ]) {
        expect(taskSyncCategoryFor(sampleItem(type)), RealtimeCategory.tasks,
            reason: '$type');
      }
    });

    test('non-task types map to null (badge-only refresh, as before)', () {
      for (final type in [
        NotificationType.messageReceived,
        NotificationType.documentRejected,
        NotificationType.welcome,
        NotificationType.unknown,
      ]) {
        expect(taskSyncCategoryFor(sampleItem(type)), isNull, reason: '$type');
      }
    });
  });

  group('frame-driven invalidation (RealtimeSync seam)', () {
    ProviderContainer containerWithLog(
        List<ProviderOrFamily> log) {
      final sync = RiverpodRealtimeSync(log.add);
      final container = ProviderContainer(overrides: [
        realtimeSyncProvider.overrideWithValue(sync),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('task frame invalidates the task providers only', () {
      final log = <ProviderOrFamily>[];
      final container = containerWithLog(log);
      final sync = container.read(realtimeSyncProvider);

      sync.invalidate(taskSyncCategoryFor(
          sampleItem(NotificationType.taskUpdated))!);
      expect(
          log,
          orderedEquals([
            taskListProvider,
            internshipTasksProvider,
            supervisedInternsProvider,
            dashboardProvider,
          ]));
    });

    test('duplicate frames only repeat the same invalidations', () {
      final log = <ProviderOrFamily>[];
      final container = containerWithLog(log);
      final sync = container.read(realtimeSyncProvider);
      final category = taskSyncCategoryFor(
          sampleItem(NotificationType.taskStatusChanged))!;

      sync.invalidate(category);
      sync.invalidate(category);
      expect(log.length, 8);
      // Invalidation is idempotent downstream: Riverpod refetches REST.
    });

    test('malformed payloads never reach the sync layer', () {
      expect(notificationItemFromFrame('not-json'), isNull);
      expect(notificationItemFromFrame('{"no":"id"}'), isNull);
      expect(notificationItemFromFrame('[]'), isNull);
    });

    test('reconnect resync invalidates every category', () {
      final log = <ProviderOrFamily>[];
      final container = containerWithLog(log);
      container.read(realtimeSyncProvider).invalidateAll();
      // Every category maps to its providers (community maps to none).
      expect(log, contains(taskListProvider));
      expect(log, contains(notificationsProvider));
      expect(log, contains(conversationsProvider));
    });
  });
}
