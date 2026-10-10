import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/offline/pending_writes.dart';
import '../../../../core/realtime/community_sync.dart';
import '../../../../core/realtime/document_sync.dart';
import '../../../../core/realtime/realtime_sync.dart';
import '../../../../core/realtime/task_sync.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/messaging_remote_data_source.dart';
import '../../data/repositories/messaging_repository_impl.dart';
import '../../data/services/stomp_chat_service.dart';
import '../../data/services/stomp_chat_service_impl.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../../domain/repositories/notification_repository.dart';

/// Notification-center state (T01): REST-authoritative rows merged with
/// deduplicated live frames, plus the last failure for honest error rendering.
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.loading = false,
    this.loaded = false,
    this.offlineCache = false,
    this.unreadOnly = false,
    this.live = false,
    this.error,
  });

  /// Newest-first (REST order; frames merge through [mergeNotificationFrame]).
  final List<NotificationItem> items;
  final int unreadCount;
  final bool loading;
  final bool loaded;

  /// True when the current rows came from the last-good snapshot while
  /// offline (degraded banner shows instead of a blank screen).
  final bool offlineCache;

  /// True while the "unread only" filter is active — the flag is sent to the
  /// server (`GET /api/notifications?unreadOnly=true`) so the filtered view
  /// covers the retained history, not only the loaded page.
  final bool unreadOnly;

  /// Socket streaming right now (drives the honest "live sync" hint).
  final bool live;

  /// Raw failure object; localized at the render edge (T00 error model).
  final Object? error;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    bool? loading,
    bool? loaded,
    bool? offlineCache,
    bool? unreadOnly,
    bool? live,
    Object? error,
    bool clearError = false,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded,
        offlineCache: offlineCache ?? this.offlineCache,
        unreadOnly: unreadOnly ?? this.unreadOnly,
        live: live ?? this.live,
        error: clearError ? null : error ?? this.error,
      );
}

