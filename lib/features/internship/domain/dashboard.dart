import 'entities/internship.dart';
import 'entities/work_items.dart';

/// Aggregated dashboard snapshot. Pure function of backend data +
/// "today" — no invented metrics. Counts prefer backend `totalElements`
/// (full collection) over the fetched page size.
class DashboardData {
  const DashboardData({
    required this.internship,
    required this.assignments,
    required this.activeAssignment,
    required this.todayTasks,
    required this.overdueTasks,
    required this.weekTasks,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.extraTasks,
    required this.pendingJournal,
    required this.pendingJournalTotal,
    required this.openDeliverables,
    required this.latestEvaluation,
    required this.recentNotifications,
    required this.unreadNotifications,
    required this.unreadMessages,
    required this.now,
  });

  final Internship internship;
  final List<InternshipAssignment> assignments;
  final InternshipAssignment? activeAssignment;
  final List<InternTask> todayTasks;
  final List<InternTask> overdueTasks;
  final List<InternTask> weekTasks;

  /// Completed/total across the WHOLE backend collection.
  final int tasksCompleted;
  final int tasksTotal;
  final int extraTasks; // totalElements beyond the fetched page

  final List<JournalEntry> pendingJournal;
  final int pendingJournalTotal;
  final List<DeliverableSummary> openDeliverables;
  final EvaluationSummary? latestEvaluation;
  final List<AppNotification> recentNotifications;
  final int unreadNotifications;
  final int unreadMessages;
  final DateTime now;

  /// Share of backend-reported tasks completed. Null when there is
  /// nothing to measure (never fabricated).
  double? get tasksFraction =>
      tasksTotal == 0 ? null : tasksCompleted / tasksTotal;

  double get timelineFraction => internship.timelineFraction(now);

  bool get hasAttention =>
      overdueTasks.isNotEmpty ||
      pendingJournalTotal > 0 ||
      unreadNotifications > 0;
}

class DashboardInput {
  const DashboardInput({
    required this.internship,
    required this.assignments,
    required this.tasks,
    required this.tasksCompletedTotal,
    required this.tasksGrandTotal,
    required this.journal,
    required this.pendingJournalTotal,
    required this.deliverables,
    required this.evaluations,
    required this.notifications,
    required this.unreadNotifications,
    required this.unreadMessages,
    required this.now,
  });

  final Internship internship;
  final List<InternshipAssignment> assignments;
  final List<InternTask> tasks;
  final int tasksCompletedTotal;
  final int tasksGrandTotal;
  final List<JournalEntry> journal;
  final int pendingJournalTotal;
  final List<DeliverableSummary> deliverables;
  final List<EvaluationSummary> evaluations;
  final List<AppNotification> notifications;
  final int unreadNotifications;
  final int unreadMessages;
  final DateTime now;
}

bool _inWeek(DateTime d, DateTime now) {
  final start = now.subtract(Duration(days: now.weekday - 1));
  final s = DateTime(start.year, start.month, start.day);
  final e = s.add(const Duration(days: 7));
  final day = DateTime(d.year, d.month, d.day);
  return !day.isBefore(s) && day.isBefore(e);
}

/// Pure aggregation — unit-tested, no widgets, no I/O.
DashboardData buildDashboard(DashboardInput input) {
  final now = input.now;
  final open = input.tasks.where((t) => t.isOpen).toList();

  final today = open.where((t) => t.isDueToday(now)).toList()
    ..sort(_byDue);
  final overdue = open.where((t) => t.isOverdue(now)).toList()
    ..sort(_byDue);
  final week = open
      .where((t) =>
          t.dueDate != null &&
          !t.isDueToday(now) &&
          !t.isOverdue(now) &&
          _inWeek(t.dueDate!, now))
      .toList()
    ..sort(_byDue);

  final pending = input.journal.where((j) => j.needsAttention).toList();
  final openDelivs = input.deliverables
      .where((d) => d.status != DeliverableStatus.validated)
      .take(3)
      .toList();

  InternshipAssignment? active;
  for (final a in input.assignments) {
    if (a.isActive) {
      active = a;
      break;
    }
  }

  final extra = (input.tasksGrandTotal - input.tasks.length)
      .clamp(0, 1 << 30);

  return DashboardData(
    internship: input.internship,
    assignments: input.assignments,
    activeAssignment: active,
    todayTasks: today,
    overdueTasks: overdue,
    weekTasks: week,
    tasksCompleted: input.tasksCompletedTotal,
    tasksTotal: input.tasksGrandTotal,
    extraTasks: extra,
    pendingJournal: pending,
    pendingJournalTotal: input.pendingJournalTotal,
    openDeliverables: openDelivs,
    latestEvaluation:
        input.evaluations.isEmpty ? null : input.evaluations.first,
    recentNotifications: input.notifications.take(5).toList(),
    unreadNotifications: input.unreadNotifications,
    unreadMessages: input.unreadMessages,
    now: now,
  );
}

int _byDue(InternTask a, InternTask b) {
  final da = a.dueDate;
  final db = b.dueDate;
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
}
