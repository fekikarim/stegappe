// T02 — status model contract (BR-10, BR-11, BR-13, BR-14, ST-TASK-02/07).
//
// Proves the mapping fix bites: the historical defect mapped `APPROVED` and
// `DENIED` to the `todo` default. Every backend value of
// `companion/domain/model/TaskStatus.java` must decode to its own mobile value,
// `COMPLETED` must be "awaiting approval" (never done), an unknown value must
// surface as `unknown`, and the student may only ever target his own
// progress states.
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';

InternTask _task({TaskStatus status = TaskStatus.todo, String? createdBy}) =>
    InternTask(id: 't1', title: 'T', status: status, createdById: createdBy);

void main() {
  group('taskStatusFrom maps every backend value (BR-10)', () {
    test('six known wire values decode explicitly', () {
      expect(taskStatusFrom('TODO'), TaskStatus.todo);
      expect(taskStatusFrom('IN_PROGRESS'), TaskStatus.inProgress);
      // COMPLETED is the student's "finished my part", not done (BR-11).
      expect(taskStatusFrom('COMPLETED'), TaskStatus.awaitingApproval);
      expect(taskStatusFrom('APPROVED'), TaskStatus.approved);
      expect(taskStatusFrom('DENIED'), TaskStatus.denied);
      expect(taskStatusFrom('CANCELLED'), TaskStatus.cancelled);
    });

    test('decoding is case/whitespace tolerant', () {
      expect(taskStatusFrom('approved'), TaskStatus.approved);
      expect(taskStatusFrom(' in_progress '), TaskStatus.inProgress);
    });

    test('unknown or absent value never becomes todo (defect fix)', () {
      expect(taskStatusFrom('SOMETHING_NEW'), TaskStatus.unknown);
      expect(taskStatusFrom(''), TaskStatus.unknown);
      expect(taskStatusFrom(null), TaskStatus.unknown);
    });

    test('round-trip: every mobile value encodes back to its wire name', () {
      for (final s in TaskStatus.values) {
        final wire = taskStatusToApi(s);
        if (s == TaskStatus.unknown) {
          expect(wire, isNull,
              reason: 'unknown is not backend vocabulary — never sent');
        } else {
          expect(taskStatusFrom(wire), s);
        }
      }
    });
  });

  group('done semantics (BR-11, A2/D6)', () {
    test('only APPROVED is done; COMPLETED awaits review', () {
      expect(_task(status: TaskStatus.approved).isDone, isTrue);
      expect(_task(status: TaskStatus.awaitingApproval).isDone, isFalse);
      expect(_task(status: TaskStatus.awaitingApproval).awaitsReview, isTrue);
      expect(_task(status: TaskStatus.denied).needsAttention, isTrue);
    });

    test('denial reason is surfaced trimmed, never as an empty string', () {
      expect(_task(status: TaskStatus.denied).denialReason, isNull);
      expect(
        InternTask(
          id: 't',
          title: 'T',
          status: TaskStatus.denied,
          reviewReason: '  ',
        ).denialReason,
        isNull,
      );
      expect(
        InternTask(
          id: 't',
          title: 'T',
          status: TaskStatus.denied,
          reviewReason: '  titre trop vague  ',
        ).denialReason,
        'titre trop vague',
      );
    });
  });

  group('student transitions (ST-TASK-02, BR-13)', () {
    test('forward path todo → in progress → awaiting approval', () {
      expect(
          studentTransitionsFrom(TaskStatus.todo), [TaskStatus.inProgress]);
      expect(studentTransitionsFrom(TaskStatus.inProgress),
          [TaskStatus.awaitingApproval]);
    });

    test('a completion can be withdrawn and a denial is actionable again', () {
      expect(studentTransitionsFrom(TaskStatus.awaitingApproval),
          [TaskStatus.inProgress]);
      expect(
          studentTransitionsFrom(TaskStatus.denied), [TaskStatus.inProgress]);
    });

    test(
        'student is never offered the supervisor/staff decisions '
        '(APPROVED/DENIED/CANCELLED)', () {
      for (final s in TaskStatus.values) {
        if (s == TaskStatus.unknown) continue;
        for (final target in studentTransitionsFrom(s)) {
          expect(
            target,
            anyOf(
              TaskStatus.todo,
              TaskStatus.inProgress,
              TaskStatus.awaitingApproval,
            ),
            reason: '$s must not offer staff state $target to a student',
          );
          expect(isStudentStatusTarget(target), isTrue);
        }
      }
      // Terminal states expose no transition at all.
      expect(studentTransitionsFrom(TaskStatus.approved), isEmpty);
      expect(studentTransitionsFrom(TaskStatus.cancelled), isEmpty);
      expect(studentTransitionsFrom(TaskStatus.unknown), isEmpty);
    });

    test('single row control matches the transition table', () {
      expect(
          studentToggleTarget(TaskStatus.todo), TaskStatus.awaitingApproval);
      expect(studentToggleTarget(TaskStatus.inProgress),
          TaskStatus.awaitingApproval);
      expect(studentToggleTarget(TaskStatus.awaitingApproval),
          TaskStatus.inProgress);
      expect(studentToggleTarget(TaskStatus.denied), TaskStatus.inProgress);
      expect(studentToggleTarget(TaskStatus.approved), isNull);
      expect(studentToggleTarget(TaskStatus.cancelled), isNull);
      expect(studentToggleTarget(TaskStatus.unknown), isNull);
    });
  });

  group('BR-14 authorship gating', () {
    test('the author edits his task; anyone else does not', () {
      final own = _task(createdBy: 'u1');
      expect(studentOwnsTask(own, 'u1'), isTrue);
      expect(studentOwnsTask(own, 'u2'), isFalse);
    });

    test('unknown authorship is treated as supervisor-authored', () {
      final legacy = _task(createdBy: null);
      expect(studentOwnsTask(legacy, 'u1'), isFalse);
      expect(studentOwnsTask(legacy, null), isFalse);
    });
  });

  group('overdue/due-today display facts (BR-21)', () {
    test('only open tasks can be overdue', () {
      final now = DateTime(2026, 10, 6);
      expect(
        _task(createdBy: 'u')
            .copyWith(dueDate: DateTime(2026, 10, 4))
            .isOverdue(now),
        isTrue,
      );
      // A denied task is actionable again but is not displayed as overdue.
      expect(
        _task(status: TaskStatus.denied)
            .copyWith(dueDate: DateTime(2026, 10, 4))
            .isOverdue(now),
        isFalse,
      );
      expect(
        _task(status: TaskStatus.approved)
            .copyWith(dueDate: DateTime(2026, 10, 4))
            .isOverdue(now),
        isFalse,
      );
    });
  });
}
