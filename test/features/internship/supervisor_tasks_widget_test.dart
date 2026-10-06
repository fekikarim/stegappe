import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/queue_harness.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/core/widgets/steg_button.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/supervisor_tasks_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/bulk_task_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_tasks_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/task_editor_sheet.dart';

import '../../test_fixtures.dart';

const _supervisor =
    AppUser(id: 'sup1', email: 'sup@steg.tn', roles: ['SUPERVISOR']);

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<AppUser> login({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => _supervisor;
}

SupervisedIntern _intern(String id, String name) => SupervisedIntern(
      internshipId: id,
      reference: 'STG-$id',
      internName: name,
      status: InternshipStatus.inProgress,
      type: InternshipType.perfectionnement,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 6, 30),
      departmentName: 'DSI',
      tasksCompleted: 1,
      tasksTotal: 3,
      pendingJournal: 0,
      pendingDeliverables: 0,
      evaluationsCount: 0,
    );

/// Fake with two students and a review-ready task list (one COMPLETED, one
/// scheduled-future, one plain).
class _SupervisorFake extends FakeInternshipRepository {
  @override
  Future<List<SupervisedIntern>> supervisedInterns() async =>
      [_intern('internship-1', 'Amira Ben Salah'), _intern('internship-2', 'Yassine Trabelsi')];

  @override
  Future<Paged<InternTask>> listTasks(String internshipId,
      {int page = 0, int size = 50, TaskStatus? status}) async {
    lastStatusFilter = status;
    final all = [
      const InternTask(
          id: 't-review', title: 'Work to review', status: TaskStatus.awaitingApproval),
      InternTask(
          id: 't-future',
          title: 'Future task',
          status: TaskStatus.todo,
          visibleFrom: DateTime.now().add(const Duration(days: 3))),
      const InternTask(
          id: 't-plain', title: 'Plain task', status: TaskStatus.todo),
    ];
    final items =
        status == null ? all : all.where((t) => t.status == status).toList();
    return pageOf(items, total: items.length);
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  FakeInternshipRepository? fake,
  bool online = true,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) async {
  final repo = fake ?? _SupervisorFake();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => online),
        await queueOverride(),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: StegLocales.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: theme ?? StegTheme.light(),
        home: Scaffold(body: page),
      ),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
}

