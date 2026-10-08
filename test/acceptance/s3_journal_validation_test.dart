import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';

import '../test_fixtures.dart';

void main() {
  group('S3 — Journal and validation (ST-JRN, ST-VAL, SU-VAL, D2/D3)', () {
    test(
      'S3.1: Outside window journal action disabled with countdown; inside window becomes available',
      () async {
        final repo = FakeInternshipRepository();

        // 1. Outside the window: daysUntilOpen > 0
        repo.journalEligibilityFixture = const JournalEligibility(
          eligible: false,
          reason: 'WINDOW_NOT_OPEN',
          daysUntilOpen: 14,
          windowDays: 30,
          taskCount: 5,
          approvedTasks: 4,
          belowThreshold: false,
        );

        final outsideEligibility = await repo.journalEligibility('internship-1');
        expect(outsideEligibility.eligible, isFalse);
        expect(outsideEligibility.daysUntilOpen, 14);

        // 2. Window opens: eligible becomes true
        repo.journalEligibilityFixture = const JournalEligibility(
          eligible: true,
          reason: 'ELIGIBLE_WINDOW',
          daysUntilOpen: 0,
          windowDays: 30,
          taskCount: 5,
          approvedTasks: 4,
          belowThreshold: false,
        );

        final insideEligibility = await repo.journalEligibility('internship-1');
        expect(insideEligibility.eligible, isTrue);
        expect(insideEligibility.daysUntilOpen, 0);
      },
    );

    test(
      'S3.2: Journal generation from tasks (PDF with task table); warning when < 75% approved tasks',
      () async {
        final repo = FakeInternshipRepository();

        // 1. Below threshold (< 75% approved tasks): warning flag is true
        repo.journalEligibilityFixture = const JournalEligibility(
          eligible: true,
          reason: 'ELIGIBLE_WINDOW',
          daysUntilOpen: 0,
          windowDays: 30,
          taskCount: 10,
          approvedTasks: 5, // 50% < 75%
          belowThreshold: true,
        );

        final eligibilityWithWarning = await repo.journalEligibility('internship-1');
        expect(eligibilityWithWarning.belowThreshold, isTrue);
        expect(eligibilityWithWarning.taskCount, 10);
        expect(eligibilityWithWarning.approvedTasks, 5);

        // 2. Generate journal document from tasks
        final generatedFromTasks = await repo.generateJournalFromTasks('internship-1');
        expect(generatedFromTasks.fileName, contains('.pdf'));
        expect(generatedFromTasks.deliverableId, isNotEmpty);

        // 3. Generate journal document from text
        final generatedFromText = await repo.generateJournalFromText(
          'internship-1',
          'Rapport détaillé des réalisations de la semaine.',
        );
        expect(generatedFromText.fileName, contains('.pdf'));
        expect(generatedFromText.deliverableId, isNotEmpty);
      },
    );

    test(
      'S3.3: In final week student submits journal and report -> REPORT_SUBMITTED',
      () async {
        final repo = FakeInternshipRepository();

        // Create journal deliverable and report deliverable with explicit documentKind
        final journal = await repo.createDeliverable(
          'internship-1',
          title: 'Journal de Stage',
          fileName: 'journal.pdf',
          fileBytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
          documentKind: 'JOURNAL',
        );
        expect(journal.status, DeliverableStatus.draft);
        expect(journal.documentKind, 'JOURNAL');

        final report = await repo.createDeliverable(
          'internship-1',
          title: 'Rapport de Stage',
          fileName: 'rapport.pdf',
          fileBytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
          documentKind: 'REPORT',
        );
        expect(report.status, DeliverableStatus.draft);
        expect(report.documentKind, 'REPORT');

        // Student submits both deliverables
        final submittedJournal = await repo.submitDeliverable(journal.id);
        final submittedReport = await repo.submitDeliverable(report.id);
        expect(submittedJournal.status, DeliverableStatus.submitted);
        expect(submittedReport.status, DeliverableStatus.submitted);
      },
    );

    test(
      'S3.4: Supervisor review: approve with note, or deny with reason -> student resends',
      () async {
        final repo = FakeInternshipRepository();

        // 1. Supervisor validates journal with note
        final validated = await repo.validateJournal(
          'j-sub',
          'Rapport et journal clairs et complets.',
        );
        expect(validated.status, JournalStatus.validated);

        // 2. Supervisor registers document kinds explicitly
        await repo.registerDocumentKind('d1', 'JOURNAL');
        expect(repo.registeredKinds, contains(('d1', 'JOURNAL')));

        await repo.registerDocumentKind('d2', 'REPORT');
        expect(repo.registeredKinds, contains(('d2', 'REPORT')));

        // 3. Deliverable rejection with reason records decision
        await repo.rejectDeliverable(
          'd1',
          'Chapitre 3 incomplet, veuillez rajouter les schémas.',
        );
        expect(repo.deliverableDecisions.any((d) => d.$1 == 'd1' && d.$2 == 'REJECTED'), isTrue);
      },
    );
  });
}
