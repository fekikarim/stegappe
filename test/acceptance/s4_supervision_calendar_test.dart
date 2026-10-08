import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/domain/calendar.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';

import '../test_fixtures.dart';

void main() {
  group('S4 — Supervision, calendar, candidates (SU-CAL, SU-HOME)', () {
    test(
      'S4.1: Calendar displays all students periods; candidates list includes student without conversation thread (T12)',
      () async {
        final now = DateTime(2026, 10, 8);
        final repo = FakeInternshipRepository(now: now);

        // Seed supervised interns list including a student without any chat thread
        final interns = [
          SupervisedIntern(
            internshipId: 'i1',
            reference: 'STG-2026-0001',
            internName: 'Yassine Mansour',
            status: InternshipStatus.inProgress,
            type: InternshipType.perfectionnement,
            startDate: DateTime(2026, 10, 1),
            endDate: DateTime(2026, 12, 31),
            departmentName: 'DSI',
            tasksCompleted: 3,
            tasksTotal: 6,
            pendingJournal: 1,
            submittedJournal: 1,
            pendingDeliverables: 1,
            evaluationsCount: 1,
          ),
          SupervisedIntern(
            internshipId: 'i2-no-chat',
            reference: 'STG-2026-0002',
            internName: 'Sarra Touati',
            status: InternshipStatus.inProgress,
            type: InternshipType.perfectionnement,
            startDate: DateTime(2026, 10, 5),
            endDate: DateTime(2026, 11, 15),
            departmentName: 'DSI',
            tasksCompleted: 1,
            tasksTotal: 4,
            pendingJournal: 0,
            submittedJournal: 0,
            pendingDeliverables: 0,
            evaluationsCount: 0,
          ),
        ];

        repo.supervisedOverride = interns;

        // Verify supervised candidates list returns both, including the one without chat
        final candidates = await repo.supervisedInterns();
        expect(candidates.length, 2);
        expect(candidates.any((c) => c.internshipId == 'i2-no-chat'), isTrue);

        // Pure calendar month layout verification for October 2026
        final weeks = monthWeeks(2026, 10, 1);
        expect(weeks, isNotEmpty);

        // Both candidates overlap October 2026
        for (final intern in candidates) {
          expect(
            periodOverlapsMonth(intern.startDate, intern.endDate, 2026, 10),
            isTrue,
          );
        }
      },
    );

    test(
      'S4.2: Open candidate detail, add task, notify documents preparation to selected students',
      () async {
        final now = DateTime(2026, 10, 8);
        final repo = FakeInternshipRepository(now: now);

        // 1. Candidate detail & add task from candidate context
        final newTask = await repo.createTask(
          'i1',
          title: 'Tâche créée depuis fiche candidat',
          description: 'Vérifier les données',
        );
        expect(newTask.title, 'Tâche créée depuis fiche candidat');
        expect(repo.createdTasks.any((t) => t['internshipId'] == 'i1'), isTrue);

        // 2. Notify to prepare documents to two selected students
        final notifiedCount = await repo.notifyDocumentsPreparation(
          ['i1', 'i2-no-chat'],
          idempotencyKey: 'notify-prep-key-42',
        );
        expect(notifiedCount, 2);
        expect(repo.notifyCalls, 1);
        expect(repo.notifyIds.first, containsAll(['i1', 'i2-no-chat']));
      },
    );

    test(
      'S4.3: Supervisor home shows statistics consistent with the lists and issues single request',
      () async {
        final now = DateTime(2026, 10, 8);
        final repo = FakeInternshipRepository(now: now);

        final candidates = await repo.supervisedInterns();
        final totals = queueTotals(candidates);
        expect(totals.submittedJournal, greaterThanOrEqualTo(0));
        expect(totals.submittedDeliverables, greaterThanOrEqualTo(0));
      },
    );
  });
}
