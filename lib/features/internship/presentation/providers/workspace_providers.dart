import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/settings_providers.dart';
import '../../../../core/network/paged.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/cache/composer_draft_store.dart';
import '../../data/cache/internship_id_store.dart';
import '../../data/datasources/internship_remote_data_source.dart';
import '../../data/repositories/internship_repository_impl.dart';
import '../../domain/dashboard.dart';
import '../../domain/calendar.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/internship.dart';
import '../../domain/entities/logbook.dart';
import '../../domain/entities/work_items.dart';
import '../../domain/repositories/internship_repository.dart';

final internshipRemoteDataSourceProvider =
    Provider<InternshipRemoteDataSource>(
        (ref) => InternshipRemoteDataSource(ref.watch(apiClientProvider)));

final internshipIdStoreProvider = Provider<InternshipIdStore>((ref) =>
    PrefsInternshipIdStore(ref.watch(prefsStoreProvider)));

final internshipRepositoryProvider = Provider<InternshipRepository>(
  (ref) => InternshipRepositoryImpl(
    remote: ref.watch(internshipRemoteDataSourceProvider),
    tokens: ref.watch(tokenStorageProvider),
    idStore: ref.watch(internshipIdStoreProvider),
  ),
);

/// Resolved internship id (null = no linked internship yet).
final myInternshipIdProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.resolveMyInternshipId();
});

final internshipDetailProvider = FutureProvider<Internship>((ref) async {
  final id = ref.watch(myInternshipIdProvider).valueOrNull;
  if (id == null) throw StateError('no-internship');
  return ref.watch(internshipRepositoryProvider).getInternship(id);
});

final assignmentsProvider =
    FutureProvider<List<InternshipAssignment>>((ref) async {
  final id = ref.watch(myInternshipIdProvider).valueOrNull;
  if (id == null) return const [];
  return ref.watch(internshipRepositoryProvider).getAssignments(id);
});

/// Task status filter for the task list (null = all).
///
/// A non-null value is a **server** query (`?status=`) — the board itself is
/// built from the unfiltered page.
final taskFilterProvider = StateProvider<TaskStatus?>((ref) => null);

/// Client-side task search (title/description). The page is bounded
/// server-side (50), so filtering in memory is exact and instant; it never
/// replaces the server status filter.
final taskSearchProvider = StateProvider<String>((ref) => '');

/// Full dashboard snapshot: ONE scoped read (T13/B13) plus the two live
/// badge counts. Throws `StateError('no-internship')` when no internship is
/// linked yet. The badge reads stay separate on purpose: they are
/// shell-global live state (socket-invalidated), and bundling them into the
/// cached summary would stale the badges.
final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  final now = DateTime.now();

  final summary = await repo.internshipSummary(id);
  final results = await Future.wait([
    repo.unreadNotificationCount(),
    repo.unreadMessageCount(),
  ]);
  final data = buildDashboard(DashboardInput(
    internship: summary.internship,
    assignments: summary.assignments,
    tasks: summary.tasks,
    tasksCompletedTotal: summary.tasksCompletedTotal,
    tasksGrandTotal: summary.tasksGrandTotal,
    journal: summary.journal,
    pendingJournalTotal: summary.pendingJournalTotal,
    journalValidatedTotal: summary.journalValidatedTotal,
    deliverables: summary.deliverables,
    deliverablesTotal: summary.deliverablesTotal,
    evaluations: summary.evaluations,
    notifications: summary.notifications,
    unreadNotifications: results[0],
    unreadMessages: results[1],
    now: now,
  ));
  // Keep last-good snapshot for honest stale rendering when offline.
  ref.read(lastDashboardProvider.notifier).state = data;
  return data;
});

/// Last successfully loaded dashboard (for stale/offline rendering).
final lastDashboardProvider = StateProvider<DashboardData?>((ref) => null);

/// Task list page honoring the current filter.
final taskListProvider = FutureProvider<Paged<InternTask>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  final filter = ref.watch(taskFilterProvider);
  final page = await repo.listTasks(id, size: 50, status: filter);
  ref.read(lastTasksProvider.notifier).state = page;
  return page;
});