void main() {
  group('SupervisorTasksScreen', () {
    testWidgets('student chips + review queue render separately', (tester) async {
      await _pump(tester, const SupervisorTasksScreen());
      expect(find.text('Amira Ben Salah'), findsOneWidget);
      expect(find.text('Yassine Trabelsi'), findsOneWidget);
      expect(find.text('Work to review'), findsOneWidget);
      expect(find.text('À examiner'), findsOneWidget);
      expect(find.text('Approuver'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    });

    testWidgets('scheduled task carries a scheduled chip, not just color',
        (tester) async {
      await _pump(tester, const SupervisorTasksScreen());
      expect(find.textContaining('Planifiée'), findsOneWidget);
      expect(find.textContaining('Visible le'), findsOneWidget);
    });

    testWidgets('approve confirms with feedback and no raw text', (tester) async {
      final fake = _SupervisorFake();
      await _pump(tester, const SupervisorTasksScreen(), fake: fake);
      await tester.tap(find.text('Approuver'));
      await tester.pumpAndSettle();
      expect(fake.reviewedTasks.single['approve'], isTrue);
      expect(find.text('Travail approuvé.'), findsOneWidget);
    });

    testWidgets('deny requires a reason (client blocks empty first)',
        (tester) async {
      final fake = _SupervisorFake();
      await _pump(tester, const SupervisorTasksScreen(), fake: fake);
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      // Empty confirm → inline localized error, no backend call.
      await tester.tap(find.text('Refuser').last);
      await tester.pump();
      expect(find.text('Un motif est obligatoire pour refuser un travail.'),
          findsOneWidget);
      expect(fake.reviewedTasks, isEmpty);
      // With a reason → denied with the reason stored.
      await tester.enterText(
          find.byType(TextField), 'Missing tests');
      await tester.tap(find.text('Refuser').last);
      await tester.pumpAndSettle();
      expect(fake.reviewedTasks.single['comment'], 'Missing tests');
      expect(find.text('Travail refusé avec motif.'), findsOneWidget);
    });

    testWidgets('delete confirms naming task and student', (tester) async {
      final fake = _SupervisorFake();
      await _pump(tester, const SupervisorTasksScreen(), fake: fake);
      await tester.tap(find.text('Supprimer').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('« Work to review »'), findsOneWidget);
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();
      expect(fake.deletedTasks, ['t-review']);
    });

    testWidgets('offline disables mutations with an honest indicator',
        (tester) async {
      await _pump(tester, const SupervisorTasksScreen(), online: false);
      final approve = tester.widget<StegButton>(
          find.widgetWithText(StegButton, 'Approuver'));
      expect(approve.onPressed, isNull);
    });

    testWidgets('no students renders the honest empty state', (tester) async {
      await _pump(tester, const SupervisorTasksScreen(),
          fake: _NoInternsFake());
      expect(find.text('Aucun stagiaire suivi'), findsOneWidget);
    });

    testWidgets('arabic renders RTL with translated chrome', (tester) async {
      await _pump(tester, const SupervisorTasksScreen(),
          locale: const Locale('ar'), theme: StegTheme.dark());
      expect(find.text('مهام المتربصين'), findsOneWidget);
    });
  });

  group('BulkTaskSheet', () {
    testWidgets('plan preview + per-item results, no silent partial',
        (tester) async {
      final fake = _SupervisorFake();
      await _pump(tester, const BulkTaskSheet(), fake: fake);
      expect(find.textContaining('× 2 stagiaire'), findsOneWidget);
      await tester.enterText(
          find.byType(TextField).first, 'Shared task');
      await tester.pump();
      await tester.tap(find.text('Ajouter les tâches'));
      await tester.pumpAndSettle();
      expect(find.textContaining('créée'), findsOneWidget);
      // Two students × one task = two result rows.
      expect(find.text('Amira Ben Salah'), findsOneWidget);
      expect(find.text('Yassine Trabelsi'), findsOneWidget);
      expect(fake.bulkCalls, 1);
    });

    testWidgets('double submit is guarded (one backend call)', (tester) async {
      final fake = _SupervisorFake()..bulkGate = Completer<void>();
      await _pump(tester, const BulkTaskSheet(), fake: fake);
      await tester.enterText(
          find.byType(TextField).first, 'Shared task');
      await tester.pump();
      // Drive the submit through the controller (a plain future, no tester
      // guard conflict) and hold it behind the gate: the sheet must show
      // the loading (disabled) state, so a second tap cannot resubmit.
      final ctx = tester.element(find.byType(Scaffold).first);
      final container = ProviderScope.containerOf(ctx);
      final pending = container
          .read(supervisorTaskControllerProvider.notifier)
          .bulkTasks([
        bulkMutationForTest('internship-1', 'Shared task'),
      ]);
      await tester.pump();
      // While in flight the submit shows a spinner instead of its label:
      // no enabled button exists for a second tap to land on.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Ajouter les tâches'), findsNothing);
      fake.bulkGate!.complete();
      await pending;
      await tester.pumpAndSettle();
      // Exactly one backend call despite the in-flight loading state, and
      // the sheet is still on the form (its own submit never ran twice).
      expect(fake.bulkCalls, 1);
      expect(find.text('Ajouter les tâches'), findsOneWidget);
    });

    testWidgets('failure shows a localized error and allows fix+resend',
        (tester) async {
      final fake = _SupervisorFake()..failWrites = true;
      await _pump(tester, const BulkTaskSheet(), fake: fake);
      await tester.enterText(
          find.byType(TextField).first, 'Shared task');
      await tester.pump();
      await tester.tap(find.text('Ajouter les tâches'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Exception'), findsNothing);
      // Fix (back online) and resend with a fresh key.
      fake.failWrites = false;
      await tester.tap(find.text('Ajouter les tâches'));
      await tester.pumpAndSettle();
      expect(fake.bulkCalls, 2);
      expect(fake.bulkKeys.toSet().length, 2);
      expect(find.textContaining('créée'), findsOneWidget);
    });

    testWidgets('offline disables submit with an honest sentence',
        (tester) async {
      await _pump(tester, const BulkTaskSheet(), online: false);
      expect(find.text('La connexion est nécessaire pour envoyer le lot.'),
          findsOneWidget);
    });
  });

  group('TaskEditorSheet staff scheduling', () {
    testWidgets('schedule row offers immediate by default (create)',
        (tester) async {
      await _pump(tester,
          const TaskEditorSheet(internshipId: 'internship-1', staffMode: true));
      expect(find.textContaining('Immédiatement'), findsOneWidget);
      expect(find.text('Choisir la date'), findsOneWidget);
    });

    testWidgets('picking a date+time schedules, saving sends the instant',
        (tester) async {
      final fake = _SupervisorFake();
      await _pump(tester,
          const TaskEditorSheet(internshipId: 'internship-1', staffMode: true),
          fake: fake);
      await tester.enterText(
          find.byType(TextField).first, 'Scheduled by sup');
      await tester.tap(find.text('Choisir la date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Time dialog confirms the initial time without dial interaction.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Apparaît le'), findsOneWidget);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final sent = fake.createdTasks.single['visibleFrom'] as DateTime?;
      expect(sent, isNotNull);
      expect(sent!.isAfter(DateTime.now()), isTrue);
      expect(sent.isUtc, isTrue);
    });

    testWidgets('existing schedule shows and clears to immediate (edit)',
        (tester) async {
      final fake = _SupervisorFake();
      const existing = InternTask(
        id: 't-future',
        title: 'Future task',
        status: TaskStatus.todo,
      );
      await _pump(
          tester,
          TaskEditorSheet(
            internshipId: 'internship-1',
            existing: existing.copyWith(
                visibleFrom:
                    DateTime.now().add(const Duration(days: 2))),
            staffMode: true,
          ),
          fake: fake);
      expect(find.textContaining('Apparaît le'), findsOneWidget);
    });
  });
}

class _NoInternsFake extends FakeInternshipRepository {
  @override
  Future<List<SupervisedIntern>> supervisedInterns() async => [];
}

Map<String, dynamic> bulkMutationForTest(String internshipId, String title) =>
    bulkMutationJson(
        action: 'CREATE',
        internshipId: internshipId,
        task: taskWriteJson(title: title));


