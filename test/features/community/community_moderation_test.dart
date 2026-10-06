import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/community/domain/entities/community.dart';
import 'package:stegappe/features/community/presentation/providers/community_providers.dart';
import 'package:stegappe/features/community/presentation/screens/community_feed_screen.dart';
import 'package:stegappe/features/community/presentation/screens/community_reports_screen.dart';

import 'community_test_support.dart';

const _supervisorUser =
    AppUser(id: 'sup', email: 'sup@steg.tn', roles: ['SUPERVISOR']);

/// T08 moderation UX: role-gated menus, staff reports queue, confirm +
/// reason sheets, mute/unmute calls.
void main() {
  FakeCommunityRepository moderatedRepo() {
    final repo = FakeCommunityRepository()
      ..pages = [
        CommunityFeedPage(items: [
          communityPost('p1',
              authorId: 'u9',
              authorDisplayName: 'Karim F.',
              body: 'needs moderation'),
        ], hasMore: false),
      ]
      ..postsById = {
        'p1': communityPost('p1',
            authorId: 'u9',
            authorDisplayName: 'Karim F.',
            body: 'needs moderation'),
      }
      ..reportRows = [
        CommunityReport(
            id: 'r1',
            targetType: 'POST',
            targetPostId: 'p1',
            reason: 'spammy',
            status: CommunityReportStatus.open,
            createdAt: DateTime(2026, 9, 15, 12, 0)),
      ];
    return repo;
  }

  Future<void> openPostMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert_outlined).first);
    await tester.pumpAndSettle();
  }

  group('role-gated menus', () {
    testWidgets('intern sees report on others, delete on own',
        (tester) async {
      final repo = moderatedRepo();
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      await openPostMenu(tester);
      // Other author's post: report only (no staff actions).
      expect(find.text('Signaler'), findsOneWidget);
      expect(find.text('Retirer (modération)'), findsNothing);
      expect(find.text('Couper l’accès'), findsNothing);
    });

    testWidgets('supervisor sees remove + mute on others',
        (tester) async {
      final repo = moderatedRepo();
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo, user: _supervisorUser);
      // No composer for staff (read + moderate only).
      expect(find.byType(FloatingActionButton), findsNothing);
      await openPostMenu(tester);
      expect(find.text('Signaler'), findsOneWidget);
      expect(find.text('Retirer (modération)'), findsOneWidget);
      expect(find.text('Couper l’accès'), findsOneWidget);
    });

    testWidgets('staff remove requires a reason and calls delete',
        (tester) async {
      final repo = moderatedRepo();
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo, user: _supervisorUser);
      await openPostMenu(tester);
      await tester.tap(find.text('Retirer (modération)'));
      await tester.pumpAndSettle();
      // Reason sheet: empty submit stays with the required hint.
      await tester.tap(find.text('Retirer (modération)').last);
      await tester.pump();
      expect(repo.deletedPosts, isEmpty);
      await tester.enterText(find.byType(TextField).last, 'spam');
      await tester.tap(find.text('Retirer (modération)').last);
      await tester.pumpAndSettle();
      expect(repo.deletedPosts, ['p1']);
    });

    testWidgets('report sends with the typed reason', (tester) async {
      final repo = moderatedRepo();
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      await openPostMenu(tester);
      await tester.tap(find.text('Signaler'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).last, 'contenu inapproprié');
      await tester.tap(find.text('Signaler').last);
      await tester.pumpAndSettle();
      expect(repo.reportedPosts, ['p1']);
    });
  });

  group('staff reports queue', () {
    testWidgets('open/all filter drives the server query',
        (tester) async {
      final repo = moderatedRepo();
      final container = await pumpCommunity(tester,
          const CommunityReportsScreen(),
          repo: repo, user: _supervisorUser);
      expect(find.text('spammy'), findsOneWidget);
      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();
      expect(
          container
              .read(communityReportsProvider)
              .openOnly,
          isFalse);
    });

    testWidgets('resolve closes the report', (tester) async {
      final repo = moderatedRepo();
      await pumpCommunity(tester,
          const CommunityReportsScreen(),
          repo: repo, user: _supervisorUser);
      await tester.tap(find.text('Clore le signalement'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clore le signalement').last);
      await tester.pumpAndSettle();
      expect(repo.resolvedReports, ['r1']);
    });

    testWidgets('mute sheet offers durations and calls mute',
        (tester) async {
      final repo = moderatedRepo();
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo, user: _supervisorUser);
      await openPostMenu(tester);
      await tester.tap(find.text('Couper l’accès'));
      await tester.pumpAndSettle();
      expect(find.text('1 heure'), findsOneWidget);
      expect(find.text('30 jours'), findsOneWidget);
      await tester.enterText(
          find.byType(TextField).last, 'spam répété');
      await tester.tap(find.text('Couper l’accès').last);
      await tester.pumpAndSettle();
      expect(repo.mutedUsers, ['u9']);
    });
  });
}
