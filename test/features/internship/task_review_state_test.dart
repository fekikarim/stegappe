// T02 — review state on the wire + honest labels (BR-11/BR-12, AC2).
//
// The backend `TaskResponse` carries `reviewReason` (and NOT `reviewedAt`,
// which is entity-only today): the mobile DTO must read the reason and stay
// tolerant when the date is absent. Writing never sends an unknown status.
// The labels must never call a task under review "done".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/widgets/steg_status_chip.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/domain/task_board.dart';
import 'package:stegappe/features/internship/presentation/widgets/status_labels.dart';

AppLocalizations _l10n(String code) => AppLocalizations(Locale(code));

void main() {
  group('taskFromJson reads the review fields (BR-12)', () {
    test('a denied payload carries the supervisor reason', () {
      final task = taskFromJson(const {
        'id': 't1',
        'internshipId': 'i1',
        'createdById': 'sup-1',
        'title': 'Rapport',
        'status': 'DENIED',
        'reviewReason': 'Titre trop vague',
      });
      expect(task.status, TaskStatus.denied);
      expect(task.denialReason, 'Titre trop vague');
      expect(task.createdById, 'sup-1');
      // reviewedAt is entity-only today — the DTO stays tolerant (null).
      expect(task.reviewedAt, isNull);
    });

    test('a completed payload reads as awaiting approval with completedAt', () {
      final task = taskFromJson(const {
        'id': 't2',
        'internshipId': 'i1',
        'createdById': 'u1',
        'title': 'Démo',
        'status': 'COMPLETED',
        'completedAt': '2026-10-06T09:30:00Z',
      });
      expect(task.status, TaskStatus.awaitingApproval);
      expect(task.awaitsReview, isTrue);
      expect(task.completedAt, isNotNull);
    });

    test('missing status degrades to unknown, never todo', () {
      final task = taskFromJson(const {
        'id': 't3',
        'internshipId': 'i1',
        'title': 'Legacy',
      });
      expect(task.status, TaskStatus.unknown);
    });

    test('reviewedAt is parsed when a newer backend exposes it', () {
      final task = taskFromJson(const {
        'id': 't4',
        'internshipId': 'i1',
        'title': 'Rapport',
        'status': 'APPROVED',
        'reviewReason': 'ok',
        'reviewedAt': '2026-10-05T14:00:00Z',
      });
      expect(task.status, TaskStatus.approved);
      expect(task.isDone, isTrue);
      expect(task.reviewedAt, isNotNull);
    });
  });

  group('taskWriteJson never sends an unknown status', () {
    test('unknown is omitted; every known value is encoded', () {
      final base = taskWriteJson(
        title: 'T',
        description: 'D',
        dueDate: DateTime(2026, 10, 10),
        status: TaskStatus.unknown,
      );
      expect(base.containsKey('status'), isFalse,
          reason: 'unknown is not backend vocabulary — never sent');
      expect(
        taskWriteJson(
          title: 'T',
          description: 'D',
          dueDate: DateTime(2026, 10, 10),
          status: TaskStatus.awaitingApproval,
        )['status'],
        'COMPLETED',
      );
      expect(
        taskWriteJson(
          title: 'T',
          description: 'D',
          dueDate: DateTime(2026, 10, 10),
          status: TaskStatus.approved,
        )['status'],
        'APPROVED',
      );
    });
  });

  group('labels never lie about done (AC2, BR-11)', () {
    test('the board groups have honest fr labels and kinds', () {
      final l10n = _l10n('fr');
      expect(taskGroupLabel(TaskGroup.todo, l10n), 'À faire');
      expect(taskGroupLabel(TaskGroup.inProgress, l10n), 'En cours');
      expect(taskGroupLabel(TaskGroup.attention, l10n), 'À surveiller');
      expect(taskGroupLabel(TaskGroup.done, l10n), 'Terminées');
      expect(taskGroupKind(TaskGroup.attention), StegStatusKind.warning);
      expect(taskGroupKind(TaskGroup.done), StegStatusKind.success);
    });

    test('COMPLETED is labelled awaiting approval, never done', () {
      final fr = _l10n('fr');
      final en = _l10n('en');
      final ar = _l10n('ar');
      expect(
        taskStatusLabel(TaskStatus.awaitingApproval, fr),
        'En attente de validation',
      );
      expect(taskStatusLabel(TaskStatus.awaitingApproval, en),
          isNot(taskStatusLabel(TaskStatus.approved, en)));
      expect(
        taskStatusLabel(TaskStatus.awaitingApproval, ar),
        isNot(taskStatusLabel(TaskStatus.approved, ar)),
      );
      expect(
        taskStatusKind(TaskStatus.awaitingApproval, overdue: false),
        StegStatusKind.warning,
      );
      expect(
        taskStatusKind(TaskStatus.approved, overdue: false),
        StegStatusKind.success,
      );
      expect(
        taskStatusKind(TaskStatus.denied, overdue: false),
        StegStatusKind.error,
      );
    });

    test('transition labels describe the student action honestly', () {
      final fr = _l10n('fr');
      // Submitting for review must not read as "mark done".
      expect(
        taskTransitionLabel(
            TaskStatus.inProgress, TaskStatus.awaitingApproval, fr),
        isNot('Terminée'),
      );
      expect(
        taskTransitionLabel(TaskStatus.denied, TaskStatus.inProgress, fr),
        'Reprendre',
      );
    });
  });
}
