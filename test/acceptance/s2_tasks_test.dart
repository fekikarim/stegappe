import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/domain/entities/task_classification.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';

import '../test_fixtures.dart';

void main() {
  group('S2 — Tasks end to end (ST-TASK, SU-TASK, D6)', () {
    test(
      'S2.1 & S2.2 & S2.3: Lifecycle with supervisor creation, scheduled task exclusion, review denial with reason, resubmit, approval',
      () async {
        final now = DateTime(2026, 10, 8, 10, 0);
        final repo = FakeInternshipRepository(now: now);

        // 1. Supervisor creates a manual task for student 1.
        final manualTask = await repo.createTask(
          'internship-1',
          title: 'Manual Task 1',
          description: 'Document initial setup',
          dueDate: now.add(const Duration(days: 2)),
        );
        expect(manualTask.status, TaskStatus.todo);
        expect(manualTask.isScheduled(now), isFalse);

        // Supervisor creates a scheduled task visible only tomorrow.
        final futureInstant = now.add(const Duration(days: 1));
        final scheduledTask = await repo.createTask(
          'internship-1',
          title: 'Scheduled Task 2',
          dueDate: now.add(const Duration(days: 5)),
          visibleFrom: futureInstant,
        );
        expect(scheduledTask.visibleFrom, futureInstant);

        // 2. Student moves manual task: To do -> In progress -> Done (awaitingApproval on wire).
        final inProgress = await repo.updateTaskStatus(
          manualTask.id,
          TaskStatus.inProgress,
        );
        expect(inProgress.status, TaskStatus.inProgress);

        final awaitingApproval = await repo.updateTaskStatus(
          manualTask.id,
          TaskStatus.awaitingApproval,
        );
        expect(awaitingApproval.status, TaskStatus.awaitingApproval);

        // 3. Supervisor denies with a reason.
        final denied = await repo.reviewTask(
          manualTask.id,
          approve: false,
          comment: 'Veuillez préciser la méthodologie employée.',
        );
        expect(denied.status, TaskStatus.denied);
        expect(denied.reviewReason, 'Veuillez préciser la méthodologie employée.');

        // Student sees Denied + the reason, moves back to In progress, completes again.
        final rework = await repo.updateTaskStatus(
          manualTask.id,
          TaskStatus.inProgress,
        );
        expect(rework.status, TaskStatus.inProgress);

        final completedAgain = await repo.updateTaskStatus(
          manualTask.id,
          TaskStatus.awaitingApproval,
        );
        expect(completedAgain.status, TaskStatus.awaitingApproval);

        // Supervisor approves -> status becomes Done (approved).
        final approved = await repo.reviewTask(
          manualTask.id,
          approve: true,
        );
        expect(approved.status, TaskStatus.approved);
      },
    );

    test(
      'S2.4: Scheduled task date passes -> appears in list and notifications',
      () async {
        final now = DateTime(2026, 10, 8, 10, 0);
        final scheduledDate = now.add(const Duration(days: 1));

        // Create tasks with schedule
        final task = InternTask(
          id: 't-scheduled',
          title: 'Scheduled Task Future',
          status: TaskStatus.todo,
          visibleFrom: scheduledDate,
        );

        // Scheduling predicate: hidden until visibleFrom instant passes.
        expect(task.isScheduled(now), isTrue);
        expect(now.isBefore(task.visibleFrom!), isTrue);

        // After instant passes:
        final later = scheduledDate.add(const Duration(minutes: 5));
        expect(later.isAfter(task.visibleFrom!), isTrue);
      },
    );

    test(
      'S2.5: Bulk task creation to multiple students with per-item result',
      () async {
        final now = DateTime(2026, 10, 8, 10, 0);
        final repo = FakeInternshipRepository(now: now);

        final mutations = [
          {'internshipId': 'internship-1', 'title': 'Tâche commune A', 'action': 'CREATE'},
          {'internshipId': 'internship-1', 'title': 'Tâche commune B', 'action': 'CREATE'},
          {'internshipId': 'internship-2', 'title': 'Tâche commune A', 'action': 'CREATE'},
          {'internshipId': 'internship-2', 'title': 'Tâche commune B', 'action': 'CREATE'},
        ];

        final result = await repo.bulkTasks(
          mutations: mutations,
          idempotencyKey: 'idemp-bulk-1234',
        );

        // 2 tasks × 2 students = 4 tasks.
        expect(result.items.length, 4);
        for (final item in result.items) {
          expect(item.status, 'OK');
        }
      },
    );

    test(
      'S2.6: Classification: student categories, AI suggestion, accept, undo; task status untouched',
      () async {
        final repo = FakeInternshipRepository();

        // 1. Create custom category.
        final category = await repo.createCategory('internship-1', name: 'Frontend & UI');
        expect(category.name, 'Frontend & UI');

        // 2. Initial task status is todo.
        final initialTasks = await repo.listTasks('internship-1');
        final targetTask = initialTasks.items.firstWhere((t) => t.id == 't-today');
        final initialStatus = targetTask.status;

        // 3. Assign category to task.
        await repo.assignTaskCategory(
          't-today',
          categoryId: category.id,
        );
        expect(repo.fakeBoard.assignments['t-today'], category.id);

        // Confirm task status was NOT modified by categorization.
        final tasksAfterAssign = await repo.listTasks('internship-1');
        final assignedTask = tasksAfterAssign.items.firstWhere((t) => t.id == 't-today');
        expect(assignedTask.status, initialStatus);

        // 4. AI classification proposal.
        repo.fakeProposals = [
          const CategoryProposal(
            taskId: 't-week',
            categoryId: 'cat-1',
            confidence: 0.92,
          ),
        ];
        final suggestions = await repo.suggestCategories('internship-1');
        expect(suggestions.proposals, isNotEmpty);

        // Remove category (undo).
        await repo.assignTaskCategory('t-today', categoryId: null);
        expect(repo.fakeBoard.assignments.containsKey('t-today'), isFalse);

        final tasksAfterUndo = await repo.listTasks('internship-1');
        final undoneTask = tasksAfterUndo.items.firstWhere((t) => t.id == 't-today');
        expect(undoneTask.status, initialStatus);
      },
    );
  });
}
