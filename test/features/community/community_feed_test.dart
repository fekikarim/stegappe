import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/network/error_messages.dart';
import 'package:stegappe/features/community/domain/entities/community.dart';
import 'package:stegappe/features/community/presentation/providers/community_providers.dart';
import 'package:stegappe/features/community/presentation/screens/community_feed_screen.dart';

import 'package:stegappe/core/realtime/community_sync.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

import 'community_test_support.dart';
import '../messaging/messaging_widget_test.dart' show FakeStomp;

/// T08 feed: contract rules, loading/empty/error/offline, pagination,
/// optimistic create + retry identity, delete rollback, realtime resync.
void main() {
  group('content contract (server `@NotBlank @Size`)', () {
    test('rules mirror the backend limits', () {
      expect(CommunityContentRules.maxPostLength, 2000);
      expect(CommunityContentRules.maxCommentLength, 1000);
      expect(CommunityContentRules.maxReasonLength, 500);
      expect(CommunityContentRules.isPostable(''), isFalse);
      expect(CommunityContentRules.isPostable('  '), isFalse);
      expect(CommunityContentRules.isPostable('question'), isTrue);
    });

    test('server guard codes map to precise sentences (fr/en/ar)', () {
      const fr = AppLocalizations(Locale('fr'));
      const en = AppLocalizations(Locale('en'));
      const ar = AppLocalizations(Locale('ar'));
      ApiException code(String c) => ApiException(
          kind: ApiErrorKind.validation,
          message: 'raw backend text',
          statusCode: 422,
          code: c);
      expect(userErrorOf(code('CONTACT_DATA_NOT_ALLOWED'), fr).message,
          fr.errCommunityContactData);
      expect(userErrorOf(code('DUPLICATE_POST'), en).message,
          en.errCommunityDuplicate);
      expect(userErrorOf(code('STUDENT_MUTED'), ar).message,
          ar.errCommunityMuted);
      expect(userErrorOf(code('REPORT_ALREADY_OPEN'), fr).message,
          fr.errCommunityReportOpen);
      expect(userErrorOf(code('POST_TOO_LONG'), fr).message,
          fr.errCommunityTooLong);
      expect(userErrorOf(code('COMMENT_TOO_LONG'), fr).message,
          fr.errCommunityTooLong);
    });

    test('merge dedupes by id, newest-first by (createdAt, id)', () {
      final a = communityPost('a', at: DateTime(2026, 9, 15, 10, 0));
      final b = communityPost('b', at: DateTime(2026, 9, 15, 11, 0));
      final merged = mergeCommunityPosts([a], [b, a]);
      expect([for (final p in merged) p.id], ['b', 'a']);
      final sameTime = DateTime(2026, 9, 15, 10, 0);
      final x = communityPost('x', at: sameTime);
      final y = communityPost('y', at: sameTime);
      final tied = mergeCommunityPosts([x], [y]);
      expect([for (final p in tied) p.id], ['y', 'x']);
    });
  });

  group('feed controller', () {
    testWidgets('loading then rows newest-first', (tester) async {
      final repo = FakeCommunityRepository()
        ..pages = [
          CommunityFeedPage(items: [
            communityPost('p2',
                body: 'second',
                at: DateTime(2026, 9, 15, 11, 0)),
            communityPost('p1',
                body: 'first',
                at: DateTime(2026, 9, 15, 10, 0)),
          ], hasMore: false),
        ];
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('Yasmine H.'), findsNWidgets(2));
    });

    testWidgets('empty state explains and offers the composer',
        (tester) async {
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: FakeCommunityRepository());
      expect(find.text('Aucune publication pour le moment.'),
          findsOneWidget);
      expect(find.text('Publier'), findsOneWidget);
    });

    testWidgets('error state retries', (tester) async {
      final repo = FakeCommunityRepository()..failFeed = true;
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      expect(
          find.text(
              'Une erreur est survenue. Réessayez.'),
          findsOneWidget);
      // Retry button present.
      expect(find.byType(ElevatedButton), findsOneWidget);
      repo.failFeed = false;
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      // Recovered into the empty state (feed loads, no rows).
      expect(find.text('Aucune publication pour le moment.'),
          findsOneWidget);
    });

    testWidgets('offline cold start keeps the last snapshot honest',
        (tester) async {
      final repo = FakeCommunityRepository()
        ..pages = [
          CommunityFeedPage(items: [
            communityPost('p1', body: 'cached post'),
          ], hasMore: false),
        ];
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      expect(find.text('cached post'), findsOneWidget);
      // Now offline with an empty-handed reload: stale rows stay.
      repo
        ..pages = const []
        ..failFeed = true;
      final ctx = tester.element(find.byType(CommunityFeedScreen));
      await ProviderScope.containerOf(ctx)
          .read(communityFeedProvider.notifier)
          .loadInitial();
      await tester.pumpAndSettle();
      expect(find.text('cached post'), findsOneWidget);
    });

    testWidgets('pagination appends without duplicates', (tester) async {
      final repo = FakeCommunityRepository()
        ..pages = [
          CommunityFeedPage(
              items: [communityPost('p2', body: 'page one')],
              hasMore: true,
              nextCursorTs: DateTime(2026, 9, 15, 10, 0),
              nextCursorId: 'p2'),
          CommunityFeedPage(
              items: [
                communityPost('p2', body: 'page one'),
                communityPost('p1', body: 'page two')
              ],
              hasMore: false),
        ];
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      final ctx = tester.element(find.byType(CommunityFeedScreen));
      await ProviderScope.containerOf(ctx)
          .read(communityFeedProvider.notifier)
          .loadMore();
      await tester.pumpAndSettle();
      expect(find.text('page one'), findsOneWidget);
      expect(find.text('page two'), findsOneWidget);
      expect(repo.feedCalls, 2);
    });

    testWidgets('optimistic create swaps the pending card on success',
        (tester) async {
      final repo = FakeCommunityRepository();
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      final ctx = tester.element(find.byType(CommunityFeedScreen));
      final controller = ProviderScope.containerOf(ctx)
          .read(communityFeedProvider.notifier);
      await controller.createPost('hello feed');
      await tester.pumpAndSettle();
      expect(find.text('hello feed'), findsOneWidget);
      expect(repo.createdKeys, hasLength(1));
      expect(repo.createdKeys.single, isNotNull);
    });

    testWidgets('failed create becomes a retryable card reusing the key',
        (tester) async {
      final repo = FakeCommunityRepository()..failNextCreate = true;
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      final ctx = tester.element(find.byType(CommunityFeedScreen));
      final controller = ProviderScope.containerOf(ctx)
          .read(communityFeedProvider.notifier);
      await controller.createPost('unlucky post');
      await tester.pumpAndSettle();
      // Failed card offers retry (reopens the composer prefilled).
      expect(find.text('unlucky post'), findsOneWidget);
      expect(
          ProviderScope.containerOf(ctx)
              .read(communityFeedProvider)
              .failed,
          hasLength(1));
      final key = ProviderScope.containerOf(ctx)
          .read(communityFeedProvider)
          .failed
          .single
          .localId;
      await controller.createPost('unlucky post',
          idempotencyKey: key);
      await tester.pumpAndSettle();
      expect(repo.createdKeys.last, key);
    });

    testWidgets('delete rolls back on failure', (tester) async {
      final repo = FakeCommunityRepository()
        ..pages = [
          CommunityFeedPage(items: [
            communityPost('p1', body: 'doomed', mine: true),
          ], hasMore: false),
        ]
        ..postsById = {
          'p1': communityPost('p1', body: 'doomed', mine: true),
        }
        ..failNextDelete = true;
      await pumpCommunity(tester, const CommunityFeedScreen(),
          repo: repo);
      expect(find.text('doomed'), findsOneWidget);
      final ctx = tester.element(find.byType(CommunityFeedScreen));
      await ProviderScope.containerOf(ctx)
          .read(communityFeedProvider.notifier)
          .deletePost('p1');
      await tester.pumpAndSettle();
      // Rolled back + error announced once.
      expect(find.text('doomed'), findsOneWidget);
      expect(
          ProviderScope.containerOf(ctx)
              .read(communityFeedProvider)
              .posts,
          hasLength(1));
    });

    testWidgets('topic frame resyncs; malformed frames are ignored',
        (tester) async {
      final repo = FakeCommunityRepository()
        ..pages = [
          CommunityFeedPage(
              items: [communityPost('p1', body: 'v1')],
              hasMore: false),
        ];
      final stomp = FakeStomp();
      final container = await pumpCommunity(
          tester, const CommunityFeedScreen(),
          repo: repo, stomp: stomp);
      expect(repo.feedCalls, 1);
      // Mirror the session socket-slot ownership (foregroundSyncProvider):
      // topic frames land in the in-app sink, controllers resync from it.
      await container
          .read(stompChatServiceProvider)
          .subscribeCommunity((body) {
        container.read(communityFramesProvider).add(body);
      });
      stomp.communityInbound('not json{{{');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.feedCalls, 1);
      repo.pages = [
        CommunityFeedPage(
            items: [communityPost('p2', body: 'v2')], hasMore: false),
      ];
      stomp.communityInbound(
          '{"kind":"POST_CREATED","postId":"p2","at":"2026-09-15T12:00:00Z"}');
      await tester.pump(const Duration(seconds: 2));
      expect(repo.feedCalls, greaterThanOrEqualTo(2));
      expect(find.text('v2'), findsOneWidget);
      expect(find.text('v1'), findsNothing);
    });
  });
}
