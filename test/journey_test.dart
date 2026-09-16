import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

import 'test_fixtures.dart';
import 'features/messaging/messaging_widget_test.dart'
    show FakeMessagingRepo, FakeNotifRepo, FakeStomp;
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';

class _JourneyAuth implements AuthRepository {
  @override
  Future<AppUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => const AppUser(
      id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);
}

/// Full business loop through the REAL providers with fakes behind
/// them: login → today's tasks → journal → validation → deliverable →
/// message → evaluation → logbook draft.
///
/// NOTE: supervisor-only transitions (validate/reject) are exercised at
/// the repository contract level here; the live backend enforces
/// `isSupervisorOf` per request (verified in D2/D4 probes).
void main() {
  test('intern daily-work journey across providers', () async {
    final internshipRepo = FakeInternshipRepository();
    final stomp = FakeStomp();
    stomp.setState(ChatConnectionState.connected);
    final messagingRepo = FakeMessagingRepo(stomp: stomp);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_JourneyAuth()),
        internshipRepositoryProvider
            .overrideWithValue(internshipRepo),
        messagingRepositoryProvider
            .overrideWithValue(messagingRepo),
        notificationRepositoryProvider
            .overrideWithValue(FakeNotifRepo()),
        stompChatServiceProvider.overrideWithValue(stomp),
      ],
    );
    addTearDown(container.dispose);

    // 1. Login + session restore.
    await container
        .read(authControllerProvider.notifier)
        .bootstrap();
    final auth = container.read(authControllerProvider);
    expect(auth, isA<AuthAuthenticated>());
    expect((auth as AuthAuthenticated).user.mobileRole,
        UserRole.intern);

    // 2. Today's tasks from the dashboard aggregate.
    final internshipId =
        await container.read(myInternshipIdProvider.future);
    expect(internshipId, 'internship-1');
    final dashboard =
        await container.read(dashboardProvider.future);
    expect(
        dashboard.todayTasks.any((t) => t.id == 't-today'), isTrue);

    // 3. Real-life meeting → planned task → completed task.
    final created = await internshipRepo.createTask(internshipId!,
        title: 'Préparer la démo', dueDate: DateTime.now());
    expect(created.status, TaskStatus.todo);
    final done = await internshipRepo.updateTaskStatus(
        created.id, TaskStatus.completed);
    expect(done.status, TaskStatus.completed);

    // 4. Journal: record what actually happened, then submit.
    final entry = await internshipRepo.createJournal(internshipId,
        title: 'Journée démo',
        description: 'Préparé et présenté la démo.',
        entryDate: DateTime.now());
    expect(entry.status, JournalStatus.draft);
    final submitted =
        await internshipRepo.submitJournal(entry.id);
    expect(submitted.status, JournalStatus.submitted);

    // 5. Supervisor validation (contract-level; backend gates by role).
    final validated = await internshipRepo.validateJournal(
        'j-sub', 'Bien documenté.');
    expect(validated.status, JournalStatus.validated);

    // 6. Deliverable: create with file → submit.
    final deliv = await internshipRepo.createDeliverable(
      internshipId,
      title: 'Démo',
      fileName: 'demo.pdf',
      fileBytes: _pdfBytes(),
    );
    expect(deliv.status, DeliverableStatus.draft);
    expect(deliv.currentVersion, 1);
    final submittedDeliv =
        await internshipRepo.submitDeliverable(deliv.id);
    expect(submittedDeliv.status, isNotNull);

    // 7. Message to the supervisor over the live socket path.
    final sent =
        await messagingRepo.send('c1', 'Bonjour, démo prête !');
    // STOMP-connected fake: echo arrives via broadcast (null here).
    expect(sent, isNull);
    expect(stomp.sent, contains('Bonjour, démo prête !'));
    // 8. Evaluation authored from the backend template + criteria.
    final templates = await internshipRepo.listTemplates();
    expect(templates.map((t) => t.id), contains('t1'));
    final criteria =
        await internshipRepo.templateCriteria('t1');
    expect(criteria.map((c) => c.id),
        containsAll(['c-tech', 'c-soft']));
    final evaluation = await internshipRepo.createEvaluation(
      internshipId,
      templateId: 't1',
      kind: EvaluationKind.weekly,
      date: DateTime.now(),
      feedback: 'Bonne progression.',
    );
    await internshipRepo.submitScores(evaluation.id, [
      {'criterionId': 'c-tech', 'score': 15},
      {'criterionId': 'c-soft', 'score': 16},
    ]);
    await internshipRepo.addTaskReview(evaluation.id, {
      'taskId': 't-done',
      'completed': true,
      'score': 16,
    });
    final detail =
        await internshipRepo.evaluationDetail(evaluation.id);
    expect(detail.totalScore, 15.0); // authoritative server value

    // 9. Advisory logbook draft from recorded data (review-only).
    final draft =
        await internshipRepo.generateLogbookDraft(internshipId);
    expect(draft.draftText, isNotEmpty);
    expect(draft.cinExcluded, isTrue);
    expect(draft.recommendations, isNotEmpty);
  });
}

Uint8List _pdfBytes() => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