final lastTasksProvider =
    StateProvider<Paged<InternTask>?>((ref) => null);

/// Selected journal day (defaults to today). Day navigation filters the
/// list through the backend `startDate`/`endDate` query.
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

final selectedDayProvider = StateProvider<DateTime>((ref) => _today());

final journalStatusFilterProvider =
    StateProvider<JournalStatus?>((ref) => null);

/// Journal page for the selected day + status filter.
final journalListProvider =
    FutureProvider<Paged<JournalEntry>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  final page = await repo.listJournal(id,
      size: 20,
      status: ref.watch(journalStatusFilterProvider),
      day: ref.watch(selectedDayProvider));
  ref.read(lastJournalProvider.notifier).state = page;
  return page;
});

final lastJournalProvider =
    StateProvider<Paged<JournalEntry>?>((ref) => null);

/// Every journal entry inside a calendar month, used by the month calendar to
/// mark the days that already carry work (dot + count). One bounded request
/// per displayed month — never one per day. Failures degrade to "no marks":
/// the calendar still renders the period and the day selection.
final journalMonthProvider =
    FutureProvider.family<Paged<JournalEntry>, DateTime>((ref, month) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  return repo.listJournal(
    id,
    size: 100,
    from: DateTime(month.year, month.month, 1),
    to: DateTime(month.year, month.month + 1, 0),
  );
});

/// Feedback comments for one journal entry (supervisor notes live here).
final journalCommentsProvider =
    FutureProvider.family<List<JournalComment>, String>(
        (ref, entryId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.journalComments(entryId);
});

final composerDraftStoreProvider = Provider<ComposerDraftStore>(
    (ref) => PrefsComposerDraftStore(ref.watch(prefsStoreProvider)));

/// One submitted entry awaiting review, with its internship context.
class PendingValidation {
  const PendingValidation({
    required this.internshipId,
    required this.internshipReference,
    required this.entry,
  });

  final String internshipId;
  final String internshipReference;
  final JournalEntry entry;
}

/// Supervisor queue: SUBMITTED entries across supervised internships.
/// Fail-soft per internship (one failure never hides the other queues);
/// throws only when every queue fails.
final pendingValidationsProvider =
    FutureProvider<List<PendingValidation>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final ids = await repo.supervisedInternshipIds();
  final out = <PendingValidation>[];
  Object? firstError;
  final results = await Future.wait(
    ids.map((id) async {
      try {
        final page =
            await repo.listJournal(id, status: JournalStatus.submitted, size: 50);
        String reference = id;
        try {
          reference = (await repo.getInternship(id)).reference;
        } on Exception {
          // Reference is decoration; the queue matters.
        }
        return MapEntry(reference,
            page.items.map((e) => PendingValidation(
                internshipId: id,
                internshipReference: reference,
                entry: e)));
      } on Exception catch (e) {
        firstError ??= e;
        return const MapEntry('', <PendingValidation>[]);
      }
    }),
  );
  for (final r in results) {
    out.addAll(r.value);
  }
  if (out.isEmpty && firstError != null) throw firstError!;
  return out;
});

/// Refresh every workspace provider (pull-to-refresh entry point).
void refreshWorkspace(WidgetRef ref) {
  ref
    ..invalidate(myInternshipIdProvider)
    ..invalidate(dashboardProvider)
    ..invalidate(taskListProvider)
    ..invalidate(journalListProvider)
    ..invalidate(assignmentsProvider)
    ..invalidate(internshipDetailProvider);
}

/// Refresh supervisor-side providers.
void refreshValidations(WidgetRef ref) {
  ref
    ..invalidate(pendingValidationsProvider)
    ..invalidate(pendingDeliverableReviewsProvider)
    ..invalidate(pendingLogbookReviewsProvider);
}

/// Intern's deliverable checklist page.
final deliverablesListProvider =
    FutureProvider<Paged<DeliverableSummary>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  return repo.listDeliverables(id, size: 50);
});

/// Full detail incl. version history.
final deliverableDetailProvider =
    FutureProvider.family<DeliverableDetail, String>(
        (ref, deliverableId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.getDeliverable(deliverableId);
});

