import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/task_drafts.dart';
import '../../domain/repositories/internship_repository.dart';
import 'supervisor_tasks_providers.dart';
import 'workspace_providers.dart';

/// T05 supervisor AI task drafts (SU-TASK-02).
///
/// Drafts are server-side proposals; only bulk-add creates real tasks
/// (atomic, idempotent, per-pair validated). The backend owns scope
/// (out-of-scope → 404), schema, rate limits and validation; this
/// controller renders state and sends intents. REST stays authoritative —
/// no socket work (T06 owns realtime).

enum DraftSource { pdf, text }

class TaskDraftFlowState {
  const TaskDraftFlowState({
    this.referenceInternshipId,
    this.source = DraftSource.text,
    this.pdfName,
    this.specText = '',
    this.generating = false,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.drafts = const [],
    this.error,
    this.targets = const {},
    this.visibleFrom,
    this.bulkAdding = false,
    this.lastBulk,
    this.busyDraftId,
    this.generation = 0,
  });

  final String? referenceInternshipId;
  final DraftSource source;
  final String? pdfName;
  final String specText;
  final bool generating;

  /// Upload progress for the PDF path (bytes sent/total).
  final int sentBytes;
  final int totalBytes;
  final List<TaskDraft> drafts;
  final Object? error;
  final Set<String> targets;

  /// Optional shared batch schedule (T04 D8 rule, validated per target).
  final DateTime? visibleFrom;
  final bool bulkAdding;
  final DraftBulkResult? lastBulk;

  /// Draft id under a per-item mutation (edit/revise/delete), if any.
  final String? busyDraftId;

  /// Incremented on every generate/abandon so an abandoned wait ignores
  /// its late result instead of flashing stale drafts.
  final int generation;

  double? get uploadProgress =>
      totalBytes <= 0 ? null : sentBytes / totalBytes;

  TaskDraftFlowState copyWith({
    String? referenceInternshipId,
    DraftSource? source,
    String? pdfName,
    bool clearPdf = false,
    String? specText,
    bool? generating,
    int? sentBytes,
    int? totalBytes,
    List<TaskDraft>? drafts,
    Object? error,
    bool clearError = false,
    Set<String>? targets,
    DateTime? visibleFrom,
    bool clearSchedule = false,
    bool? bulkAdding,
    DraftBulkResult? lastBulk,
    bool clearBulk = false,
    String? busyDraftId,
    int? generation,
  }) =>
      TaskDraftFlowState(
        referenceInternshipId:
            referenceInternshipId ?? this.referenceInternshipId,
        source: source ?? this.source,
        pdfName: clearPdf ? null : (pdfName ?? this.pdfName),
        specText: specText ?? this.specText,
        generating: generating ?? this.generating,
        sentBytes: sentBytes ?? this.sentBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        drafts: drafts ?? this.drafts,
        error: clearError ? null : (error ?? this.error),
        targets: targets ?? this.targets,
        visibleFrom:
            clearSchedule ? null : (visibleFrom ?? this.visibleFrom),
        bulkAdding: bulkAdding ?? this.bulkAdding,
        lastBulk: clearBulk ? null : (lastBulk ?? this.lastBulk),
        busyDraftId: busyDraftId,
        generation: generation ?? this.generation,
      );
}

class TaskDraftFlowController extends StateNotifier<TaskDraftFlowState> {
  TaskDraftFlowController(this._ref, String? referenceInternshipId)
      : super(TaskDraftFlowState(
            referenceInternshipId: referenceInternshipId,
            targets: referenceInternshipId == null
                ? const {}
                : {referenceInternshipId}));

  final Ref _ref;

  /// PDF bytes stay in the controller (never in state, never logged).
  Uint8List? _pdfBytes;

  InternshipRepository get _repo =>
      _ref.read(internshipRepositoryProvider);

  String _bulkKey(int count) =>
      'drafts-${DateTime.now().microsecondsSinceEpoch}-$count';

  void setReference(String id) => state = state.copyWith(
      referenceInternshipId: id,
      targets:
          state.targets.isEmpty ? {id} : state.targets,
      clearBulk: true);

  void setSource(DraftSource source) =>
      state = state.copyWith(source: source, clearError: true);

  void setSpecText(String text) =>
      state = state.copyWith(specText: text);

  void setPdf(String name, Uint8List bytes) {
    _pdfBytes = bytes;
    state = state.copyWith(pdfName: name, clearError: true);
  }

  void clearPdf() {
    _pdfBytes = null;
    state = state.copyWith(clearPdf: true);
  }

  void toggleTarget(String internshipId, bool on) {
    final next = Set<String>.of(state.targets);
    if (on) {
      next.add(internshipId);
    } else {
      next.remove(internshipId);
    }
    state = state.copyWith(targets: next, clearBulk: true);
  }

  void setSchedule(DateTime? instant) => state = instantsEqual(
          state.visibleFrom, instant)
      ? state
      : state.copyWith(
          visibleFrom: instant, clearSchedule: instant == null);

  static bool instantsEqual(DateTime? a, DateTime? b) =>
      (a == null && b == null) ||
      (a != null &&
          b != null &&
          a.toUtc().millisecondsSinceEpoch ==
              b.toUtc().millisecondsSinceEpoch);