/// Loads REST state, then applies live frames through the dedupe reducer.
/// Resyncs on every socket reconnect (`resyncRequested`) and never marks a
/// REST-known read row unread from a frame.
class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._repo, this._frames, this._stomp, this._sync)
      : super(const NotificationsState()) {
    _init();
  }

  final NotificationRepository _repo;
  final NotificationFrames _frames;
  final StompChatService _stomp;
  final RealtimeSync _sync;
  StreamSubscription<ChatConnectionState>? _stateSub;
  StreamSubscription<void>? _resyncSub;
  StreamSubscription<String>? _framesSub;
  var _disposed = false;

  Future<void> _init() async {
    await refresh();
    if (_disposed) return;
    // Auth-aware lifecycle: every reconnect re-subscribes (service contract)
    // and its resync signal triggers a REST refresh, so a missed frame can
    // never leave stale state.
    _stateSub = _stomp.state.listen(_onSocketState);
    _resyncSub = _stomp.resyncRequested.listen((_) => refresh());
    // Frames arrive through the session-wide sink: the STOMP service keeps ONE
    // callback per destination (`_subs[dest] = cb`) and `foregroundSyncProvider`
    // owns the notification slot for the whole session. Subscribing here would
    // steal it and leave a disposed handler installed once this screen closes.
    _framesSub = _frames.stream.listen(_onFrame);
    try {
      await _stomp.ensureConnected();
    } on Exception {
      // Offline at open: REST state is on screen; the socket connects later.
    }
  }

  void _onSocketState(ChatConnectionState s) {
    if (_disposed) return;
    final live = s == ChatConnectionState.connected;
    state = state.copyWith(
      live: live,
      // Reconnecting clears the degraded banner.
      offlineCache: live ? false : state.offlineCache,
    );
  }

  /// Applies the unread filter by re-querying the server (never by hiding rows
  /// of the loaded page: unread history older than the first page stays
  /// reachable).
  Future<void> setUnreadOnly(bool unreadOnly) async {
    if (state.unreadOnly == unreadOnly) return;
    state = state.copyWith(unreadOnly: unreadOnly, items: const []);
    await refresh();
  }

  void _onFrame(String body) {
    if (_disposed) return;
    final frame = notificationItemFromFrame(body);
    if (frame == null) return; // malformed frame: keep REST state
    // Dedupe by id + stable newest-first order; never un-read a read row.
    final merged = mergeNotificationFrame(state.items, frame);
    if (identical(merged, state.items)) return;
    state = state.copyWith(items: merged);
    // The live signal alone never computes the badge: refetch the
    // authoritative count (and list) so REST stays the source of truth.
    refreshUnread();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _repo.list(size: 20, unreadOnly: state.unreadOnly);
      final unread = await _repo.unreadCount().catchError((_) => 0);
      if (_disposed) return;
      state = state.copyWith(
        items: page.items,
        unreadCount: unread,
        loading: false,
        loaded: true,
        offlineCache: false,
      );
    } on Exception catch (e) {
      if (_disposed) return;
      // Degrade honestly: keep the last-good rows with the offline flag,
      // only error when there is nothing to show.
      if (state.items.isEmpty) {
        state = state.copyWith(loading: false, loaded: true, error: e);
      } else {
        state = state.copyWith(loading: false, loaded: true, offlineCache: true);
      }
    }
  }

  Future<void> refreshUnread() async {
    try {
      final unread = await _repo.unreadCount();
      if (!_disposed) state = state.copyWith(unreadCount: unread);
    } on Exception {
      // Badge refreshes on next successful sync; never alarms the user.
    }
  }

  Future<void> markRead(NotificationItem n) async {
    // Optimistic with rollback (in-flight protection lives in the screen).
    final wasRead = n.isRead;
    final previous = state.items;
    final unreadBefore = state.unreadCount;
    if (!wasRead) {
      state = state.copyWith(
        // Under the unread filter a read row leaves the list; the rollback
        // below restores the exact previous snapshot.
        items: [
          for (final item in state.items)
            if (item.id != n.id)
              item
            else if (!state.unreadOnly)
              item.copyWith(isRead: true),
        ],
        unreadCount: unreadBefore > 0 ? unreadBefore - 1 : 0,
      );
    }
    try {
      await _repo.markRead(n.id);
      await refreshUnread();
    } on Exception {
      if (_disposed) return;
      // Roll back the optimistic change; the server keeps the authority.
      state = state.copyWith(items: previous, unreadCount: unreadBefore);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final previous = state.items;
    final unreadBefore = state.unreadCount;
    state = state.copyWith(
      // Under the unread filter "all read" empties the view.
      items: state.unreadOnly
          ? const []
          : [for (final item in previous) item.copyWith(isRead: true)],
      unreadCount: 0,
    );
    try {
      await _repo.markAllRead();
    } on Exception {
      if (_disposed) return;
      // Roll back; the next refresh reconciles with the server anyway.
      state = state.copyWith(items: previous, unreadCount: unreadBefore);
      rethrow;
    }
  }

  /// Notification category → T00 RealtimeSync invalidation (other surfaces
  /// that show notification-derived state, e.g. the home dashboard). Called
  /// by the screen after explicit user actions so caches converge.
  void invalidateRelatedCaches() {
    _sync.invalidate(RealtimeCategory.notifications);
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _resyncSub?.cancel();
    _framesSub?.cancel();
    super.dispose();
  }
}

/// Parses a raw `/user/queue/notifications` frame tolerantly.
NotificationItem? notificationItemFromFrame(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    return notificationItemFromPayloadJson(decoded);
  } on Exception {
    return null;
  }
}

final stompChatServiceProvider = Provider<StompChatService>((ref) {
  var ws = AppConfig.wsBaseUrl;
  if (ws.isEmpty && kDebugMode) {
    ws = defaultTargetPlatform == TargetPlatform.android
        ? 'ws://10.0.2.2:8080'
        : 'ws://localhost:8080';
  }
  final service = StompChatServiceImpl(
    tokens: ref.watch(tokenStorageProvider),
    wsBaseUrl: ws.isNotEmpty ? ws : null,
  );
  ref.onDispose(() => service.disconnect());
  return service;
});

final messagingRemoteDataSourceProvider =
    Provider<MessagingRemoteDataSource>(
        (ref) => MessagingRemoteDataSource(ref.watch(apiClientProvider)));