/// T10/B7 — the server-owned final-week submission window (BR-22). Family by
/// internship id; invalidated after a submit so the read stays honest.
/// The device clock never decides (server computes in `Africa/Tunis`).
final submissionWindowProvider =
    FutureProvider.family<SubmissionWindow, String>(
        (ref, internshipId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.submissionWindow(internshipId);
});

final deliverableCommentsProvider =
    FutureProvider.family<List<JournalComment>, String>(
        (ref, deliverableId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.deliverableComments(deliverableId);
});

/// Supervisor queue: SUBMITTED deliverables across supervised internships.
final pendingDeliverableReviewsProvider =
    FutureProvider<List<PendingDeliverableReview>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.pendingDeliverableReviews();
});

/// Refresh deliverable providers after any mutation.
void refreshDeliverables(WidgetRef ref, [String? deliverableId]) {
  ref.invalidate(deliverablesListProvider);
  ref.invalidate(pendingDeliverableReviewsProvider);
  ref.invalidate(dashboardProvider);
  if (deliverableId != null) {
    ref.invalidate(deliverableDetailProvider(deliverableId));
    ref.invalidate(deliverableCommentsProvider(deliverableId));
  }
}

// --- D4 supervisor workspace ---

/// Supervised interns with backend-sourced progress (fail-soft per
/// intern inside the repository: one failure never hides the others).
final supervisedInternsProvider =
    FutureProvider<List<SupervisedIntern>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final interns = await repo.supervisedInterns();
  ref.read(lastSupervisedProvider.notifier).state = interns;
  return interns;
});

/// Last good supervised list for stale-offline rendering (T12 mirrors the
/// journal pattern: cached rows stay visible with an explicit stale label).
final lastSupervisedProvider =
    StateProvider<List<SupervisedIntern>?>((ref) => null);

/// Interns-tab view: list or period calendar (SU-CAL-01/02).
enum SupervisedView { list, calendar }

final supervisedViewProvider =
    StateProvider<SupervisedView>((ref) => SupervisedView.list);

/// Candidates-list search text (name/reference, case-insensitive).
final supervisedSearchProvider = StateProvider<String>((ref) => '');

/// Candidates-list sort order (SU-CAL-02).
final supervisedSortProvider =
    StateProvider<SupervisedSort>((ref) => SupervisedSort.name);

/// Full intern detail for supervisors: header, tasks, pending journal,
/// deliverables, evaluations — composed from backend reads.
class SupervisedInternDetail {
  const SupervisedInternDetail({
    required this.internship,
    required this.assignments,
    required this.activeAssignment,
    required this.tasks,
    required this.tasksTotal,
    required this.tasksCompletedTotal,
    required this.pendingJournal,
    required this.deliverables,
    required this.evaluations,
  });

  final Internship internship;
  final List<InternshipAssignment> assignments;
  final InternshipAssignment? activeAssignment;
  final List<InternTask> tasks;
  final int tasksTotal;
  final int tasksCompletedTotal;
  final List<JournalEntry> pendingJournal;
  final List<DeliverableSummary> deliverables;
  final List<EvaluationSummary> evaluations;
}

final supervisedInternDetailProvider = FutureProvider.family<
    SupervisedInternDetail, String>((ref, internshipId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final results = await Future.wait([
    repo.getInternship(internshipId),
    repo.getAssignments(internshipId),
    repo.listTasks(internshipId, size: 50),
    // BR-11/A2: an intern's "done" count is his APPROVED tasks only.
    repo.listTasks(internshipId,
        size: 1, status: TaskStatus.approved),
    repo.listJournal(internshipId,
        status: JournalStatus.submitted, size: 50),
    repo.listDeliverables(internshipId, size: 50),
    repo.listEvaluations(internshipId, size: 20),
  ]);
  final assignments = results[1] as List<InternshipAssignment>;
  InternshipAssignment? active;
  for (final a in assignments) {
    if (a.isActive) {
      active = a;
      break;
    }
  }
  final tasks = results[2] as Paged<InternTask>;
  return SupervisedInternDetail(
    internship: results[0] as Internship,
    assignments: assignments,
    activeAssignment: active,
    tasks: tasks.items,
    tasksTotal: tasks.totalElements,
    tasksCompletedTotal:
        (results[3] as Paged<InternTask>).totalElements,
    pendingJournal: (results[4] as Paged<JournalEntry>).items,
    deliverables:
        (results[5] as Paged<DeliverableSummary>).items,
    evaluations: (results[6] as Paged<EvaluationSummary>).items,
  );
});

