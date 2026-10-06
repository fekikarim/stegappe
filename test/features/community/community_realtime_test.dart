import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/realtime/community_sync.dart';
import 'package:stegappe/core/realtime/realtime_sync.dart';
import 'package:stegappe/features/community/domain/entities/community.dart';
import 'package:stegappe/features/community/presentation/providers/community_providers.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

import 'community_test_support.dart';
import '../messaging/messaging_widget_test.dart' show FakeStomp;

/// T08 realtime: topic envelopes as invalidation triggers, notification
/// frames as sync triggers, reconnect/resync coverage, duplicate safety.
void main() {
  NotificationItem frame(String type, String postId) =>
      notificationItemFromPayloadJson({
        'id': 'n-$type-$postId',
        'type': type,
        'title': 't',
        'message': 'm',
        'priority': 'NORMAL',
        'relatedEntityType': 'CommunityPost',
        'relatedEntityId': postId,
        'createdAt': '2026-09-15T12:00:00Z',
      })!;

  group('sync triggers', () {
    test('community notification types map to the community category',
        () {
      expect(
          communitySyncCategoryFor(
              frame('COMMUNITY_COMMENT', 'p1')),
          RealtimeCategory.community);
      expect(
          communitySyncCategoryFor(
              frame('COMMUNITY_POST_REMOVED', 'p1')),
          RealtimeCategory.community);
      expect(
          communitySyncCategoryFor(
              frame('COMMUNITY_COMMENT_REMOVED', 'p1')),
          RealtimeCategory.community);
    });

    test('other types never trigger the community surface', () {
      expect(
          communitySyncCategoryFor(
              frame('MESSAGE_RECEIVED', 'c1')),
          isNull);
      expect(
          communitySyncCategoryFor(
              frame('TASK_STATUS_CHANGED', 't1')),
          isNull);
      expect(
          communitySyncCategoryFor(
              frame('SOMETHING_FROM_THE_FUTURE', 'x')),
          isNull);
    });

    test('envelope parsing tolerates malformed frames', () {
      expect(parseCommunityEnvelope('not json'), isNull);
      expect(parseCommunityEnvelope('{"kind":"POST_CREATED"}'),
          isNull);
      expect(
          parseCommunityEnvelope(
              '{"kind":"POST_CREATED","postId":"p1"}')!,
          (kind: 'POST_CREATED', postId: 'p1'));
    });

    test('community targets cover feed, detail and reports', () {
      final sync = RiverpodRealtimeSync((_) {});
      final targets = sync.targetsFor(RealtimeCategory.community);
      expect(targets, contains(communityFeedProvider));
      expect(targets, contains(communityPostDetailProvider));
      expect(targets, contains(communityReportsProvider));
    });
  });

  group('live resync', () {
    testWidgets('category invalidation refetches the feed surface',
        (tester) async {
      final repo = FakeCommunityRepository()
        ..pages = [
          CommunityFeedPage(items: [
            communityPost('p1', body: 'before'),
          ], hasMore: false),
        ];
      final container = await pumpCommunity(tester,
          const _FeedProbe(),
          repo: repo);
      expect(repo.feedCalls, 1);
      // What foregroundSyncProvider does on a community frame (its own
      // element, never a dependent's): invalidate the category → the
      // mapped providers refetch over REST.
      container.invalidate(communityFeedProvider);
      await tester.pumpAndSettle();
      expect(repo.feedCalls, 2);
      expect(find.text('before'), findsOneWidget);
    });

    testWidgets('duplicate topic frames converge to one resync',
        (tester) async {      final repo = FakeCommunityRepository()
        ..pages = [
          CommunityFeedPage(items: [
            communityPost('p1', body: 'stable'),
          ], hasMore: false),
        ];
      final stomp = FakeStomp();
      final container = await pumpCommunity(tester,
          const _FeedProbe(),
          repo: repo, stomp: stomp);
      await container
          .read(stompChatServiceProvider)
          .subscribeCommunity((body) {
        container.read(communityFramesProvider).add(body);
      });
      const envelope =
          '{"kind":"COMMENT_ADDED","postId":"p1","at":"2026-09-15T12:00:00Z"}';
      stomp.communityInbound(envelope);
      stomp.communityInbound(envelope);
      stomp.communityInbound(envelope);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      // Debounce collapses the burst; the feed converges once.
      expect(repo.feedCalls, 2);
      expect(find.text('stable'), findsOneWidget);
    });
  });
}

class _FeedProbe extends ConsumerWidget {
  const _FeedProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(communityFeedProvider);
    return Text(feed.posts.isEmpty ? 'empty' : feed.posts.first.body);
  }
}
