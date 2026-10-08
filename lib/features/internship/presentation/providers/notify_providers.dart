import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/network/api_exception.dart';
import 'workspace_providers.dart';

/// Supervisor document-preparation flow (T14/D14, SU-HOME-02/SU-CAL-04).
///
/// Multi-select lives here so the Interns list and the intern detail share
/// one selection; the server owns scope, rate limit and idempotency. The
/// UI waits only for server acceptance (a notified count), never for
/// recipient delivery. Online-only by design: preparation requests are not
/// part of the T06 offline queue.
class NotifyPreparationState {
  const NotifyPreparationState({
    this.selected = const {},
    this.sending = false,
    this.error,
    this.lastNotified,
  });

  final Set<String> selected;
  final bool sending;

  /// Raw failure of the last attempt (transient); screens localize it at
  /// the edge via `context.userError`.
  final Object? error;

  /// Server-accepted recipient count of the last successful submit.
  final int? lastNotified;

  NotifyPreparationState copyWith({
    Set<String>? selected,
    bool? sending,
    Object? error = _unset,
    int? lastNotified = _unsetInt,
  }) =>
      NotifyPreparationState(
        selected: selected ?? this.selected,
        sending: sending ?? this.sending,
        error: identical(error, _unset) ? this.error : error,
        lastNotified:
            lastNotified == _unsetInt ? this.lastNotified : lastNotified,
      );

  static const _unset = Object();
  static const _unsetInt = -1;
}

final notifyPreparationProvider = NotifierProvider.autoDispose<
    NotifyPreparationController, NotifyPreparationState>(
  NotifyPreparationController.new,
);

/// Whether the Interns list shows selection checkboxes (T14 multi-select).
/// Independent from the selection itself so entering the mode with stale
/// rows is impossible: exiting clears the selection.
final notifySelectModeProvider = StateProvider<bool>((ref) => false);

class NotifyPreparationController
    extends AutoDisposeNotifier<NotifyPreparationState> {
  @override
  NotifyPreparationState build() => const NotifyPreparationState();

  String? _lastKey;
  List<String> _lastKeyIds = const [];
  bool _lastAttemptFailed = false;

  void toggle(String internshipId) {
    final next = Set.of(state.selected);
    if (!next.remove(internshipId)) next.add(internshipId);
    state = state.copyWith(selected: next, error: null, lastNotified: null);
  }

  void clearSelection() {
    state = state.copyWith(selected: {}, error: null, lastNotified: null);
  }

  String _newKey() =>
      'notify-${DateTime.now().microsecondsSinceEpoch}';

  /// Duplicate-safe key selection (D14 "duplicate requests cannot generate
  /// duplicate notifications"). A **failed** attempt keeps its key while the
  /// target set is unchanged, so pressing send again replays the server-side
  /// receipt instead of notifying twice when the first request actually
  /// landed (timeout, lost response). A brand-new request — new/edited
  /// selection, or a new batch after a success — always mints a new key,
  /// because a reused key makes the server replay the *old* receipt (a
  /// different selection would silently never be notified).
  String _keyFor(List<String> ids) {
    final reusable = _lastAttemptFailed &&
        _lastKey != null &&
        _sameTargets(_lastKeyIds, ids);
    return reusable ? _lastKey! : _newKey();
  }

  static bool _sameTargets(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final set = a.toSet();
    return set.length == b.length && set.containsAll(b);
  }

  /// Submits the current selection. Returns the accepted count, or null
  /// when nothing was dispatched (empty selection, in-flight, offline).
  Future<int?> send() async {
    if (state.sending || state.selected.isEmpty) return null;
    if (!ref.read(isOnlineProvider)) {
      state = state.copyWith(error: ApiException.network());
      return null;
    }
    final ids = state.selected.toList()..sort();
    return _submit(ids, _keyFor(ids), clearOnOk: true);
  }

  /// Notifies exactly one internship (intern-detail shortcut).
  Future<int?> sendTo(String internshipId) async {
    if (state.sending) return null;
    if (!ref.read(isOnlineProvider)) {
      state = state.copyWith(error: ApiException.network());
      return null;
    }
    final ids = [internshipId];
    return _submit(ids, _keyFor(ids), clearOnOk: false);
  }

  Future<int?> _submit(
    List<String> ids,
    String key, {
    required bool clearOnOk,
  }) async {
    _lastKey = key;
    _lastKeyIds = List.of(ids);
    state = state.copyWith(sending: true, error: null, lastNotified: null);
    try {
      final notified = await ref
          .read(internshipRepositoryProvider)
          .notifyDocumentsPreparation(ids, idempotencyKey: key);
      _lastAttemptFailed = false;
      state = state.copyWith(
        sending: false,
        lastNotified: notified,
        selected: clearOnOk ? {} : state.selected,
      );
      return notified;
    } on Exception catch (e) {
      _lastAttemptFailed = true;
      state = state.copyWith(sending: false, error: e);
      return null;
    }
  }
}