final messagingRepositoryProvider =
    Provider<MessagingRepository>((ref) {
  return MessagingRepositoryImpl(
    remote: ref.watch(messagingRemoteDataSourceProvider),
    tokens: ref.watch(tokenStorageProvider),
    stomp: ref.watch(stompChatServiceProvider),
  );
});

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    client: ref.watch(apiClientProvider),
    tokens: ref.watch(tokenStorageProvider),
  );
});

/// Conversation list with unread counts merged in.
final conversationsProvider =
    FutureProvider<List<Conversation>>((ref) async {
  final repo = ref.watch(messagingRepositoryProvider);
  final list = await repo.conversations();
  // Attach latest-message previews (decoration; failures are local).
  final enriched = await Future.wait(list.map((c) async {
    try {
      final latest = await repo.latestMessage(c.id);
      return Conversation(
        id: c.id,
        type: c.type,
        title: c.title,
        internshipId: c.internshipId,
        members: c.members,
        lastSequenceNumber: c.lastSequenceNumber,
        unreadCount: c.unreadCount,
        lastMessage: latest,
      );
    } on Exception {
      return c;
    }
  }));
  return enriched;
});

/// Total unread messages across conversations (shell badge).
final totalUnreadMessagesProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(messagingRepositoryProvider);
  final counts = await repo.unreadCounts();
  var total = 0;
  for (final v in counts.values) {
    total += v;
  }
  return total;
});

/// Single conversation detail (authoritative title, internship link, read
/// watermarks). Powers friendly 1-to-1 titles and Messenger-style Seen
/// receipts without depending on a possibly stale list snapshot.
final conversationDetailProvider =
    FutureProvider.family<Conversation, String>((ref, conversationId) async {
  final repo = ref.watch(messagingRepositoryProvider);
  return repo.getConversation(conversationId);
});

/// Chat state per conversation: merged history (ascending), pending
/// outgoing, failed outgoing, oldest-sequence cursor, end-of-history.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.pending = const [],
    this.failed = const [],
    this.cursor,
    this.hasMore = true,
    this.loadingMore = false,
    this.initialized = false,
    this.initError,
  });

  final List<ChatMessage> messages;
  final List<PendingMessage> pending;
  final List<FailedMessage> failed;
  final int? cursor;
  final bool hasMore;
  final bool loadingMore;
  final bool initialized;

  /// The raw failure (never a `toString()`): screens localize it once with
  /// `context.userError(initError)` at the render edge (T00 error model).
  final Object? initError;

  int? get maxSequence =>
      messages.isEmpty ? null : messages.last.sequenceNumber;

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<PendingMessage>? pending,
    List<FailedMessage>? failed,
    int? cursor,
    bool? hasMore,
    bool? loadingMore,
    bool? initialized,
    Object? initError,
    bool clearInitError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        cursor: cursor ?? this.cursor,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        initialized: initialized ?? this.initialized,
        initError: clearInitError ? null : initError ?? this.initError,
      );
}

/// Optimistic outgoing bubble awaiting the broadcast echo.
class PendingMessage {
  const PendingMessage({
    required this.localId,
    required this.content,
    required this.at,
  });

  final String localId;
  final String content;
  final DateTime at;
}

class FailedMessage {
  const FailedMessage({
    required this.content,
    required this.at,
    required this.error,
    required this.key,
  });

  final String content;
  final DateTime at;

  /// Raw failure object; localized at the render edge (T00 error model).
  final Object? error;

  /// The idempotency identity of the original attempt (T07/BR-56): an
  /// explicit retry reuses it so a replay after a successful server write
  /// cannot duplicate the message.
  final String key;
}

final chatControllerProvider = StateNotifierProvider.family<
    ChatController, ChatState, String>(
  (ref, conversationId) => ChatController(
    ref.watch(messagingRepositoryProvider),
    ref.watch(stompChatServiceProvider),
    conversationId,
    ref.watch(pendingWritesProvider.notifier),
  )..init(),
);

class ChatController extends StateNotifier<ChatState> {
  ChatController(
      this._repo, this._stomp, this._conversationId, this._queue)
      : super(const ChatState());

  final MessagingRepository _repo;
  final StompChatService _stomp;
  final String _conversationId;
  final PendingWritesController _queue;

  void Function()? _cancelSub;
  StreamSubscription<void>? _resyncSub;
  var _disposed = false;
  var _localSeq = 0;

