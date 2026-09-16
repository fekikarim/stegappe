import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/paged.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/messaging_remote_data_source.dart';
import '../../data/repositories/messaging_repository_impl.dart';
import '../../data/services/stomp_chat_service.dart';
import '../../data/services/stomp_chat_service_impl.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../../domain/repositories/notification_repository.dart';

final stompChatServiceProvider = Provider<StompChatService>((ref) {
  final service = StompChatServiceImpl(
      tokens: ref.watch(tokenStorageProvider));
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
  final String? initError;

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
    String? initError,
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
  });

  final String content;
  final DateTime at;
  final String error;
}

final chatControllerProvider = StateNotifierProvider.family<
    ChatController, ChatState, String>(
  (ref, conversationId) => ChatController(
    ref.watch(messagingRepositoryProvider),
    ref.watch(stompChatServiceProvider),
    conversationId,
  )..init(),
);

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo, this._stomp, this._conversationId)
      : super(const ChatState());

  final MessagingRepository _repo;
  final StompChatService _stomp;
  final String _conversationId;

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
    try {
      await loadInitial();
      if (!_disposed) {
        state = state.copyWith(
            initialized: true, clearInitError: true);
      }
    } on Exception catch (e) {
      if (!_disposed) {
        state = state.copyWith(
            initialized: true, initError: e.toString());
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

  /// Drop pending bubbles echoed by the server (same sender+content).
  void _dropPendingEcho(ChatMessage msg) {
    if (!msg.mine) return;
    final remaining = state.pending
        .where((p) => p.content != msg.content)
        .toList();
    if (remaining.length != state.pending.length) {
      state = state.copyWith(pending: remaining);
    }
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
            initialized: true, initError: e.toString());
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

  void _ackUpTo(int? seq) {
    if (seq == null || seq <= 0) return;
    _repo.markDelivered(_conversationId, seq);
    _repo.markRead(_conversationId, seq);
  }

  Future<void> send(String raw) async {
    final content = raw.trim();
    if (content.isEmpty) return;
    final pending = PendingMessage(
      localId: 'p${DateTime.now().microsecondsSinceEpoch}_${_localSeq++}',
      content: content,
      at: DateTime.now(),
    );
    state = state.copyWith(
        pending: [...state.pending, pending]);
    try {
      final sent = await _repo.send(_conversationId, content);
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
              error: e.toString()),
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

  @override
  void dispose() {
    _disposed = true;
    _cancelSub?.call();
    _resyncSub?.cancel();
    super.dispose();
  }
}

/// Foreground notification feed: socket payloads refresh the center,
/// plus explicit refresh on resume (no push provider configured).
final notificationsProvider =
    FutureProvider<Paged<NotificationItem>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.list(size: 20);
});

final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.unreadCount();
});

/// Subscribes once per login session: notification payloads + chat
/// errors refresh the relevant providers. Called from AuthGate after
/// authentication (idempotent per session via keepAlive guard).
final foregroundSyncProvider = Provider<void>((ref) {
  // Fire-and-forget subscriptions; errors never break the session.
  Future<void> boot() async {
    final stomp = ref.read(stompChatServiceProvider);
    try {
      await stomp.ensureConnected();
      await stomp.subscribeNotifications((_) {
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationsProvider);
        ref.invalidate(totalUnreadMessagesProvider);
      });
      await stomp.subscribeErrors((_, _) {});
    } on Exception {
      // Offline at login: socket connects later on demand.
    }
  }

  boot();
});
