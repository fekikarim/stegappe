import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/settings_providers.dart';
import '../network/api_exception.dart';
import '../realtime/realtime_sync.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/internship/domain/entities/work_items.dart';
import '../../features/internship/domain/repositories/internship_repository.dart';
import '../../features/internship/presentation/providers/workspace_providers.dart';
import '../../features/messaging/domain/entities/conversation.dart';
import '../../features/messaging/domain/repositories/messaging_repository.dart';
import '../../features/messaging/presentation/providers/messaging_providers.dart';
import 'pending_write_store.dart';

/// T06/D12 offline write queue state: the persisted items plus flush
/// progress. Screens render the count/pending markers from here; the
/// backend answer always wins on conflict (BR-56).
class PendingWritesState {
  const PendingWritesState({
    this.items = const [],
    this.flushing = false,
    this.error,
    this.authDiscarded = false,
  });

  final List<PendingWrite> items;
  final bool flushing;

  /// Raw failure of the last flush attempt (localized at the render edge).
  final Object? error;

  /// True after a 401 flush wiped the queue and signed out (login shows
  /// the explicit notice; cleared on next enqueue).
  final bool authDiscarded;

  int get count => items.length;

  bool hasQueuedStatus(String taskId) =>
      items.any((w) =>
          w.kind == PendingWriteKind.taskStatus && w.taskId == taskId);

  bool hasQueuedMessages(String conversationId) =>
      items.any((w) =>
          w.kind == PendingWriteKind.message &&
          w.conversationId == conversationId);

  PendingWritesState copyWith({
    List<PendingWrite>? items,
    bool? flushing,
    Object? error,
    bool clearError = false,
    bool? authDiscarded,
  }) =>
      PendingWritesState(
        items: items ?? this.items,
        flushing: flushing ?? this.flushing,
        error: clearError ? null : error ?? this.error,
        authDiscarded: authDiscarded ?? this.authDiscarded,
      );
}