  Future<void> init() async {
    await _stomp.ensureConnected().catchError((_) {});
    if (_disposed) return;
    _cancelSub = await _stomp
        .subscribeConversation(_conversationId, _onFrame)
        .catchError((_) => () {});
    if (_disposed) return;
    _resyncSub =
        _stomp.resyncRequested.listen((_) => resync());
    // T06/D12: messages queued while the app was dead flush on open.
    await flushQueued();
    if (_disposed) return;
    try {
      await loadInitial();
      if (!_disposed) {
        state = state.copyWith(
            initialized: true, clearInitError: true);
      }
    } on Exception catch (e) {
      if (!_disposed) {
        state = state.copyWith(
            initialized: true, initError: e);
      }
    }
  }

  void _onFrame(String body) async {
    if (_disposed) return;
    final msg = await _repo.parseFrame(body);
    if (_disposed || msg == null) return;
    if (msg.conversationId != _conversationId) return;
    state = state.copyWith(
        messages: mergeMessages(state.messages, [msg]));
    _dropPendingEcho(msg);
    _ackUpTo(msg.sequenceNumber);
  }

  /// Test seam: drives the real broadcast path ([_onFrame]) with a raw
  /// frame, exactly as the socket delivers it (same parse, merge,
  /// echo-drop and ack pipeline — no shortcut).
  @visibleForTesting
  Future<void> debugFrame(String body) async {
    _onFrame(body);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  /// Drop pending bubbles echoed by the server (same sender+content).
  /// Drops only the OLDEST match: rapid identical sends ("ok", "ok") keep
  /// one bubble per echo instead of clearing every twin at the first echo.
  void _dropPendingEcho(ChatMessage msg) {
    if (!msg.mine) return;
    final index =
        state.pending.indexWhere((p) => p.content == msg.content);
    if (index < 0) return;
    state = state.copyWith(
        pending: [...state.pending]..removeAt(index));
  }

  Future<void> loadInitial() async {
    try {
      final page = await _repo.history(_conversationId, size: 30);
      if (_disposed) return;
      final ascending = page.items.reversed.toList();
      state = state.copyWith(
        messages: mergeMessages([], ascending),
        cursor: ascending.isEmpty
            ? null
            : ascending.first.sequenceNumber,
        hasMore: !page.isLast,
      );
      _ackUpTo(state.maxSequence);
    } on Exception {
      // UI renders retry via ChatScreen error handling below.
      rethrow;
    }
  }

  /// Retry the initial load after a failure (clears the error first).
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
        state = state.copyWith(
            initialized: true, initError: e);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    final cursor = state.cursor;
    if (cursor == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.history(_conversationId,
          cursor: cursor, size: 30);
      if (_disposed) return;
      final ascending = page.items.reversed.toList();
      state = state.copyWith(
        messages: mergeMessages(state.messages, ascending),
        cursor: ascending.isEmpty
            ? cursor
            : ascending.first.sequenceNumber,
        hasMore: !page.isLast && page.items.isNotEmpty,
        loadingMore: false,
      );
    } on Exception {
      if (!_disposed) state = state.copyWith(loadingMore: false);
      rethrow;
    }
  }

  /// Resync after reconnect: fetch everything newer than the local max.
  Future<void> resync() async {
    await flushQueued();
    try {
      final page = await _repo.history(_conversationId, size: 30);
      if (_disposed) return;
      state = state.copyWith(
          messages:
              mergeMessages(state.messages, page.items.reversed.toList()));
      _ackUpTo(state.maxSequence);
    } on Exception {
      // Next resync or pull-to-refresh recovers.
    }
  }

  /// T06/D12: flush this conversation's persisted queue (same keys make
  /// overlapping flushers replay instead of duplicating), merge what the
  /// server persisted, and drop exactly the delivered bubbles.
  Future<void> flushQueued() async {
    final delivered = await _queue.flushConversation(_conversationId);
    if (_disposed || delivered.isEmpty) return;
    final ids = {
      for (final d in delivered)
        if (d.localId != null) d.localId!,
    };
    state = state.copyWith(
      pending: [
        for (final p in state.pending)
          if (!ids.contains(p.localId)) p,
      ],
      messages: mergeMessages(
          state.messages, [for (final d in delivered) d.message]),
    );
    _ackUpTo(state.maxSequence);
  }

