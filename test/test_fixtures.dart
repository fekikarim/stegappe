import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/features/internship/domain/dashboard.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/domain/repositories/internship_repository.dart';

DateTime day(DateTime base, int offset) {
  final d = base.add(Duration(days: offset));
  return DateTime(d.year, d.month, d.day);
}

Internship fixtureInternship(DateTime now) => Internship(
      id: 'internship-1',
      reference: 'STG-2026-0001',
      startDate: day(now, -10),
      endDate: day(now, 50),
      status: InternshipStatus.active,
      type: InternshipType.perfectionnement,
      requirement: 'OBLIGATOIRE',
      paymentEligible: true,
      subject: 'Digitalisation du suivi des stagiaires',
      candidateFullName: 'Amira Ben Salah',
    );

List<InternTask> fixtureTasks(DateTime now) => [
      InternTask(
          id: 't-overdue', title: 'Overdue task', status: TaskStatus.todo, dueDate: day(now, -2)),
      InternTask(
          id: 't-today', title: 'Today task', status: TaskStatus.inProgress, dueDate: day(now, 0)),
      InternTask(
          id: 't-week', title: 'Week task', status: TaskStatus.todo, dueDate: day(now, 3)),
      InternTask(
          id: 't-done', title: 'Done task', status: TaskStatus.completed, dueDate: day(now, -5)),
    ];

List<JournalEntry> fixtureJournal(DateTime now) => [
      JournalEntry(
          id: 'j-draft', title: 'Draft entry', status: JournalStatus.draft, entryDate: day(now, 0)),
      JournalEntry(
          id: 'j-sub', title: 'Submitted entry', status: JournalStatus.submitted, entryDate: day(now, -1)),
      JournalEntry(
          id: 'j-val', title: 'Validated entry', status: JournalStatus.validated, entryDate: day(now, -2)),
    ];

DashboardData fixtureDashboard(DateTime now) => buildDashboard(
      DashboardInput(
        internship: fixtureInternship(now),
        assignments: [
          InternshipAssignment(
              id: 'a1',
              departmentName: 'DSI',
              supervisorName: 'Karim Feki',
              status: 'ACTIVE',
              startDate: day(now, -10),
              endDate: day(now, 50)),
        ],
        tasks: fixtureTasks(now),
        tasksCompletedTotal: 1,
        tasksGrandTotal: 4,
        journal: fixtureJournal(now),
        pendingJournalTotal: 1,
        deliverables: const [
          DeliverableSummary(
              id: 'd1', title: 'Rapport', status: DeliverableStatus.submitted, currentVersion: 2),
        ],
        evaluations: [
          EvaluationSummary(
              id: 'e1', type: 'WEEKLY', evaluationDate: day(now, -7), totalScore: 15.5),
        ],
        notifications: [
          AppNotification(
              id: 'n1',
              title: 'Bienvenue',
              message: 'Bienvenue sur la plateforme',
              priority: 'NORMAL',
              createdAt: now,
              isRead: false),
        ],
        unreadNotifications: 1,
        unreadMessages: 2,
        now: now,
      ),
    );

Paged<T> pageOf<T>(List<T> items, {int total = -1}) => Paged<T>(
      items: items,
      page: 0,
      totalElements: total < 0 ? items.length : total,
      totalPages: 1,
      isLast: true,
    );

/// Fake repository for widget tests. Records write calls.
class FakeInternshipRepository implements InternshipRepository {
  FakeInternshipRepository({DateTime? now}) : now = now ?? DateTime.now();

  final DateTime now;
  TaskStatus? lastStatusFilter;
  final List<(String, TaskStatus)> statusUpdates = [];
  bool failWrites = false;
  bool noInternship = false;

  DashboardData get dashboard => fixtureDashboard(now);

  @override
  Future<String?> resolveMyInternshipId() async =>
      noInternship ? null : 'internship-1';

  @override
  Future<Internship> getInternship(String id) async =>
      fixtureInternship(now);

  @override
  Future<List<InternshipAssignment>> getAssignments(String id) async =>
      dashboard.assignments;

  @override
  Future<Paged<InternTask>> listTasks(String internshipId,
      {int page = 0, int size = 50, TaskStatus? status}) async {
    lastStatusFilter = status;
    final all = fixtureTasks(now);
    final items =
        status == null ? all : all.where((t) => t.status == status).toList();
    return pageOf(items, total: items.length);
  }

  @override
  Future<InternTask> updateTaskStatus(
      String taskId, TaskStatus status) async {
    if (failWrites) {
      throw Exception('offline');
    }
    statusUpdates.add((taskId, status));
    final t = fixtureTasks(now).firstWhere((e) => e.id == taskId);
    return InternTask(
        id: t.id,
        title: t.title,
        status: status,
        dueDate: t.dueDate,
        description: t.description);
  }

  @override
  Future<Paged<JournalEntry>> listJournal(String internshipId,
      {int page = 0, int size = 20, JournalStatus? status}) async {
    final all = fixtureJournal(now);
    final items =
        status == null ? all : all.where((j) => j.status == status).toList();
    return pageOf(items, total: items.length);
  }

  @override
  Future<Paged<DeliverableSummary>> listDeliverables(String internshipId,
          {int page = 0, int size = 20}) async =>
      pageOf(dashboard.openDeliverables);

  @override
  Future<Paged<EvaluationSummary>> listEvaluations(String internshipId,
          {int page = 0, int size = 20}) async =>
      pageOf([
        if (dashboard.latestEvaluation != null)
          dashboard.latestEvaluation!,
      ]);

  @override
  Future<Paged<AppNotification>> listNotifications(
          {int page = 0, int size = 20}) async =>
      pageOf(dashboard.recentNotifications,
          total: dashboard.unreadNotifications);

  @override
  Future<int> unreadNotificationCount() async =>
      dashboard.unreadNotifications;

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<int> unreadMessageCount() async => dashboard.unreadMessages;
}
