import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';

import '../messaging/notifications_test_support.dart';

/// T08 deep links: community rows open the post detail through
/// `onOpenCommunityPost` (no shell tab), mark read, and fail safe without a
/// post id or callback.
void main() {
  group('notification deep links — community rows', () {
    testWidgets('community row opens the post detail + marks read',
        (tester) async {
      final repo = FakeNotificationsRepositoryForCommunity();
      String? opened;
      await pumpNotifications(tester,
          repo: repo,
          onOpenCommunityPost: (postId) => opened = postId);
      await tester.tap(find.byTooltip('Ouvrir'));
      await tester.pumpAndSettle();
      expect(opened, 'p1');
      expect(repo.read, contains('n-community-1'));
    });

    testWidgets('row without a post id stays in the center',
        (tester) async {
      final repo =
          FakeNotificationsRepositoryForCommunity(entityId: null);
      var opened = false;
      await pumpNotifications(tester,
          repo: repo,
          onOpenCommunityPost: (_) => opened = true);
      // No open affordance on the row: no navigation happens.
      expect(find.byTooltip('Ouvrir'), findsNothing);
      expect(opened, isFalse);
    });
  });
}

class FakeNotificationsRepositoryForCommunity
    extends FakeNotificationsRepository {
  FakeNotificationsRepositoryForCommunity({this.entityId = 'p1'});

  final String? entityId;

  @override
  Future<Paged<NotificationItem>> list(
      {int page = 0, int size = 20, bool unreadOnly = false}) async {
    return Paged<NotificationItem>(
      items: [
        notif('n-community-1',
            type: NotificationType.communityComment,
            entity: 'CommunityPost',
            entityId: entityId),
      ],
      page: 0,
      totalElements: 1,
      totalPages: 1,
      isLast: true,
    );
  }
}
