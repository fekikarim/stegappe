import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/settings_providers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/cache/assistant_history_store.dart';
import '../../domain/entities/assistant.dart';
import 'workspace_providers.dart';

/// Session-scoped assistant conversation (T11).
///
/// The participant path has no server history, so rows live in the local
/// [AssistantHistoryStore] (per user, wiped on logout) and in memory here
/// so the conversation survives navigation. Keep-alive by design: the
/// shell gate invalidates this provider on logout. Every send is
/// server-confirmed — a failed answer renders as a failed row with retry,
/// never as a fabricated answer.
class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.pending = false,
    this.error,
  });

  final List<AssistantMessage> messages;
  final bool pending;

  /// Raw failure of the last attempt (transient, never persisted);
  /// screens localize it at the edge via `context.userError`.
  final Object? error;

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? pending,
    Object? error = _unset,
  }) =>
      AssistantState(
        messages: messages ?? this.messages,
        pending: pending ?? this.pending,
        error: error == _unset ? this.error : error,
      );

  static const _unset = Object();
}

final assistantHistoryStoreProvider = Provider<AssistantHistoryStore>(
    (ref) => PrefsAssistantHistoryStore(ref.watch(prefsStoreProvider)));

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>(
        (ref) => AssistantController(ref),
        // Survives navigation within the session; the shell gate resets it
        // on logout so no row leaks into the next session.
        );

class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(this._ref) : super(const AssistantState());

  final Ref _ref;
  bool _restoredFor = false;
  String? _userId;

  String? get _currentUserId {
    final auth = _ref.read(authControllerProvider);
    if (auth is AuthAuthenticated) return auth.user.id;
    return null;
  }

  /// Loads the persisted conversation for the current user (idempotent per
  /// user; the screen calls it on open).
  Future<void> restore() async {
    final id = _currentUserId;
    if (id == null) return;
    if (_restoredFor && _userId == id) return;
    _userId = id;
    _restoredFor = true;
    try {
      final rows =
          await _ref.read(assistantHistoryStoreProvider).load(id);
      state = state.copyWith(messages: rows, error: null);
    } on Exception {
      // A corrupt local history never breaks the screen; start empty.
      state = state.copyWith(messages: const [], error: null);
    }
  }

  Future<void> _persist() async {
    final id = _userId ?? _currentUserId;
    if (id == null) return;
    try {
      await _ref.read(assistantHistoryStoreProvider).save(id, state.messages);
    } on Exception {
      // Local persistence is best-effort; the server answer already arrived.
    }
  }

  /// Sends one question. Guarded against empty text and double-submit;
  /// AI is never queued — offline fails honestly with the connectivity
  /// sentence instead of pretending a response is coming. Returns true
  /// when the question was dispatched (the caller may clear its field).
  Future<bool> send(String raw) async {
    final question = raw.trim();
    if (question.isEmpty || state.pending) return false;
    if (!_ref.read(isOnlineProvider)) {
      state = state.copyWith(error: ApiException.network());
      return false;
    }
    final id = _userId ?? _currentUserId;
    if (id == null) return false;
    _userId = id;
    state = state.copyWith(
      messages: [
        ...state.messages,
        AssistantMessage(mine: true, text: question),
      ],
      pending: true,
      error: null,
    );
    await _persist();
    try {
      final answer =
          await _ref.read(internshipRepositoryProvider).askAssistant(question);
      state = state.copyWith(
        messages: [
          ...state.messages,
          AssistantMessage(mine: false, text: answer),
        ],
        pending: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          const AssistantMessage(mine: false, text: '', failed: true),
        ],
        pending: false,
        error: e,
      );
    }
    await _persist();
    return true;
  }

  /// Re-sends the question behind a failed answer row, replacing the row
  /// on success (or refreshing its failed state on another failure).
  /// Returns true when the retry was dispatched.
  Future<bool> retry(int failedIndex) async {
    if (state.pending) return false;
    final rows = state.messages;
    if (failedIndex < 0 || failedIndex >= rows.length) return false;
    final row = rows[failedIndex];
    if (row.mine || !row.failed) return false;
    String question = '';
    for (var i = failedIndex - 1; i >= 0; i--) {
      if (rows[i].mine) {
        question = rows[i].text;
        break;
      }
    }
    if (question.isEmpty) return false;
    if (!_ref.read(isOnlineProvider)) {
      state = state.copyWith(error: ApiException.network());
      return false;
    }
    state = state.copyWith(pending: true, error: null);
    try {
      final answer =
          await _ref.read(internshipRepositoryProvider).askAssistant(question);
      final next = List.of(rows);
      next[failedIndex] = AssistantMessage(mine: false, text: answer);
      state = state.copyWith(messages: next, pending: false);
    } on Exception catch (e) {
      state = state.copyWith(pending: false, error: e);
    }
    await _persist();
    return true;
  }

  /// Clears the conversation locally after an explicit user confirmation
  /// (the screen owns the dialog; there is no server history to clear).
  Future<void> clear() async {
    final id = _userId ?? _currentUserId;
    state = const AssistantState();
    if (id == null) return;
    try {
      await _ref.read(assistantHistoryStoreProvider).clear(id);
    } on Exception {
      // Best-effort; the in-memory state is already empty.
    }
  }
}