  void _ackUpTo(int? seq) {
    if (seq == null || seq <= 0) return;
    _repo.markDelivered(_conversationId, seq);
    _repo.markRead(_conversationId, seq);
  }

  /// Sends one logical message. The pending bubble's local id doubles as
  /// the idempotency key (T07/BR-56): the direct REST attempt and the
  /// offline-queue row share it, so every retry path replays instead of
  /// duplicating. An explicit retry of a failed bubble reuses [FailedMessage.key].
  Future<void> send(String raw, {String? idempotencyKey}) async {
    final content = raw.trim();
    if (content.isEmpty) return;
    if (content.length > ChatMessageRules.maxLength) {
      state = state.copyWith(
        failed: [
          ...state.failed,
          FailedMessage(
              content: content,
              at: DateTime.now(),
              // Client-side pre-check of the server contract: the render edge
              // maps MESSAGE_TOO_LONG to the precise sentence (T00 model).
              error: const ApiException(
                  kind: ApiErrorKind.validation,
                  message: 'client pre-check: message exceeds 4000 characters',
                  code: ChatMessageRules.tooLongCode),
              key: idempotencyKey ??
                  'p${DateTime.now().microsecondsSinceEpoch}_${_localSeq++}'),
        ],
      );
      return;
    }
    final pending = PendingMessage(
      localId: idempotencyKey ??
          'p${DateTime.now().microsecondsSinceEpoch}_${_localSeq++}',
      content: content,
      at: DateTime.now(),
    );
    state = state.copyWith(
        pending: [...state.pending, pending]);
    try {
      final sent = await _repo.send(_conversationId, content,
          idempotencyKey: pending.localId);
      if (_disposed) return;
      state = state.copyWith(
          pending: state.pending
              .where((p) => p.localId != pending.localId)
              .toList());
      if (sent != null) {
        // REST path returns the persisted message immediately.
        state = state.copyWith(
            messages:
                mergeMessages(state.messages, [sent.message]));
        _ackUpTo(sent.message.sequenceNumber);
      }
      // STOMP path: the broadcast echo reconciles + acks.
    } on ApiException catch (e) {
      if (_disposed) return;
      if (e.kind == ApiErrorKind.network) {
        // T06/D12 offline path: keep the bubble visibly queued in the
        // persisted store; the flush applies it exactly once on reconnect
        // under the same key (see enqueueMessage).
        await _queue.enqueueMessage(
          conversationId: _conversationId,
          content: content,
          localId: pending.localId,
          idempotencyKey: pending.localId,
        );
        return;
      }
      state = state.copyWith(
        pending: state.pending
            .where((p) => p.localId != pending.localId)
            .toList(),
        failed: [
          ...state.failed,
          FailedMessage(
              content: content,
              at: DateTime.now(),
              error: e,
              key: pending.localId),
        ],
      );
    } on Exception catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        pending: state.pending
            .where((p) => p.localId != pending.localId)
            .toList(),
        failed: [
          ...state.failed,
          FailedMessage(
              content: content,
              at: DateTime.now(),
              error: e,
              key: pending.localId),
        ],
      );
    }
  }

  void discardFailed(FailedMessage failed) {
    state = state.copyWith(
        failed: state.failed
            .where((f) =>
                f.content != failed.content ||
                f.at != failed.at)
            .toList());
  }

  /// Explicit "mark as read" (Messenger-style): advances the read watermark
  /// to the newest known message. Opening/resync already ack implicitly;
  /// this is the user-visible action + list-badge reconciler.
  Future<void> markAsReadNow() async {
    _ackUpTo(state.maxSequence);
  }

  /// Edit my own message (1-to-1 threads; the server enforces sender-only).
  /// Optimistic with rollback: the new text shows immediately and reverts
  /// with a rethrow if the server rejects it.
  Future<void> editMessage(String messageId, String raw) async {
    final content = raw.trim();
    if (content.isEmpty) return;
    if (content.length > ChatMessageRules.maxLength) {
      throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'client pre-check: message exceeds 4000 characters',
          code: ChatMessageRules.tooLongCode);
    }
    final index =
        state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final previous = state.messages[index];
    if (!previous.mine || previous.isDeleted) return;
    final optimistic = ChatMessage(
      id: previous.id,
      conversationId: previous.conversationId,
      senderId: previous.senderId,
      content: content,
      status: MessageStatus.edited,
      sequenceNumber: previous.sequenceNumber,
      sentAt: previous.sentAt,
      attachments: previous.attachments,
      mine: true,
    );
    state = state.copyWith(
      messages: [
        ...state.messages.sublist(0, index),
        optimistic,
        ...state.messages.sublist(index + 1),
      ],
    );
    try {
      final updated =
          await _repo.editMessage(messageId, content);
      if (_disposed) return;
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == messageId) updated else m,
        ],
      );
    } on Exception {
      if (_disposed) rethrow;
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == messageId) previous else m,
        ],
      );
      rethrow;
    }
  }

  /// Soft-delete my own message (content redacted, history slot kept).
  /// Optimistic with rollback, mirroring [editMessage].
  Future<void> deleteMessage(String messageId) async {
    final index =
        state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final previous = state.messages[index];
    if (!previous.mine || previous.isDeleted) return;
    final optimistic = ChatMessage(
      id: previous.id,
      conversationId: previous.conversationId,
      senderId: previous.senderId,
      content: previous.content,
      status: MessageStatus.deleted,
      sequenceNumber: previous.sequenceNumber,
      sentAt: previous.sentAt,
      attachments: previous.attachments,
      mine: true,
    );
    state = state.copyWith(
      messages: [
        ...state.messages.sublist(0, index),
        optimistic,
        ...state.messages.sublist(index + 1),
      ],
    );
    try {
      await _repo.deleteMessage(messageId);
    } on Exception {
      if (_disposed) rethrow;
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.id == messageId) previous else m,
        ],
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelSub?.call();
    _resyncSub?.cancel();
    super.dispose();
  }
}

