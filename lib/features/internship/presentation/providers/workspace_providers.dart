import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/settings_providers.dart';
import '../../../../core/network/paged.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/cache/internship_id_store.dart';
import '../../data/datasources/internship_remote_data_source.dart';
import '../../data/repositories/internship_repository_impl.dart';
import '../../domain/dashboard.dart';
import '../../domain/entities/internship.dart';
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
final taskFilterProvider = StateProvider<TaskStatus?>((ref) => null);

/// Full dashboard snapshot, fetched in parallel. Throws
/// `StateError('no-internship')` when no internship is linked yet.
final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  final now = DateTime.now();

  final results = await Future.wait([
    repo.getInternship(id),
    repo.getAssignments(id),
    repo.listTasks(id, size: 50),
    repo.listTasks(id, size: 1, status: TaskStatus.completed),
    repo.listJournal(id, size: 20),
    repo.listJournal(id, size: 1, status: JournalStatus.draft),
    repo.listJournal(id, size: 1, status: JournalStatus.rejected),
    repo.listDeliverables(id, size: 20),
    repo.listEvaluations(id, size: 10),
    repo.listNotifications(size: 5),
    repo.unreadNotificationCount(),
    repo.unreadMessageCount(),
  ]);

  final tasks = results[2] as Paged<InternTask>;
  final tasksDone = results[3] as Paged<InternTask>;
  final journal = results[4] as Paged<JournalEntry>;
  final drafts = results[5] as Paged<JournalEntry>;
  final rejected = results[6] as Paged<JournalEntry>;
  final deliverables = results[7] as Paged<DeliverableSummary>;
  final evaluations = results[8] as Paged<EvaluationSummary>;
  final notifications = results[9] as Paged<AppNotification>;

  final data = buildDashboard(DashboardInput(
    internship: results[0] as Internship,
    assignments: results[1] as List<InternshipAssignment>,
    tasks: tasks.items,
    tasksCompletedTotal: tasksDone.totalElements,
    tasksGrandTotal: tasks.totalElements,
    journal: journal.items,
    pendingJournalTotal: drafts.totalElements + rejected.totalElements,
    deliverables: deliverables.items,
    evaluations: evaluations.items,
    notifications: notifications.items,
    unreadNotifications: results[10] as int,
    unreadMessages: results[11] as int,
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

/// Read-only journal page (D1). Write flows land in D2.
final journalListProvider =
    FutureProvider<Paged<JournalEntry>>((ref) async {
  final repo = ref.watch(internshipRepositoryProvider);
  final id = await ref.watch(myInternshipIdProvider.future);
  if (id == null) throw StateError('no-internship');
  return repo.listJournal(id, size: 20);
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
