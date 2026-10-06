import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/realtime/realtime_sync.dart';
import 'package:stegappe/features/community/presentation/providers/community_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

/// T00 · acceptance criterion 5 — one place decides "refresh what".
void main() {
  group('category → provider mapping', () {
    test('every RealtimeCategory has a mapping entry', () {
      expect(kRealtimeTargets.keys.toSet(), RealtimeCategory.values.toSet(),
          reason: 'a new RealtimeCategory must declare its invalidation set');
    });

    test('tasks invalidates the task + dashboard + supervised providers', () {
      final targets = RiverpodRealtimeSync((_) {}).targetsFor(
        RealtimeCategory.tasks,
      );
      expect(
        targets,
        containsAll(<Object>[
          taskListProvider,
          internshipTasksProvider,
          supervisedInternsProvider,
          dashboardProvider,
        ]),
      );
    });

    test('notifications invalidates the feed + badge', () {
      final targets = RiverpodRealtimeSync((_) {})
          .targetsFor(RealtimeCategory.notifications);
      expect(targets,
          containsAll(<Object>[notificationsProvider, unreadNotificationsProvider]));
    });

    test('messages invalidates the conversation list + unread badge', () {
      final targets =
          RiverpodRealtimeSync((_) {}).targetsFor(RealtimeCategory.messages);
      expect(
        targets,
        containsAll(
            <Object>[conversationsProvider, totalUnreadMessagesProvider]),
      );
    });

    test('documents invalidates the deliverable + validation queues', () {
      final targets =
          RiverpodRealtimeSync((_) {}).targetsFor(RealtimeCategory.documents);
      expect(
        targets,
        containsAll(<Object>[
          deliverablesListProvider,
          journalListProvider,
          pendingValidationsProvider,
          pendingDeliverableReviewsProvider,
          pendingLogbookReviewsProvider,
        ]),
      );
    });

    test('community invalidates the feed + detail + reports providers', () {
      final targets = RiverpodRealtimeSync((_) {}).targetsFor(
        RealtimeCategory.community,
      );
      expect(targets, contains(communityFeedProvider));
      expect(targets, contains(communityReportsProvider));
    });
  });

  group('invalidation behaviour', () {
    test('invalidate re-runs the providers mapped to the category', () {
      var builds = 0;
      final counter = Provider<int>((ref) => ++builds);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sync = RiverpodRealtimeSync(
        container.invalidate,
        targets: {
          for (final category in RealtimeCategory.values)
            category: <ProviderOrFamily>[counter],
        },
      );

      container.read(counter);
      expect(builds, 1, reason: 'first read builds once');

      sync.invalidate(RealtimeCategory.tasks);
      container.read(counter);
      expect(builds, 2, reason: 'tasks invalidation must refetch');

      sync.invalidate(RealtimeCategory.messages);
      container.read(counter);
      expect(builds, 3, reason: 'messages invalidation must refetch');
    });

    test('invalidateAll is a no-op with nothing subscribed (no socket needed)',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sync = RiverpodRealtimeSync(container.invalidate);
      expect(sync.invalidateAll, returnsNormally);
      expect(() => sync.invalidate(RealtimeCategory.community), returnsNormally);
    });

    test('a category with an empty mapping invalidates nothing', () {
      var builds = 0;
      final counter = Provider<int>((ref) => ++builds);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sync = RiverpodRealtimeSync(
        container.invalidate,
        targets: const {},
      );
      container.read(counter);
      sync.invalidate(RealtimeCategory.tasks);
      container.read(counter);
      expect(builds, 1, reason: 'empty mapping must not refetch anything');
    });
  });
}