/// Fan-out sink for raw `/user/queue/notifications` payloads.
///
/// `StompChatServiceImpl` keeps a single callback per destination
/// (`_subs[dest] = onPayload`), so exactly one session-scoped owner may hold
/// that slot: [foregroundSyncProvider] does, for the whole authenticated
/// session. Every frame it receives is pushed here and any number of in-app
/// listeners consume it (the open notification center merges frames with
/// dedupe today) without ever touching the socket — closing a screen can no
/// longer leave a stale socket handler behind.
class NotificationFrames {
  final _controller = StreamController<String>.broadcast();

  Stream<String> get stream => _controller.stream;

  void add(String body) {
    if (!_controller.isClosed) _controller.add(body);
  }

  Future<void> dispose() => _controller.close();
}

final notificationFramesProvider = Provider<NotificationFrames>((ref) {
  final frames = NotificationFrames();
  ref.onDispose(frames.dispose);
  return frames;
});

/// T01 notification center controller (typed state + live dedupe + resync).
/// Auto-disposes when the center closes; the frames subscription lives with it
/// and the badge provider below keeps the shell honest.
final notificationsControllerProvider = StateNotifierProvider.autoDispose<
    NotificationsController, NotificationsState>((ref) {
  return NotificationsController(
    ref.watch(notificationRepositoryProvider),
    ref.watch(notificationFramesProvider),
    ref.watch(stompChatServiceProvider),
    ref.watch(realtimeSyncProvider),
  );
});

/// Unread badge for the shell bell — REST-authoritative, refreshed by the
/// live frames through [notificationsControllerProvider.refreshUnread] while
/// the center is open and by resume/pull-to-refresh otherwise.
final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.unreadCount();
});

/// Compatibility provider (existing tests/screens): the REST page behind the
/// controller. Prefer [notificationsControllerProvider] for the center.
final notificationsProvider =
    FutureProvider<Paged<NotificationItem>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.list(size: 20);
});