/// Session pending-write queue (T06 §10–§12, D12).
///
/// Persisted across restarts, wiped on logout, flushed in insertion order.
/// Overlapping flushers are harmless: every write carries its own
/// idempotency key, so a repeated flush replays instead of duplicating.
class PendingWritesController
    extends StateNotifier<PendingWritesState> {
  PendingWritesController(
    this._ref,
    this._store,
    this._internships,
    this._messaging,
    this._sync,
  ) : super(const PendingWritesState()) {
    state = state.copyWith(items: _store.load());
  }

  final Ref _ref;
  final PendingWriteStore _store;
  final InternshipRepository _internships;
  final MessagingRepository _messaging;
  final RealtimeSync _sync;

  var _disposed = false;
  var _seq = 0;

  String _newKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'q${now}_${_seq++}';
  }

  /// Queue a task-status change. False when the bound refuses the push
  /// (caller shows `queueFull` instead of silently dropping).
  Future<bool> enqueueStatus({
    required String taskId,
    required TaskStatus status,
  }) async {
    final api = taskStatusToApi(status);
    if (api == null) return false;
    // One pending write per task: a newer intent replaces the older one
    // (the server answer is authoritative; intermediate states collapse).
    final rest = [
      for (final w in state.items)
        if (!(w.kind == PendingWriteKind.taskStatus &&
            w.taskId == taskId))
          w,
    ];
    final write = PendingWrite(
      key: _newKey(),
      kind: PendingWriteKind.taskStatus,
      taskId: taskId,
      targetStatus: api,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (rest.length >= PendingWriteStore.maxItems) return false;
    await _store.save([...rest, write]);
    if (_disposed) return true;
    // Re-read the store (never append locally): see enqueueMessage.
    state = state.copyWith(
        items: _store.load(), authDiscarded: false);
    return true;
  }

  /// Queue a chat message. The [localId] links the store row to the
  /// on-screen pending bubble so the flush can drop exactly that bubble.
  Future<bool> enqueueMessage({
    required String conversationId,
    required String content,
    required String localId,
  }) async {
    if (content.trim().isEmpty) return false;
    final write = PendingWrite(
      key: _newKey(),
      kind: PendingWriteKind.message,
      conversationId: conversationId,
      content: content,
      localId: localId,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final ok = await _store.push(write);
    if (!ok || _disposed) return ok;
    // Re-read the store (never append locally): a concurrent flush may
    // have removed rows in between, and a blind reload there must never
    // resurrect this write as a twin — see flushConversation/flushTaskStatuses.
    state = state.copyWith(
        items: _store.load(), authDiscarded: false);
    return true;
  }

  /// Flush every queued task-status write in order. Stops at the first
  /// retryable failure; 404/422 answers discard that row (the server
  /// resolved the conflict); 401 signs out and discards everything.
  Future<void> flushTaskStatuses() async {
    if (state.flushing) return;
    final pending = [
      for (final w in state.items)
        if (w.kind == PendingWriteKind.taskStatus) w,
    ];
    if (pending.isEmpty) return;
    state = state.copyWith(flushing: true, clearError: true);
    var removed = false;
    try {
      for (final write in pending) {
        if (_disposed) return;
        final status = taskStatusFrom(write.targetStatus);
        if (status == TaskStatus.unknown || write.taskId == null) {
          await _store.remove(write.key);
          removed = true;
          continue;
        }
        try {
          await _internships.updateTaskStatus(
            write.taskId!,
            status,
            idempotencyKey: write.key,
          );
          await _store.remove(write.key);
          removed = true;
        } on Exception catch (e) {
          if (e is ApiException && _isAuth(e)) {
            await _discardOnAuthFailure();
            return;
          }
          if (e is ApiException &&
              (e.kind == ApiErrorKind.notFound ||
                  e.kind == ApiErrorKind.validation ||
                  e.kind == ApiErrorKind.badRequest ||
                  e.kind == ApiErrorKind.forbidden)) {
            // Gone, invalid or no longer allowed: the server answered.
            await _store.remove(write.key);
            removed = true;
            continue;
          }
          // Network and unexpected failures stay queued (bounded attempts).
          await _bump(write);
          break;
        }
      }
      if (!_disposed) {
        // Reload only when this flush removed something: a blind reload
        // would resurrect a row a concurrent enqueue just saved (same
        // store, twin state rows). Skipping also avoids rebuild storms.
        if (removed) {
          state = state.copyWith(items: _store.load());
          _sync.invalidate(RealtimeCategory.tasks);
        }
      }
    } finally {
      if (!_disposed) state = state.copyWith(flushing: false);
    }
  }

  /// Flush one conversation's queued messages via REST with their keys.
  /// Returns the persisted messages (in send order) for the caller to
  /// merge; failures stay queued for the next flush.
  Future<List<DeliveredQueuedMessage>> flushConversation(
      String conversationId) async {
    final pending = [
      for (final w in state.items)
        if (w.kind == PendingWriteKind.message &&
            w.conversationId == conversationId)
          w,
    ];
    final delivered = <DeliveredQueuedMessage>[];
    var removed = false;
    for (final write in pending) {
      if (_disposed) return delivered;
      try {
        final sent = await _messaging.sendRest(
          conversationId,
          write.content ?? '',
          idempotencyKey: write.key,
        );
        await _store.remove(write.key);
        removed = true;
        delivered.add(DeliveredQueuedMessage(
            localId: write.localId, message: sent));
      } on Exception catch (e) {
        if (e is ApiException && _isAuth(e)) {
          await _discardOnAuthFailure();
          return delivered;
        }
        if (e is ApiException &&
            (e.kind == ApiErrorKind.notFound ||
                e.kind == ApiErrorKind.validation ||
                e.kind == ApiErrorKind.badRequest ||
                e.kind == ApiErrorKind.forbidden)) {
          await _store.remove(write.key);
          removed = true;
          continue;
        }
        await _bump(write);
        break;
      }
    }
    if (!_disposed) {
      // Reload only when this flush removed something (same race rule as
      // enqueue: never resurrect a concurrently saved row as a twin).
      if (removed) {
        state = state.copyWith(items: _store.load());
        _sync.invalidate(RealtimeCategory.messages);
      } else if (delivered.isNotEmpty) {
        _sync.invalidate(RealtimeCategory.messages);
      }
    }
    return delivered;
  }

  /// Flush everything (reconnect path): statuses first, then every
  /// conversation with queued messages. Returns delivered messages grouped
  /// for open chats to merge (keyed by conversation).
  Future<Map<String, List<DeliveredQueuedMessage>>>
      flushAll() async {
    await flushTaskStatuses();
    final out = <String, List<DeliveredQueuedMessage>>{};
    final convIds = {
      for (final w in state.items)
        if (w.kind == PendingWriteKind.message &&
            w.conversationId != null)
          w.conversationId!,
    };
    for (final id in convIds) {
      final delivered = await flushConversation(id);
      if (delivered.isNotEmpty) out[id] = delivered;
    }
    return out;
  }

  /// Wipe the queue (logout path). Silent: leaving is not an error.
  Future<void> clear() async {
    await _store.clear();
    if (!_disposed) {
      state = state.copyWith(items: const [], clearError: true);
    }
  }

  Future<void> _bump(PendingWrite write) async {
    final next = write.attempts + 1;
    if (next >= 10) {
      // Bounded attempts: hard failure discards the row (never an
      // invisible infinite retry). The count drop is visible in the UI.
      await _store.remove(write.key);
      return;
    }
    await _store.replace(write.withAttempts(next));
  }

  bool _isAuth(ApiException e) =>
      e.kind == ApiErrorKind.unauthorized ||
      e.statusCode == 401;

  Future<void> _discardOnAuthFailure() async {
    await _store.clear();
    if (_disposed) return;
    state = state.copyWith(items: const [], authDiscarded: true);
    _ref.read(authControllerProvider.notifier).signOutExpired();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A queued message the flush persisted: the caller merges [message] and
/// drops the bubble with [localId].
class DeliveredQueuedMessage {
  const DeliveredQueuedMessage({required this.localId, required this.message});

  final String? localId;
  final ChatMessage message;
}

final pendingWritesProvider = StateNotifierProvider<PendingWritesController,
    PendingWritesState>((ref) {
  return PendingWritesController(
    ref,
    PendingWriteStore(ref.watch(prefsStoreProvider)),
    ref.watch(internshipRepositoryProvider),
    ref.watch(messagingRepositoryProvider),
    ref.watch(realtimeSyncProvider),
  );
});
