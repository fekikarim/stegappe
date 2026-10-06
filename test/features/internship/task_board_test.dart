// T02 — board grouping contract (ST-TASK-01, AC1, task §Edge cases).
//
// The board is a pure function of the server page: four always-present
// groups with per-group counts, newest-first server order preserved, empty
// groups explained (never dropped), cancelled hidden by default, unknown
// values in their own group — never silently "To do".
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/domain/task_board.dart';

InternTask _t(
  String id,
  TaskStatus status, {
  String? title,
  String? description,
}) =>
    InternTask(
        id: id, title: title ?? 'T$id', status: status, description: description);

void main() {
  group('taskGroupOf (ST-TASK-01/06, BR-11/12)', () {
    test('attention gathers awaiting approval AND denial', () {
      expect(taskGroupOf(TaskStatus.awaitingApproval), TaskGroup.attention);
      expect(taskGroupOf(TaskStatus.denied), TaskGroup.attention);
    });

    test('done is approved only', () {
      expect(taskGroupOf(TaskStatus.approved), TaskGroup.done);
      // The historical lie: a COMPLETED task must never render as done.
      expect(taskGroupOf(TaskStatus.awaitingApproval), isNot(TaskGroup.done));
    });

    test('cancelled and unknown have their own groups', () {
      expect(taskGroupOf(TaskStatus.cancelled), TaskGroup.cancelled);
      expect(taskGroupOf(TaskStatus.unknown), TaskGroup.unknown);
    });
  });

  group('buildTaskBoard (AC1)', () {
    test('always renders the four primary groups, even empty', () {
      final sections = buildTaskBoard([]);
      expect(sections.map((s) => s.group),
          kBoardPrimaryGroups);
      for (final s in sections) {
        expect(s.isEmpty, isTrue);
        expect(s.count, 0);
      }
    });

    test('groups every task and keeps the server page order', () {
      final sections = buildTaskBoard([
        _t('1', TaskStatus.todo),
        _t('2', TaskStatus.inProgress),
        _t('3', TaskStatus.awaitingApproval),
        _t('4', TaskStatus.denied, title: 'Denied one'),
        _t('5', TaskStatus.approved),
        _t('6', TaskStatus.todo),
      ]);
      final byGroup = {for (final s in sections) s.group: s};
      expect(byGroup[TaskGroup.todo]!.tasks.map((t) => t.id), ['1', '6']);
      expect(byGroup[TaskGroup.inProgress]!.tasks.map((t) => t.id), ['2']);
      // COMPLETED and DENIED live together in attention, in page order.
      expect(byGroup[TaskGroup.attention]!.tasks.map((t) => t.id), ['3', '4']);
      expect(byGroup[TaskGroup.done]!.tasks.map((t) => t.id), ['5']);
    });

    test('counts reflect the tasks in each group', () {
      final sections = buildTaskBoard([
        _t('1', TaskStatus.todo),
        _t('2', TaskStatus.todo),
        _t('3', TaskStatus.approved),
      ]);
      final byGroup = {for (final s in sections) s.group: s};
      expect(byGroup[TaskGroup.todo]!.count, 2);
      expect(byGroup[TaskGroup.done]!.count, 1);
      expect(byGroup[TaskGroup.attention]!.count, 0);
    });

    test('unknown values surface in their own group, never todo', () {
      final sections = buildTaskBoard([_t('1', TaskStatus.unknown)]);
      final unknown = sections.singleWhere((s) => s.group == TaskGroup.unknown);
      expect(unknown.count, 1);
      final todo =
          sections.singleWhere((s) => s.group == TaskGroup.todo);
      expect(todo.isEmpty, isTrue);
    });

    test('cancelled is hidden by default', () {
      final sections = buildTaskBoard([
        _t('1', TaskStatus.todo),
        _t('2', TaskStatus.cancelled),
      ]);
      expect(sections.any((s) => s.group == TaskGroup.cancelled), isFalse);
    });

    test('cancelled appears when asked for', () {
      final sections = buildTaskBoard(
        [_t('1', TaskStatus.cancelled)],
        includeCancelled: true,
      );
      expect(sections.any((s) => s.group == TaskGroup.cancelled), isTrue);
    });

    test('cancelled alone is never silently swallowed (looks like data loss)',
        () {
      final sections = buildTaskBoard([_t('1', TaskStatus.cancelled)]);
      expect(sections.any((s) => s.group == TaskGroup.cancelled), isTrue);
    });
  });

  group('taskMatchesQuery (AC4 — search)', () {
    test('blank query matches everything', () {
      expect(taskMatchesQuery(_t('1', TaskStatus.todo), ''), isTrue);
      expect(taskMatchesQuery(_t('1', TaskStatus.todo), '   '), isTrue);
    });

    test('matches title and description, case-insensitively', () {
      final task = _t('1', TaskStatus.todo,
          title: 'Préparer la démo', description: 'Salle B12');
      expect(taskMatchesQuery(task, 'démo'), isTrue);
      expect(taskMatchesQuery(task, 'la démo'), isTrue);
      expect(taskMatchesQuery(task, 'b12'), isTrue);
      expect(taskMatchesQuery(task, 'B12'), isTrue);
      // Deliberately accent-sensitive: a simple contains, predictable on a
      // phone keyboard (no normalization, documented behaviour).
      expect(taskMatchesQuery(task, 'demo'), isFalse);
      expect(taskMatchesQuery(task, 'absent'), isFalse);
    });

    test('search filters the board, preserving always-present groups', () {
      final sections = buildTaskBoard([
        _t('1', TaskStatus.todo, title: 'Rapport'),
        _t('2', TaskStatus.todo, title: 'Démo'),
        _t('3', TaskStatus.approved, title: 'Rapport finale'),
      ], query: 'rapport');
      final todo = sections.singleWhere((s) => s.group == TaskGroup.todo);
      final done = sections.singleWhere((s) => s.group == TaskGroup.done);
      expect(todo.tasks.map((t) => t.id), ['1']);
      expect(done.tasks.map((t) => t.id), ['3']);
      expect(sections.map((s) => s.group), kBoardPrimaryGroups);
    });
  });
}