/// Subscribes once per login session: notification payloads + chat
/// errors refresh the relevant providers. Called from AuthGate after
/// authentication (idempotent per session via keepAlive guard).
///
/// Also watches [connectivityStreamProvider]: when the device transitions from
/// **offline → online** the socket is reconnected and all providers are
/// invalidated so every screen refetches — mirrors the STOMP reconnect path
/// and closes the gap where the app shows stale data after network recovery.
final foregroundSyncProvider = Provider<void>((ref) {
  final frames = ref.read(notificationFramesProvider);

  // Connectivity-triggered resync: none → online means we just regained
  // network access. Reconnect the socket and invalidate everything.
  ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityStreamProvider,
      (prev, next) {
    final prevOnline = prev?.valueOrNull
            ?.any((r) => r != ConnectivityResult.none) ??
        true;
    final nowOnline =
        next.valueOrNull?.any((r) => r != ConnectivityResult.none) ?? true;
    if (!prevOnline && nowOnline) {
      // Came back online: reconnect socket and invalidate all stale providers.
      ref.read(stompChatServiceProvider).ensureConnected().ignore();
      ref.read(realtimeSyncProvider).invalidateAll();
      ref.read(pendingWritesProvider.notifier).flushAll().ignore();
    }
  });

  // Fire-and-forget subscriptions; errors never break the session.
  Future<void> boot() async {
    final stomp = ref.read(stompChatServiceProvider);
    try {
      await stomp.ensureConnected();
      await stomp.subscribeNotifications((body) {
        // Single session owner of the destination: hand the raw payload to the
        // in-app sink (the open center merges it with dedupe) and refresh the
        // authoritative counts the shell renders.
        frames.add(body);
        // T06 task sync (W10 option (a)): task-class frames invalidate the
        // task providers so lists converge without a manual refresh. The
        // frame is never applied as state — REST refetch wins by
        // construction, so duplicates/stale frames are harmless.
        final item = notificationItemFromFrame(body);
        final taskCategory =
            item == null ? null : taskSyncCategoryFor(item);
        if (taskCategory != null) {
          ref.read(realtimeSyncProvider).invalidate(taskCategory);
        }
        // T09 journal sync (same posture as tasks): a validated-entry
        // frame invalidates the journal + supervisor queues so both sides
        // converge without a manual refresh. No submit/reject notification
        // exists server-side; those paths stay on REST + resume + pull.
        final documentCategory =
            item == null ? null : documentSyncCategoryFor(item);
        if (documentCategory != null) {
          ref.read(realtimeSyncProvider).invalidate(documentCategory);
        }
        ref.invalidate(unreadNotificationsProvider);
        ref.invalidate(totalUnreadMessagesProvider);
        ref.invalidate(notificationsProvider);
        // T08 community sync (same posture as tasks): community-class
        // notification frames invalidate the community surface; REST
        // refetch wins, so duplicates/stale frames are harmless.
        final communityCategory =
            item == null ? null : communitySyncCategoryFor(item);
        if (communityCategory != null) {
          ref.read(realtimeSyncProvider).invalidate(communityCategory);
        }
      });
      await stomp.subscribeErrors((_, _) {});
      // T08 community topic: single session-wide owner of the slot (P15
      // rule). Frames are `{kind, postId, at}` triggers — handed to the
      // in-app sink, which the open feed/detail screens consume with a
      // trailing-edge debounce before their REST resync. A subscribe
      // failure (e.g. graduated/no access) never breaks the session:
      // the feed stays correct over REST + resume + pull-to-refresh.
      try {
        final communityFrames = ref.read(communityFramesProvider);
        await stomp.subscribeCommunity((body) {
          communityFrames.add(body);
          ref
              .read(realtimeSyncProvider)
              .invalidate(RealtimeCategory.community);
        });
      } on Exception {
        // Offline or ineligible: REST remains authoritative.
      }
      // T06 §11: flush writes queued while the app was dead or offline.
      try {
        await ref.read(pendingWritesProvider.notifier).flushAll();
      } on Exception {
        // Next resync retries; the queue persists.
      }
      // T06 §10: every reconnect resyncs REST state (a missed frame can
      // never leave stale lists) and flushes the offline queue.
      stomp.resyncRequested.listen((_) async {
        ref.read(realtimeSyncProvider).invalidateAll();
        try {
          await ref
              .read(pendingWritesProvider.notifier)
              .flushAll();
        } on Exception {
          // Next resync retries; the queue persists.
        }
      });
    } on Exception {
      // Offline at login: socket connects later on demand.
    }
  }

  boot();
});
