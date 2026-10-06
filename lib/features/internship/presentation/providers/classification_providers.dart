import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/task_classification.dart';
import '../../domain/repositories/internship_repository.dart';
import 'workspace_providers.dart';

/// T03 student task classification (ST-TASK-03/04/05, D5/D5b).
///
/// The backend is authoritative for ownership, validation, compare-and-set
/// and AI context; providers only render state and send intents. REST stays
/// authoritative — no socket subscription is added here (T06 owns realtime);
/// task mutations invalidate this board through [refreshClassification].

/// Category filter for the task board: all, unclassified only, or one
/// concrete category. Classification is a secondary dimension — it never
/// replaces the status board (T02).
class ClassificationFilter {
  const ClassificationFilter._(this.kind, this.categoryId);

  const ClassificationFilter.all() : this._(0, null);
  const ClassificationFilter.unclassified() : this._(1, null);
  const ClassificationFilter.category(String id) : this._(2, id);

  final int kind;
  final String? categoryId;

  bool get isAll => kind == 0;
  bool get isUnclassified => kind == 1;

  bool matches(String? taskCategoryId) => switch (kind) {
        0 => true,
        1 => taskCategoryId == null,
        _ => taskCategoryId == categoryId,
      };

  @override
  bool operator ==(Object other) =>
      other is ClassificationFilter &&
      kind == other.kind &&
      categoryId == other.categoryId;

  @override
  int get hashCode => Object.hash(kind, categoryId);
}

final classificationFilterProvider =
    StateProvider<ClassificationFilter>((ref) => const ClassificationFilter.all());

/// The student's classification board (throws `StateError('no-internship')`
/// when no internship is linked yet, like the other workspace providers).
final classificationBoardProvider =
    FutureProvider<ClassificationBoard>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  final board = await repo.classificationBoard(id);
  ref.read(lastClassificationProvider.notifier).state = board;
  return board;
});

/// Last successfully loaded board (for stale/offline rendering).
final lastClassificationProvider =
    StateProvider<ClassificationBoard?>((ref) => null);

/// Refresh classification state (called after task mutations too, so the
/// chips on cards never disagree with the board).
void refreshClassification(Ref ref) {
  ref.invalidate(classificationBoardProvider);
}

/// AI suggestion + accept/undo flow state.
class SuggestionFlowState {
  const SuggestionFlowState({
    this.loading = false,
    this.proposals = const [],
    this.unclassifiedCount = 0,
    this.capped = false,
    this.error,
    this.accepting = false,
    this.acceptedTaskIds = const {},
    this.lastBatchId,
    this.lastApply,
    this.undoing = false,
    this.lastUndo,
    this.round = 0,
  });

  final bool loading;
  final List<CategoryProposal> proposals;
  final int unclassifiedCount;
  final bool capped;
  final Object? error;
  final bool accepting;
  final Set<String> acceptedTaskIds;
  final String? lastBatchId;
  final ApplyCategoriesResult? lastApply;
  final bool undoing;
  final List<ApplyCategoryResult>? lastUndo;

  /// Incremented on every load so double invocations are detectable.
  final int round;

  bool get hasProposals => proposals.isNotEmpty;

  SuggestionFlowState copyWith({
    bool? loading,
    List<CategoryProposal>? proposals,
    int? unclassifiedCount,
    bool? capped,
    Object? error,
    bool clearError = false,
    bool? accepting,
    Set<String>? acceptedTaskIds,
    String? lastBatchId,
    bool clearBatch = false,
    ApplyCategoriesResult? lastApply,
    bool? undoing,
    List<ApplyCategoryResult>? lastUndo,
    int? round,
  }) =>
      SuggestionFlowState(
        loading: loading ?? this.loading,
        proposals: proposals ?? this.proposals,
        unclassifiedCount: unclassifiedCount ?? this.unclassifiedCount,
        capped: capped ?? this.capped,
        error: clearError ? null : (error ?? this.error),
        accepting: accepting ?? this.accepting,
        acceptedTaskIds: acceptedTaskIds ?? this.acceptedTaskIds,
        lastBatchId: clearBatch ? null : (lastBatchId ?? this.lastBatchId),
        lastApply: lastApply ?? this.lastApply,
        undoing: undoing ?? this.undoing,
        lastUndo: lastUndo ?? this.lastUndo,
        round: round ?? this.round,
      );
}

/// Owns the explicit AI flow: load → review → accept-one / accept-all → undo.
/// In-flight guards make double invocation impossible (accept/suggest/undo
/// return immediately while one is running); every mutation refreshes the
/// board so the UI reconciles with server state.
class SuggestionFlowController extends StateNotifier<SuggestionFlowState> {
  SuggestionFlowController(this._ref) : super(const SuggestionFlowState());

  final Ref _ref;

  InternshipRepository get _repo => _ref.read(internshipRepositoryProvider);

