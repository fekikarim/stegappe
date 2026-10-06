import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/community_sync.dart';
import '../../../../core/realtime/realtime_sync.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/community_remote_data_source.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../domain/entities/community.dart';
import '../../domain/repositories/community_repository.dart';

final communityRemoteDataSourceProvider =
    Provider<CommunityRemoteDataSource>(
        (ref) => CommunityRemoteDataSource(ref.watch(apiClientProvider)));

final communityRepositoryProvider =
    Provider<CommunityRepository>((ref) {
  return CommunityRepositoryImpl(
    remote: ref.watch(communityRemoteDataSourceProvider),
    tokens: ref.watch(tokenStorageProvider),
  );
});

/// Session-wide sink for `/topic/community` envelopes lives in
/// `core/realtime/community_sync.dart` (imported above) so the session
/// owner (`foregroundSyncProvider`) can publish without importing this
/// feature file (dependency direction stays core-ward).

/// Last-good feed snapshot for the offline cold start (task-list pattern:
/// REST writes the cache, screens fall back to it with a stale banner).
final lastCommunityProvider =
    StateProvider<List<CommunityPost>?>((ref) => null);

/// Parse a `/topic/community` envelope (`{kind, postId, at}`).
/// Null when malformed — the caller keeps REST state.
({String kind, String postId})? parseCommunityEnvelope(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final kind = (decoded['kind'] ?? '').toString();
    final postId = (decoded['postId'] ?? '').toString();
    if (kind.isEmpty || postId.isEmpty) return null;
    return (kind: kind, postId: postId);
  } on Exception {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Feed
// ---------------------------------------------------------------------------

/// Feed state: merged newest-first posts, keyset cursor, end-of-feed.
class CommunityFeedState {
  const CommunityFeedState({
    this.posts = const [],
    this.failed = const [],
    this.hasMore = true,
    this.cursorTs,
    this.cursorId,
    this.loadingMore = false,
    this.initialized = false,
    this.initError,
    this.offlineCache = false,
    this.actionError,
  });

  final List<CommunityPost> posts;
  final List<FailedPost> failed;
  final bool hasMore;
  final DateTime? cursorTs;
  final String? cursorId;
  final bool loadingMore;
  final bool initialized;

  /// Raw failure (never a `toString()`): screens localize it once with
  /// `context.userError(initError)` at the render edge (T00 error model).
  final Object? initError;

  /// True when the rows are the last-good snapshot shown while offline.
  final bool offlineCache;

  /// Last non-list mutation failure (delete/report/mute/resolve):
  /// screens show it once via `ref.listen`, then clear it.
  final Object? actionError;

  CommunityFeedState copyWith({
    List<CommunityPost>? posts,
    List<FailedPost>? failed,
    bool? hasMore,
    DateTime? cursorTs,
    String? cursorId,
    bool clearCursor = false,
    bool? loadingMore,
    bool? initialized,
    Object? initError,
    bool clearInitError = false,
    bool? offlineCache,
    Object? actionError,
    bool clearActionError = false,
  }) =>
      CommunityFeedState(
        posts: posts ?? this.posts,
        failed: failed ?? this.failed,
        hasMore: hasMore ?? this.hasMore,
        cursorTs: clearCursor ? null : cursorTs ?? this.cursorTs,
        cursorId: clearCursor ? null : cursorId ?? this.cursorId,
        loadingMore: loadingMore ?? this.loadingMore,
        initialized: initialized ?? this.initialized,
        initError: clearInitError ? null : initError ?? this.initError,
        offlineCache: offlineCache ?? this.offlineCache,
        actionError: clearActionError ? null : actionError ?? this.actionError,
      );
}

/// Optimistic post awaiting the server answer (T08 UX: pending + rollback).
class PendingPost {
  const PendingPost({
    required this.localId,
    required this.body,
    required this.at,
  });

  final String localId;
  final String body;
  final DateTime at;
}

class FailedPost {
  const FailedPost({
    required this.localId,
    required this.body,
    required this.at,
    required this.error,
    this.bytes,
    this.fileName,
    this.contentType,
  });

  final String localId;
  final String body;
  final DateTime at;

  /// Raw failure object; localized at the render edge (T00 error model).
  final Object? error;

  /// Staged attachment for retry (null = text-only post).
  final Uint8List? bytes;
  final String? fileName;
  final String? contentType;
}

final communityFeedProvider = StateNotifierProvider<
    CommunityFeedController, CommunityFeedState>((ref) {
  return CommunityFeedController(
    ref.watch(communityRepositoryProvider),
    ref.watch(communityFramesProvider),
    ref.watch(realtimeSyncProvider),
    ref.watch(lastCommunityProvider.notifier),
  )..init();
});

class CommunityFeedController extends StateNotifier<CommunityFeedState> {
  CommunityFeedController(
    this._repo,
    this._frames,
    this._sync,
    this._cache,
  ) : super(const CommunityFeedState());

  final CommunityRepository _repo;
  final CommunityFrames _frames;
  final RealtimeSync _sync;
  final StateController<List<CommunityPost>?> _cache;

  StreamSubscription<String>? _framesSub;
  Timer? _debounce;
  var _disposed = false;
  var _localSeq = 0;

  Future<void> init() async {
    _framesSub = _frames.stream.listen(_onTopicFrame);
    try {
      await loadInitial();
      if (!_disposed) {
        state = state.copyWith(initialized: true, clearInitError: true);
      }
    } on Exception catch (e) {
      if (!_disposed) {
        state = state.copyWith(initialized: true, initError: e);
      }
    }
  }

  /// Topic frames are invalidation triggers (never content): collapse
  /// bursts with a trailing-edge debounce, then refetch over REST.
  /// Malformed frames keep REST state.
  void _onTopicFrame(String body) {
    if (_disposed) return;
    if (parseCommunityEnvelope(body) == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      if (!_disposed) resync();
    });
  }

  Future<void> loadInitial() async {
    try {
      final page = await _repo.feed(size: 20);
      if (_disposed) return;
      final posts = mergeCommunityPosts([], page.items);
      _cache.state = posts;
      state = state.copyWith(
        posts: posts,
        hasMore: page.hasMore,
        cursorTs: page.nextCursorTs,
        cursorId: page.nextCursorId,
        offlineCache: false,
      );
    } on Exception {
      if (_disposed) rethrow;
      // Degrade honestly: keep showing the last-good rows (if any) with
      // the stale flag; only error when there is nothing to show.
      if (state.posts.isEmpty) rethrow;
      state = state.copyWith(offlineCache: true);
    }
  }

  Future<void> retryInitial() async {
    state = state.copyWith(clearInitError: true);
    try {
      await loadInitial();
      if (!_disposed) {
        state = state.copyWith(
            initialized: true, clearInitError: true);
      }
    } on Exception catch (e) {
      if (!_disposed) {
        state = state.copyWith(initialized: true, initError: e);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.feed(
          cursorTs: state.cursorTs, cursorId: state.cursorId, size: 20);
      if (_disposed) return;
      final posts = mergeCommunityPosts(state.posts, page.items);
      _cache.state = posts;
      state = state.copyWith(
        posts: posts,
        hasMore: page.hasMore,
        cursorTs: page.nextCursorTs,
        cursorId: page.nextCursorId,
        loadingMore: false,
      );
    } on Exception {
      if (!_disposed) state = state.copyWith(loadingMore: false);
      rethrow;
    }
  }

  /// Resync after reconnect/frame/resume: replace the window with the
  /// fresh first page (preserving optimistic pendings). Replacement — not
  /// merge — is what drops moderator-removed rows from the feed; the
  /// detail screen renders the 404 as the honest "no longer available"
  /// note. Scrolling re-pages (cursor from the fresh window, dedupe by id).
  Future<void> resync() async {
    try {
      final page = await _repo.feed(size: 20);
      if (_disposed) return;
      final pendings = [for (final p in state.posts) if (p.pending) p];
      final posts = [...pendings, ...page.items];
      _cache.state = [for (final p in posts) if (!p.pending) p];
      state = state.copyWith(
        posts: posts,
        hasMore: page.hasMore,
        cursorTs: page.nextCursorTs,
        cursorId: page.nextCursorId,
        offlineCache: false,
      );
      // NOTE: no `_sync.invalidate(community)` here — that would dispose
      // this very controller (it is a community target). Sibling screens
      // (detail, reports queue) are invalidated by the session owner
      // (`foregroundSyncProvider`) on the same frame.
    } on Exception {
      // Next resync or pull-to-refresh recovers; the feed stays as-is.
    }
  }

  /// Create a post with an optimistic pending card (rollback on failure).
  /// The composer mints one idempotency key per logical post; retries reuse
  /// the failed row's key so a replay after a successful write cannot
  /// duplicate (T08/BR-56).
  Future<void> createPost(
    String raw, {
    Uint8List? bytes,
    String? fileName,
    String? contentType,
    void Function(int sent, int total)? onProgress,
    String? idempotencyKey,
  }) async {
    final body = raw.trim();
    if (body.isEmpty) return;
    final localId =
        idempotencyKey ?? 'c${DateTime.now().microsecondsSinceEpoch}_${_localSeq++}';
    final pending = CommunityPost(
      id: localId,
      authorId: '',
      authorDisplayName: '',
      body: body,
      status: CommunityContentStatus.visible,
      commentCount: 0,
      createdAt: DateTime.now(),
      mine: true,
      pending: true,
    );
    state = state.copyWith(posts: [pending, ...state.posts]);
    try {
      final CommunityPost saved;
      if (bytes != null && fileName != null && contentType != null) {
        saved = await _repo.createPostWithAttachment(
          body: body,
          fileName: fileName,
          contentType: contentType,
          bytes: bytes,
          onProgress: onProgress,
          idempotencyKey: localId,
        );
      } else {
        saved = await _repo.createPost(body, idempotencyKey: localId);
      }
      if (_disposed) return;
      state = state.copyWith(
        posts: [
          for (final p in state.posts)
            if (p.id == localId) saved else p,
        ],
      );
      _cache.state = state.posts.where((p) => !p.pending).toList();
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        posts: [for (final p in state.posts) if (p.id != localId) p],
        failed: [
          ...state.failed,
          FailedPost(
              localId: localId,
              body: body,
              at: DateTime.now(),
              error: e,
              bytes: bytes,
              fileName: fileName,
              contentType: contentType),
        ],
      );
    }
  }

  void discardFailed(FailedPost failed) {
    state = state.copyWith(
        failed: state.failed
            .where((f) => f.localId != failed.localId)
            .toList());
  }

  /// Delete (author withdraw) or remove (staff, reason mandatory on the
  /// sheet): optimistic removal with rollback. Failures surface through
  /// [CommunityFeedState.actionError] (screens show once + clear).
  Future<void> deletePost(String postId, {String? reason}) async {
    final previous = state.posts;
    state = state.copyWith(
        posts: [for (final p in previous) if (p.id != postId) p],
        clearActionError: true);
    try {
      await _repo.deletePost(postId, reason: reason);
      if (_disposed) return;
      _cache.state = state.posts.where((p) => !p.pending).toList();
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(posts: previous, actionError: e);
    }
  }

  void clearActionError() {
    state = state.copyWith(clearActionError: true);
  }

  /// Invalidate sibling caches showing community-derived state.
  void invalidateRelatedCaches() {
    _sync.invalidate(RealtimeCategory.community);
  }

  @override
  void dispose() {
    _disposed = true;
    _framesSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Post detail
// ---------------------------------------------------------------------------

class CommunityPostDetailState {
  const CommunityPostDetailState({
    this.post,
    this.comments = const [],
    this.commentsIsLast = true,
    this.loadingCommentsMore = false,
    this.initialized = false,
    this.initError,
    this.offlineCache = false,
    this.actionError,
  });

  final CommunityPost? post;
  final List<CommunityComment> comments;
  final bool commentsIsLast;
  final bool loadingCommentsMore;
  final bool initialized;
  final Object? initError;
  final bool offlineCache;
  final Object? actionError;

  CommunityPostDetailState copyWith({
    CommunityPost? post,
    List<CommunityComment>? comments,
    bool? commentsIsLast,
    bool? loadingCommentsMore,
    bool? initialized,
    Object? initError,
    bool clearInitError = false,
    bool? offlineCache,
    Object? actionError,
    bool clearActionError = false,
  }) =>
      CommunityPostDetailState(
        post: post ?? this.post,
        comments: comments ?? this.comments,
        commentsIsLast: commentsIsLast ?? this.commentsIsLast,
        loadingCommentsMore:
            loadingCommentsMore ?? this.loadingCommentsMore,
        initialized: initialized ?? this.initialized,
        initError: clearInitError ? null : initError ?? this.initError,
        offlineCache: offlineCache ?? this.offlineCache,
        actionError: clearActionError ? null : actionError ?? this.actionError,
      );
}

final communityPostDetailProvider = StateNotifierProvider.family<
    CommunityPostDetailController, CommunityPostDetailState, String>(
  (ref, postId) => CommunityPostDetailController(
    ref.watch(communityRepositoryProvider),
    ref.watch(communityFramesProvider),
    postId,
  )..init(),
);

class CommunityPostDetailController
    extends StateNotifier<CommunityPostDetailState> {
  CommunityPostDetailController(this._repo, this._frames, this._postId)
      : super(const CommunityPostDetailState());

  final CommunityRepository _repo;
  final CommunityFrames _frames;
  final String _postId;

  StreamSubscription<String>? _framesSub;
  Timer? _debounce;
  var _disposed = false;
  var _localSeq = 0;

  Future<void> init() async {
    _framesSub = _frames.stream.listen(_onTopicFrame);
    try {
      await load();
      if (!_disposed) {
        state = state.copyWith(initialized: true, clearInitError: true);
      }
    } on Exception catch (e) {
      if (!_disposed) {
        state = state.copyWith(initialized: true, initError: e);
      }
    }
  }

  void _onTopicFrame(String body) {
    if (_disposed) return;
    final envelope = parseCommunityEnvelope(body);
    if (envelope == null || envelope.postId != _postId) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      if (!_disposed) resync();
    });
  }

  Future<void> load() async {
    try {
      final post = await _repo.post(_postId);
      final comments = await _repo.comments(_postId, size: 50);
      if (_disposed) return;
      state = state.copyWith(
        post: post,
        comments: comments.items,
        commentsIsLast: comments.isLast,
        offlineCache: false,
      );
    } on Exception {
      if (_disposed) rethrow;
      // Removed while reading → the 404 stays an honest empty state
      // (the screen renders `communityRemovedGone`, never a crash).
      if (state.post == null && state.comments.isEmpty) rethrow;
      state = state.copyWith(offlineCache: true);
    }
  }

  Future<void> retryInitial() async {
    state = state.copyWith(clearInitError: true);
    try {
      await load();
      if (!_disposed) {
        state = state.copyWith(
            initialized: true, clearInitError: true);
      }
    } on Exception catch (e) {
      if (!_disposed) {
        state = state.copyWith(initialized: true, initError: e);
      }
    }
  }

  Future<void> resync() async {
    try {
      await load();
    } on Exception {
      // Next resync or pull-to-refresh recovers.
    }
  }

  /// Optimistic comment add with rollback; idempotency key per logical
  /// comment, reused on explicit retry (T08/BR-56).
  Future<void> addComment(String raw, {String? idempotencyKey}) async {
    final body = raw.trim();
    if (body.isEmpty) return;
    final localId =
        idempotencyKey ?? 'cc${DateTime.now().microsecondsSinceEpoch}_${_localSeq++}';
    final pending = CommunityComment(
      id: localId,
      postId: _postId,
      authorId: '',
      authorDisplayName: '',
      body: body,
      createdAt: DateTime.now(),
      mine: true,
      pending: true,
    );
    state = state.copyWith(comments: [...state.comments, pending]);
    try {
      final saved =
          await _repo.comment(_postId, body, idempotencyKey: localId);
      if (_disposed) return;
      state = state.copyWith(
        comments: [
          for (final c in state.comments)
            if (c.id == localId) saved else c,
        ],
        post: state.post?.copyWith(
            commentCount: state.post!.commentCount + 1),
      );
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        comments: [
          for (final c in state.comments) if (c.id != localId) c,
        ],
        actionError: e,
      );
    }
  }

  /// Delete the open post itself (author withdraw or staff remove with
  /// reason). Callers pop the screen on success; on failure the error
  /// surfaces through [CommunityPostDetailState.actionError] and rethrows
  /// so the screen stays put.
  Future<void> deletePost(String postId, {String? reason}) async {
    try {
      await _repo.deletePost(postId, reason: reason);
    } on Exception catch (e) {
      if (_disposed) rethrow;
      state = state.copyWith(actionError: e);
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId, {String? reason}) async {
    final previous = state.comments;
    state = state.copyWith(
      comments: [for (final c in previous) if (c.id != commentId) c],
      post: state.post?.copyWith(
          commentCount:
              state.post!.commentCount > 0 ? state.post!.commentCount - 1 : 0),
      clearActionError: true,
    );
    try {
      await _repo.deleteComment(commentId, reason: reason);
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        comments: previous,
        post: state.post?.copyWith(
            commentCount: state.post!.commentCount + 1),
        actionError: e,
      );
    }
  }

  void clearActionError() {
    state = state.copyWith(clearActionError: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _framesSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Staff reports queue
// ---------------------------------------------------------------------------

class CommunityReportsState {
  const CommunityReportsState({
    this.reports = const [],
    this.openOnly = true,
    this.loading = false,
    this.initialized = false,
    this.error,
    this.actionError,
  });

  final List<CommunityReport> reports;
  final bool openOnly;
  final bool loading;
  final bool initialized;
  final Object? error;
  final Object? actionError;

  CommunityReportsState copyWith({
    List<CommunityReport>? reports,
    bool? openOnly,
    bool? loading,
    bool? initialized,
    Object? error,
    bool clearError = false,
    Object? actionError,
    bool clearActionError = false,
  }) =>
      CommunityReportsState(
        reports: reports ?? this.reports,
        openOnly: openOnly ?? this.openOnly,
        loading: loading ?? this.loading,
        initialized: initialized ?? this.initialized,
        error: clearError ? null : error ?? this.error,
        actionError: clearActionError ? null : actionError ?? this.actionError,
      );
}

final communityReportsProvider = StateNotifierProvider<
    CommunityReportsController, CommunityReportsState>((ref) {
  return CommunityReportsController(ref.watch(communityRepositoryProvider))
    ..init();
});

class CommunityReportsController
    extends StateNotifier<CommunityReportsState> {
  CommunityReportsController(this._repo)
      : super(const CommunityReportsState());

  final CommunityRepository _repo;
  var _disposed = false;

  Future<void> init() async {
    await refresh();
    if (!_disposed) state = state.copyWith(initialized: true);
  }

  Future<void> setOpenOnly(bool openOnly) async {
    if (state.openOnly == openOnly) return;
    state = state.copyWith(openOnly: openOnly, reports: const []);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _repo.reports(openOnly: state.openOnly);
      if (_disposed) return;
      state = state.copyWith(
          reports: page.items, loading: false, initialized: true);
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(
          loading: false, initialized: true, error: e);
    }
  }

  Future<void> resolve(String reportId, {String? resolution}) async {
    try {
      await _repo.resolveReport(reportId, resolution: resolution);
      if (_disposed) return;
      state = state.copyWith(
        reports: [
          for (final r in state.reports)
            if (r.id != reportId)
              r
            else if (!state.openOnly)
              CommunityReport(
                  id: r.id,
                  targetType: r.targetType,
                  targetPostId: r.targetPostId,
                  targetCommentId: r.targetCommentId,
                  reason: r.reason,
                  status: CommunityReportStatus.resolved,
                  createdAt: r.createdAt),
        ],
      );
      if (state.openOnly) {
        state = state.copyWith(
            reports: state.reports
                .where((r) => r.id != reportId)
                .toList());
      }
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(actionError: e);
    }
  }

  Future<void> mute(
      {required String userId,
      required int minutes,
      required String reason}) async {
    try {
      await _repo.muteStudent(
          userId: userId, minutes: minutes, reason: reason);
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(actionError: e);
      rethrow;
    }
  }

  /// Remove from the queue: delete the content (reason mandatory,
  /// server-enforced), resolve every open report on it, then refetch the
  /// queue from the server. Errors surface through actionError + rethrow
  /// so sheets stay open on failure.
  Future<void> removePostFromQueue(String postId,
      {required String reason}) async {
    try {
      await _repo.deletePost(postId, reason: reason);
      await _resolveReportsOnPost(postId);
      await refresh();
    } on Exception catch (e) {
      if (_disposed) rethrow;
      state = state.copyWith(actionError: e);
      rethrow;
    }
  }

  Future<void> removeCommentFromQueue(String commentId,
      {required String reason}) async {
    try {
      await _repo.deleteComment(commentId, reason: reason);
      await _resolveReportsOnComment(commentId);
      await refresh();
    } on Exception catch (e) {
      if (_disposed) rethrow;
      state = state.copyWith(actionError: e);
      rethrow;
    }
  }

  Future<void> _resolveReportsOnPost(String postId) async {
    for (final r in state.reports) {
      if (r.targetPostId == postId &&
          r.status == CommunityReportStatus.open) {
        try {
          await _repo.resolveReport(r.id,
              resolution: 'content removed');
        } on Exception {
          // Keep going: refresh() below converges the queue; the open
          // report simply stays open for another pass.
        }
      }
    }
  }

  Future<void> _resolveReportsOnComment(String commentId) async {
    for (final r in state.reports) {
      if (r.targetCommentId == commentId &&
          r.status == CommunityReportStatus.open) {
        try {
          await _repo.resolveReport(r.id,
              resolution: 'content removed');
        } on Exception {
          // Keep going (see above).
        }
      }
    }
  }

  Future<void> unmute(String userId) async {
    try {
      await _repo.unmuteStudent(userId);
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(actionError: e);
      rethrow;
    }
  }

  void clearActionError() {
    state = state.copyWith(clearActionError: true);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Shell helpers
// ---------------------------------------------------------------------------

/// Whether the role may publish (students) or moderate (staff).
/// Server-enforced in every case — the UI only decides which affordances
/// to show, never what is allowed.
bool communityCanWrite(UserRole role) => role == UserRole.intern;

bool communityCanModerate(UserRole role) =>
    role == UserRole.supervisor || role == UserRole.adminSupervisor;
