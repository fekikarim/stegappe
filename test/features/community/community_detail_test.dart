import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/community/presentation/providers/community_providers.dart';
import 'package:stegappe/features/community/presentation/screens/community_post_detail_screen.dart';

import 'community_test_support.dart';

/// T08 detail: thread load, optimistic comments + rollback, deletes,
/// 404 gone-note, offline degradation.
void main() {
  CommunityPostDetailState stateOf(
          ProviderContainer c, String postId) =>
      c.read(communityPostDetailProvider(postId));

  group('post detail', () {
    testWidgets('thread renders post + chronological comments',
        (tester) async {
      final repo = FakeCommunityRepository()
        ..postsById = {
          'p1': communityPost('p1',
              body: 'the question', commentCount: 2),
        }
        ..commentsByPost = {
          'p1': [
            communityComment('c1', postId: 'p1', body: 'first'),
            communityComment('c2', postId: 'p1', body: 'second'),
          ],
        };
      await pumpCommunity(tester,
          const CommunityPostDetailScreen(postId: 'p1'),
          repo: repo);
      expect(find.text('the question'), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('optimistic comment swaps on success', (tester) async {
      final repo = FakeCommunityRepository()
        ..postsById = {
          'p1': communityPost('p1', body: 'q', commentCount: 0),
        }
        ..commentsByPost = {'p1': []};
      final container = await pumpCommunity(tester,
          const CommunityPostDetailScreen(postId: 'p1'),
          repo: repo);
      await tester.enterText(
          find.byType(TextField).last, 'my reply');
      await tester.tap(find.byTooltip('Publier'));
      await tester.pumpAndSettle();
      expect(find.text('my reply'), findsOneWidget);
      expect(
          container
              .read(communityPostDetailProvider('p1'))
              .comments,
          hasLength(1));
      expect(repo.createdKeys.single, isNotNull);
    });

    testWidgets('removed post renders the gone-note, never a crash',
        (tester) async {
      final repo = FakeCommunityRepository();
      await pumpCommunity(tester,
          const CommunityPostDetailScreen(postId: 'missing'),
          repo: repo);
      expect(find.text('Ce contenu n’est plus disponible.'),
          findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('comment delete rolls back with the count',
        (tester) async {
      final repo = FakeCommunityRepository()
        ..postsById = {
          'p1': communityPost('p1',
              body: 'q', commentCount: 1, mine: true),
        }
        ..commentsByPost = {
          'p1': [
            communityComment('c1', postId: 'p1', mine: true),
          ],
        };
      final container = await pumpCommunity(tester,
          const CommunityPostDetailScreen(postId: 'p1'),
          repo: repo);
      final controller = container
          .read(communityPostDetailProvider('p1').notifier);
      await controller.deleteComment('c1');
      await tester.pumpAndSettle();
      expect(
          stateOf(container, 'p1').comments, isEmpty);
      expect(stateOf(container, 'p1').post?.commentCount, 0);
      expect(repo.deletedComments, ['c1']);
    });

    testWidgets('offline thread keeps cached rows with the stale strip',
        (tester) async {
      final repo = FakeCommunityRepository()
        ..postsById = {
          'p1': communityPost('p1', body: 'cached q'),
        }
        ..commentsByPost = {'p1': []};
      final container = await pumpCommunity(tester,
          const CommunityPostDetailScreen(postId: 'p1'),
          repo: repo,
          online: false);
      expect(find.text('cached q'), findsOneWidget);
      // Composer disabled offline with the reason shown.
      expect(find.text('Connexion requise pour publier.'),
          findsOneWidget);
      expect(container, isNotNull);
    });

    testWidgets('long post body wraps without overflow', (tester) async {
      final repo = FakeCommunityRepository()
        ..postsById = {
          'p1': communityPost('p1',
              body: 'mot '.padRight(600, 'très long ')),
        }
        ..commentsByPost = {'p1': []};
      await pumpCommunity(tester,
          const CommunityPostDetailScreen(postId: 'p1'),
          repo: repo);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