/// Active evaluation templates (supervisor-visible).
final evaluationTemplatesProvider =
    FutureProvider<List<EvaluationTemplate>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.listTemplates(activeOnly: true);
});

/// Criteria of the selected template — the form is generated from these.
final templateCriteriaProvider = FutureProvider.family<
    List<EvaluationCriterion>, String>((ref, templateId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.templateCriteria(templateId);
});

/// Full evaluation: authoritative detail + scores + task reviews +
/// comments (read-only for interns, authorship for supervisors).
class EvaluationFull {
  const EvaluationFull({
    required this.detail,
    required this.scores,
    required this.taskReviews,
    required this.comments,
  });

  final EvaluationSummary detail;
  final List<EvaluationScore> scores;
  final List<EvaluationTaskReview> taskReviews;
  final List<JournalComment> comments;
}

final evaluationFullProvider =
    FutureProvider.family<EvaluationFull, String>(
        (ref, evaluationId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final results = await Future.wait([
    repo.evaluationDetail(evaluationId),
    repo.evaluationScores(evaluationId),
    repo.evaluationTaskReviews(evaluationId),
    repo.evaluationComments(evaluationId),
  ]);
  return EvaluationFull(
    detail: results[0] as EvaluationSummary,
    scores: results[1] as List<EvaluationScore>,
    taskReviews: results[2] as List<EvaluationTaskReview>,
    comments: results[3] as List<JournalComment>,
  );
});

/// Intern's own evaluations (read-only).
final myEvaluationsProvider =
    FutureProvider<Paged<EvaluationSummary>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  return repo.listEvaluations(id, size: 20);
});

// --- D6 advisory logbook (review-only draft, graceful degradation) ---

/// Advisory draft generation. Throws on AI outage/rate-limit: the UI
/// catches and shows a retry card WITHOUT blocking core flows.
final logbookDraftProvider =
    FutureProvider<LogbookDraft>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  return repo.generateLogbookDraft(id);
});

/// Submission in-flight flag for the logbook review flow.
final logbookSubmitProvider = StateProvider<bool>((ref) => false);

/// Locally edited logbook text (review copy; never auto-submitted).
final logbookEditProvider = StateProvider<String?>((ref) => null);

/// Server-authoritative logbook for an internship (null before first submit).
/// The backend decides every state transition; this is pure read-through.
final logbookProvider = FutureProvider.family<LogbookState?, String>(
    (ref, internshipId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final logbook = await repo.getLogbook(internshipId);
  return logbook;
});

/// Supervisor queue: SUBMITTED logbooks across supervised internships.
final pendingLogbookReviewsProvider =
    FutureProvider<List<PendingLogbookReview>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.pendingLogbookReviews();
});

/// Refresh logbook providers after a mutation (decision or resubmit).
void refreshLogbooks(WidgetRef ref, [String? internshipId]) {
  ref.invalidate(pendingLogbookReviewsProvider);
  if (internshipId != null) {
    ref.invalidate(logbookProvider(internshipId));
  }
}

/// Task page for any internship (supervisor review + task reviews).
final internshipTasksProvider = FutureProvider.family<
    Paged<InternTask>, String>((ref, internshipId) async {
  final repo = ref.watch(internshipRepositoryProvider);
  return repo.listTasks(internshipId, size: 50);
});

/// Refresh supervisor workspace providers.
void refreshSupervisor(WidgetRef ref, [String? internshipId]) {
  ref.invalidate(supervisedInternsProvider);
  refreshValidations(ref);
  if (internshipId != null) {
    ref.invalidate(supervisedInternDetailProvider(internshipId));
  }
}