  Future<String?> _internshipId() => _ref.read(myInternshipIdProvider.future);

  String _key(String action, List<String> taskIds) =>
      '$action-${DateTime.now().microsecondsSinceEpoch}-${taskIds.length}'
      '-${taskIds.fold<int>(0, (a, id) => a ^ id.hashCode).toUnsigned(20)}';

  /// Explicitly invoked by the student only. Requires connectivity —
  /// callers disable the button offline instead of pretending AI works.
  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(
        loading: true, clearError: true, round: state.round + 1);
    try {
      final id = await _internshipId();
      if (id == null) throw StateError('no-internship');
      final suggestion = await _repo.suggestCategories(id);
      // Never trust arbitrary AI-generated identifiers: keep only proposals
      // for tasks present in the loaded task list when it is available;
      // otherwise trust the server-filtered response.
      final tasks = _ref.read(taskListProvider).valueOrNull?.items ??
          _ref.read(lastTasksProvider)?.items ??
          const [];
      final valid = tasks.isEmpty
          ? suggestion.proposals
          : [
              for (final p in suggestion.proposals)
                if (tasks.any((t) => t.id == p.taskId)) p,
            ];
      state = state.copyWith(
        loading: false,
        proposals: valid,
        unclassifiedCount: suggestion.unclassifiedCount,
        capped: suggestion.capped,
        acceptedTaskIds: const {},
        clearBatch: true,
      );
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Accept one proposal (existing or new category). Affects only that task.
  Future<void> acceptOne(CategoryProposal proposal) async {
    if (state.accepting || state.undoing) return;
    state = state.copyWith(accepting: true, clearError: true);
    try {
      final id = await _internshipId();
      if (id == null) throw StateError('no-internship');
      final board = _ref.read(classificationBoardProvider).valueOrNull ??
          _ref.read(lastClassificationProvider) ??
          ClassificationBoard.empty;
      final result = await _repo.applyCategories(id,
          items: [
            {
              'taskId': proposal.taskId,
              'categoryId': proposal.categoryId,
              'newCategoryName': proposal.newCategoryName,
              'expectedCategoryId': board.categoryOf(proposal.taskId),
            }
          ],
          idempotencyKey: _key('one', [proposal.taskId]));
      final accepted = {
        ...state.acceptedTaskIds,
        for (final r in result.items)
          if (r.applied) r.taskId,
      };
      state = state.copyWith(
        accepting: false,
        acceptedTaskIds: accepted,
        lastBatchId: result.batchId ?? state.lastBatchId,
        lastApply: result,
      );
      refreshClassification(_ref);
    } on Exception catch (e) {
      state = state.copyWith(accepting: false, error: e);
    }
  }

  /// Accept every still-valid proposal. Per-item compare-and-set server-side:
  /// only still-unclassified tasks change; the rest is reported per item.
  Future<void> acceptAll() async {
    if (state.accepting || state.undoing || state.proposals.isEmpty) return;
    state = state.copyWith(accepting: true, clearError: true);
    try {
      final id = await _internshipId();
      if (id == null) throw StateError('no-internship');
      final board = _ref.read(classificationBoardProvider).valueOrNull ??
          _ref.read(lastClassificationProvider) ??
          ClassificationBoard.empty;
      final pending = [
        for (final p in state.proposals)
          if (!state.acceptedTaskIds.contains(p.taskId)) p,
      ];
      final result = await _repo.applyCategories(id,
          items: [
            for (final p in pending)
              {
                'taskId': p.taskId,
                'categoryId': p.categoryId,
                'newCategoryName': p.newCategoryName,
                'expectedCategoryId': board.categoryOf(p.taskId),
              },
          ],
          idempotencyKey:
              _key('all', [for (final p in pending) p.taskId]));
      final accepted = {
        ...state.acceptedTaskIds,
        for (final r in result.items)
          if (r.applied) r.taskId,
      };
      state = state.copyWith(
        accepting: false,
        acceptedTaskIds: accepted,
        lastBatchId: result.batchId ?? state.lastBatchId,
        lastApply: result,
      );
      refreshClassification(_ref);
    } on Exception catch (e) {
      state = state.copyWith(accepting: false, error: e);
    }
  }

  /// Undo the last accepted batch (restores only tasks unchanged since).
  Future<void> undo() async {
    final batchId = state.lastBatchId;
    if (state.undoing || state.accepting || batchId == null) return;
    state = state.copyWith(undoing: true, clearError: true);
    try {
      final results = await _repo.undoApplyBatch(batchId);
      state = state.copyWith(undoing: false, lastUndo: results);
      refreshClassification(_ref);
    } on Exception catch (e) {
      state = state.copyWith(undoing: false, error: e);
    }
  }

  void clear() => state = const SuggestionFlowState();
}

final suggestionFlowProvider =
    StateNotifierProvider<SuggestionFlowController, SuggestionFlowState>(
        (ref) => SuggestionFlowController(ref));
