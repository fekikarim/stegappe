import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/community/domain/entities/community.dart';
import 'package:stegappe/features/community/domain/repositories/community_repository.dart';
import 'package:stegappe/features/community/presentation/providers/community_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

import '../../support/queue_harness.dart';
import '../../support/shell_harness.dart';
import '../../test_fixtures.dart';
import '../messaging/messaging_widget_test.dart' show FakeStomp;

/// Scriptable community repository: feed windows, failures, recorded
/// mutations (keys, deletes, reports, mutes, resolutions).
class FakeCommunityRepository implements CommunityRepository {
  /// Pages returned in order per feed call (extra calls repeat the last).
  List<CommunityFeedPage> pages = const [];
  var feedCalls = 0;

  bool failFeed = false;
  bool failNextCreate = false;
  bool failNextDelete = false;

  final createdKeys = <String?>[];
  final deletedPosts = <String>[];
  final deletedComments = <String>[];
  final deleteReasons = <String?>[];
  final reportedPosts = <String>[];
  final reportedComments = <String>[];
  final mutedUsers = <String>[];
  final unmutedUsers = <String>[];
  final resolvedReports = <String>[];

  Map<String, List<CommunityComment>> commentsByPost = {};
  Map<String, CommunityPost> postsById = {};
  List<CommunityReport> reportRows = const [];

  CommunityFeedPage _pageFor(int call) => pages.isEmpty
      ? const CommunityFeedPage(items: [], hasMore: false)
      : pages[call < pages.length ? call : pages.length - 1];

  @override
  Future<CommunityFeedPage> feed(
      {DateTime? cursorTs, String? cursorId, int size = 20}) async {
    final call = feedCalls;
    feedCalls++;
    if (failFeed) throw Exception('feed failed');
    return _pageFor(call);
  }

  @override
  Future<CommunityPost> post(String postId) async {
    final post = postsById[postId];
    if (post == null) {
      throw const ApiException(
          kind: ApiErrorKind.notFound, message: 'gone');
    }
    return post;
  }

  @override
  Future<CommunityPost> createPost(String body,
      {String? idempotencyKey}) async {
    if (failNextCreate) {
      failNextCreate = false;
      throw Exception('create failed');
    }
    createdKeys.add(idempotencyKey);
    return CommunityPost(
      id: 'srv-${createdKeys.length}',
      authorId: 'me',
      authorDisplayName: 'Moi M.',
      body: body,
      status: CommunityContentStatus.visible,
      commentCount: 0,
      createdAt: DateTime(2026, 9, 15, 12, 0),
      mine: true,
    );
  }

  @override
  Future<CommunityPost> createPostWithAttachment({
    required String body,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
    String? idempotencyKey,
  }) async {
    if (failNextCreate) {
      failNextCreate = false;
      throw Exception('create failed');
    }
    createdKeys.add(idempotencyKey);
    onProgress?.call(bytes.length, bytes.length);
    return CommunityPost(
      id: 'srv-${createdKeys.length}',
      authorId: 'me',
      authorDisplayName: 'Moi M.',
      body: body,
      status: CommunityContentStatus.visible,
      commentCount: 0,
      createdAt: DateTime(2026, 9, 15, 12, 0),
      attachment: CommunityAttachment(
          id: 'a1',
          fileName: fileName,
          mimeType: contentType,
          size: bytes.length),
      mine: true,
    );
  }

  @override
  Future<CommunityPost> deletePost(String postId,
      {String? reason}) async {
    if (failNextDelete) {
      failNextDelete = false;
      throw Exception('delete failed');
    }
    deletedPosts.add(postId);
    deleteReasons.add(reason);
    final post = postsById[postId];
    if (post == null) {
      throw const ApiException(
          kind: ApiErrorKind.notFound, message: 'gone');
    }
    return post;
  }

