import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/domain/dashboard.dart';

import '../../test_fixtures.dart';

void main() {
  group('buildDashboard', () {
    test('splits planned work into today/overdue/week', () {
      final now = DateTime(2026, 9, 15); // a Tuesday
      final data = fixtureDashboard(now);

      expect(data.todayTasks.map((t) => t.id), ['t-today']);
      expect(data.overdueTasks.map((t) => t.id), ['t-overdue']);
      expect(data.weekTasks.map((t) => t.id), ['t-week']);
      // Completed work is not planned work anymore.
      expect(
          [...data.todayTasks, ...data.overdueTasks, ...data.weekTasks]
              .any((t) => t.id == 't-done'),
          isFalse);
    });

    test('keeps Task / Journal / Evaluation distinct', () {
      final now = DateTime(2026, 9, 15);
      final data = fixtureDashboard(now);

      // Journal pending = DRAFT entries only (submitted awaits supervisor,
      // validated is history) — counted from backend totals.
      expect(data.pendingJournal.map((j) => j.id), ['j-draft']);
      expect(data.pendingJournalTotal, 1);
      // Evaluation is assessment, surfaced separately with backend score.
      expect(data.latestEvaluation?.totalScore, 15.5);
      // No task content leaks into journal and vice versa.
      expect(data.todayTasks.any((t) => t.id.startsWith('j-')), isFalse);
    });

    test('progress uses backend totals, never invented', () {
      final now = DateTime(2026, 9, 15);
      final data = fixtureDashboard(now);

      expect(data.tasksCompleted, 1);
      expect(data.tasksTotal, 4);
      expect(data.tasksFraction, 0.25);
      expect(data.timelineFraction,
          data.internship.timelineFraction(now));
    });

    test('tasksFraction is null when nothing to measure', () {
      final now = DateTime(2026, 9, 15);
      final input = DashboardInput(
        internship: fixtureInternship(now),
        assignments: const [],
        tasks: const [],
        tasksCompletedTotal: 0,
        tasksGrandTotal: 0,
        journal: const [],
        pendingJournalTotal: 0,
        deliverables: const [],
        evaluations: const [],
        notifications: const [],
        unreadNotifications: 0,
        unreadMessages: 0,
        now: now,
      );
      expect(buildDashboard(input).tasksFraction, isNull);
    });

    test('timeline math clamps outside the period', () {
      final i = fixtureInternship(DateTime(2026, 9, 15));
      expect(i.timelineFraction(DateTime(2020, 1, 1)), 0.0);
      expect(i.timelineFraction(DateTime(2030, 1, 1)), 1.0);
      expect(i.elapsedDays(DateTime(2020, 1, 1)), 0);
    });
  });
}