  /// Explicitly invoked by the supervisor only. Requires connectivity —
  /// callers disable the button offline instead of pretending AI works.
  Future<void> generate() async {
    if (state.generating || state.referenceInternshipId == null) return;
    final id = state.referenceInternshipId!;
    if (state.source == DraftSource.pdf && _pdfBytes == null) return;
    if (state.source == DraftSource.text &&
        state.specText.trim().isEmpty) {
      return;
    }
    final round = state.generation + 1;
    state = state.copyWith(
        generating: true,
        clearError: true,
        clearBulk: true,
        sentBytes: 0,
        totalBytes:
            state.source == DraftSource.pdf ? _pdfBytes!.length : 0,
        generation: round);
    try {
      final List<TaskDraft> drafts;
      if (state.source == DraftSource.pdf) {
        drafts = await _repo.generateDraftsFromPdf(id,
            fileName: state.pdfName ?? 'specs.pdf',
            bytes: _pdfBytes!,
            onProgress: (sent, total) {
              if (state.generation == round && mounted) {
                state = state.copyWith(
                    sentBytes: sent, totalBytes: total);
              }
            });
      } else {
        drafts = await _repo.generateDraftsFromText(id,
            specText: state.specText.trim());
      }
      // An abandoned wait ignores its late result (no stale flash).
      if (!mounted || state.generation != round) return;
      state = state.copyWith(generating: false, drafts: drafts);
    } on Exception catch (e) {
      if (!mounted || state.generation != round) return;
      state = state.copyWith(generating: false, error: e);
    }
  }

  /// Stop waiting for the in-flight generation. Server-side drafts (if the
  /// call already succeeded) simply appear on the next refresh — abandoning
  /// the wait never creates a task.
  void abandon() {
    if (!state.generating) return;
    state = state.copyWith(
        generating: false, generation: state.generation + 1);
  }

  Future<void> reload() async {
    final id = state.referenceInternshipId;
    if (id == null) return;
    try {
      final drafts = await _repo.listDrafts(internshipId: id);
      if (!mounted) return;
      state = state.copyWith(drafts: drafts, clearError: true);
    } on Exception catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    }
  }

  Future<bool> addManual(
      {required String title,
      String? description,
      DateTime? dueDate}) async {
    final id = state.referenceInternshipId;
    if (id == null || state.busyDraftId != null) return false;
    if (title.trim().isEmpty) return false;
    state = state.copyWith(busyDraftId: '__new', clearError: true);
    try {
      final draft = await _repo.addDraftManual(id,
          title: title.trim(), description: description, dueDate: dueDate);
      if (!mounted) return false;
      state = state.copyWith(
          busyDraftId: null, drafts: [...state.drafts, draft]);
      return true;
    } on Exception catch (e) {
      if (!mounted) return false;
      state = state.copyWith(busyDraftId: null, error: e);
      return false;
    }
  }

  Future<bool> updateDraft(String draftId,
      {String? title, String? description, DateTime? dueDate}) async {
    if (state.busyDraftId != null) return false;
    state = state.copyWith(busyDraftId: draftId, clearError: true);
    try {
      final updated = await _repo.updateDraft(draftId,
          title: title, description: description, dueDate: dueDate);
      if (!mounted) return false;
      state = state.copyWith(busyDraftId: null, drafts: [
        for (final d in state.drafts)
          if (d.id == draftId) updated else d,
      ]);
      return true;
    } on Exception catch (e) {
      if (!mounted) return false;
      state = state.copyWith(busyDraftId: null, error: e);
      return false;
    }
  }

  Future<bool> reviseDraft(String draftId, String instruction) async {
    if (state.busyDraftId != null || instruction.trim().isEmpty) {
      return false;
    }
    state = state.copyWith(busyDraftId: draftId, clearError: true);
    try {
      final revised = await _repo.reviseDraft(draftId,
          instruction: instruction.trim());
      if (!mounted) return false;
      state = state.copyWith(busyDraftId: null, drafts: [
        for (final d in state.drafts)
          if (d.id == draftId) revised else d,
      ]);
      return true;
    } on Exception catch (e) {
      if (!mounted) return false;
      state = state.copyWith(busyDraftId: null, error: e);
      return false;
    }
  }

  Future<bool> deleteDraft(String draftId) async {
    if (state.busyDraftId != null) return false;
    state = state.copyWith(busyDraftId: draftId, clearError: true);
    try {
      await _repo.deleteDraft(draftId);
      if (!mounted) return false;
      state = state.copyWith(busyDraftId: null, drafts: [
        for (final d in state.drafts)
          if (d.id != draftId) d,
      ]);
      return true;
    } on Exception catch (e) {
      if (!mounted) return false;
      state = state.copyWith(busyDraftId: null, error: e);
      return false;
    }
  }

  /// Explicit acceptance: atomic bulk-add with a fresh idempotency key per
  /// submit. Only the returned result authorizes the success screen.
  Future<bool> bulkAdd() async {
    if (state.bulkAdding || state.generating) return false;
    if (state.drafts.isEmpty || state.targets.isEmpty) return false;
    state = state.copyWith(bulkAdding: true, clearError: true);
    try {
      final result = await _repo.bulkAddDrafts(
        draftIds: [for (final d in state.drafts) d.id],
        internshipIds: state.targets.toList(),
        idempotencyKey: _bulkKey(state.drafts.length),
        visibleFrom: state.visibleFrom,
      );
      if (!mounted) return false;
      state = state.copyWith(bulkAdding: false, lastBulk: result);
      _ref
        ..invalidate(supervisorTasksProvider)
        ..invalidate(supervisedInternsProvider);
      return true;
    } on Exception catch (e) {
      if (!mounted) return false;
      state = state.copyWith(bulkAdding: false, error: e);
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final taskDraftFlowProvider = StateNotifierProvider.family<
    TaskDraftFlowController, TaskDraftFlowState, String?>(
  (ref, referenceInternshipId) =>
      TaskDraftFlowController(ref, referenceInternshipId),
);