  @override
  Future<Paged<CommunityComment>> comments(String postId,
      {int page = 0, int size = 20}) async {
    final all = commentsByPost[postId] ?? const [];
    return Paged<CommunityComment>(
      items: all,
      page: page,
      totalElements: all.length,
      totalPages: 1,
      isLast: true,
    );
  }

  @override
  Future<CommunityComment> comment(String postId, String body,
      {String? idempotencyKey}) async {
    createdKeys.add(idempotencyKey);
    return CommunityComment(
      id: 'c-${createdKeys.length}',
      postId: postId,
      authorId: 'me',
      authorDisplayName: 'Moi M.',
      body: body,
      createdAt: DateTime(2026, 9, 15, 12, 5),
      mine: true,
    );
  }

  @override
  Future<void> deleteComment(String commentId,
      {String? reason}) async {
    deletedComments.add(commentId);
    deleteReasons.add(reason);
  }

  @override
  Future<void> reportPost(String postId, String reason) async {
    reportedPosts.add(postId);
  }

  @override
  Future<void> reportComment(String commentId, String reason) async {
    reportedComments.add(commentId);
  }

  @override
  Future<Uint8List> downloadAttachment(
          String attachmentId, String fileName) async =>
      Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

  @override
  Future<Paged<CommunityReport>> reports({bool openOnly = true}) async {
    final items = openOnly
        ? [
            for (final r in reportRows)
              if (r.status == CommunityReportStatus.open) r,
          ]
        : reportRows;
    return Paged<CommunityReport>(
      items: items,
      page: 0,
      totalElements: items.length,
      totalPages: 1,
      isLast: true,
    );
  }

  @override
  Future<void> resolveReport(String reportId,
      {String? resolution}) async {
    resolvedReports.add(reportId);
  }

  @override
  Future<void> muteStudent(
      {required String userId,
      required int minutes,
      required String reason}) async {
    mutedUsers.add(userId);
  }

  @override
  Future<void> unmuteStudent(String userId) async {
    unmutedUsers.add(userId);
  }
}

CommunityPost communityPost(
  String id, {
  String authorId = 'u2',
  String authorDisplayName = 'Yasmine H.',
  String body = 'body',
  int commentCount = 0,
  DateTime? at,
  bool mine = false,
  CommunityAttachment? attachment,
}) =>
    CommunityPost(
      id: id,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      body: body,
      status: CommunityContentStatus.visible,
      commentCount: commentCount,
      createdAt: at ?? DateTime(2026, 9, 15, 10, 0),
      attachment: attachment,
      mine: mine,
    );

CommunityComment communityComment(
  String id, {
  String postId = 'p1',
  String body = 'reply',
  bool mine = false,
}) =>
    CommunityComment(
      id: id,
      postId: postId,
      authorId: mine ? 'me' : 'u2',
      authorDisplayName: mine ? 'Moi M.' : 'Yasmine H.',
      body: body,
      createdAt: DateTime(2026, 9, 15, 11, 0),
      mine: mine,
    );

const _internUser =
    AppUser(id: 'me', email: 'intern@u.tn', roles: ['INTERN']);

/// Pumps a community page with role control (default intern).
Future<ProviderContainer> pumpCommunity(
  WidgetTester tester,
  Widget page, {
  FakeCommunityRepository? repo,
  FakeStomp? stomp,
  AppUser user = _internUser,
  bool online = true,
}) async {
  final s = stomp ?? FakeStomp();
  s.setState(ChatConnectionState.connected);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(HarnessAuthRepository(user)),
        internshipRepositoryProvider.overrideWithValue(
          FakeInternshipRepository(),
        ),
        communityRepositoryProvider.overrideWithValue(
          repo ?? FakeCommunityRepository(),
        ),
        stompChatServiceProvider.overrideWithValue(s),
        isOnlineProvider.overrideWith((ref) => online),
        await queueOverride(),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: StegLocales.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: page),
      ),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  final container = ProviderScope.containerOf(ctx);
  await container.read(authControllerProvider.notifier).bootstrap();
  await tester.pumpAndSettle();
  return container;
}
