import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/queue_harness.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/core/widgets/steg_button.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/domain/entities/task_drafts.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/task_drafts_screen.dart';

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

class _DraftsFake extends FakeInternshipRepository {
  @override
  Future<List<SupervisedIntern>> supervisedInterns() async => [
        _intern('internship-1', 'Amira Ben Salah'),
        _intern('internship-2', 'Yassine Trabelsi'),
      ];

  @override
  Future<Paged<InternTask>> listTasks(String internshipId,
      {int page = 0, int size = 50, TaskStatus? status}) async =>
      pageOf(const [], total: 0);
}

class _RateLimitedFake extends _DraftsFake {
  @override
  Future<List<TaskDraft>> generateDraftsFromText(String internshipId,
      {required String specText}) async {
    throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Rate limited',
        statusCode: 429,
        code: 'RATE_LIMIT_EXCEEDED');
  }
}

class _ForbiddenBulkFake extends _DraftsFake {
  @override
  Future<DraftBulkResult> bulkAddDrafts(
      {required List<String> draftIds,
      required List<String> internshipIds,
      required String idempotencyKey,
      DateTime? visibleFrom}) async {
    throw const ApiException(
        kind: ApiErrorKind.notFound,
        message: 'Not found',
        statusCode: 404,
        code: 'NOT_FOUND');
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
  final repo = fake ?? _DraftsFake();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWithValue(online),
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
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
}

void main() {
  group('TaskDraftsScreen idle + generation', () {
    testWidgets('idle shows proposal note, tabs, empty drafts, targets',
        (tester) async {
      await _pump(
          tester, const TaskDraftsScreen(referenceInternshipId: 'internship-1'));
      expect(
          find.textContaining('rien ne devient une tâche'), findsOneWidget);
      expect(find.text('Document PDF'), findsOneWidget);
      expect(find.text('Décrire'), findsOneWidget);
      expect(find.text('Aucun brouillon pour le moment'), findsOneWidget);
      // Both own students offered as targets, none outside the list.
      expect(find.text('Amira Ben Salah'), findsWidgets);
      expect(find.text('Yassine Trabelsi'), findsWidgets);
      // No drafts → bulk-add disabled (targets section is below the
      // fold in the 800x600 binding: scroll it into view first).
            final bulk = tester.widget<StegButton>(
          find.widgetWithText(StegButton, 'Créer les tâches'));
      expect(bulk.onPressed, isNull);
    });

    testWidgets('text flow generates reviewable drafts with badges',
        (tester) async {
      final fake = _DraftsFake();
      await _pump(tester,
          const TaskDraftsScreen(referenceInternshipId: 'internship-1'),
          fake: fake);
      await tester.enterText(
          find.byType(TextField).first, 'Set up the bench.');
      await tester.pump();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();
      expect(fake.generateCalls, 1);
      expect(find.text('Draft one'), findsOneWidget);
      expect(find.text('Draft two'), findsOneWidget);
      // Drafts render as proposals (badge), never as tasks.
      expect(find.text('Brouillon'), findsWidgets);
      expect(find.text('Modifier'), findsWidgets);
      expect(find.text('Réviser avec l’IA'), findsWidgets);
    });

    testWidgets('per-item edit / revise / delete drive the backend',
        (tester) async {
      final fake = _DraftsFake();
      await _pump(tester,
          const TaskDraftsScreen(referenceInternshipId: 'internship-1'),
          fake: fake);
      await tester.enterText(
          find.byType(TextField).first, 'Set up the bench.');
      await tester.pump();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();

      // Edit the first draft's title.
      await tester.tap(find.text('Modifier').first);
      await tester.pumpAndSettle();
      final editDialog = find.byType(AlertDialog);
      await tester.enterText(
          find.descendant(
              of: editDialog, matching: find.byType(TextField)).first,
          'Draft one v2');
      await tester.tap(find.text('Modifier').last);
      await tester.pumpAndSettle();
      expect(
          fake.fakeDrafts
              .firstWhere((d) => d.id == 'd1')
              .title,
          'Draft one v2');

      // Revise the second draft with an instruction.
            await tester.tap(find.text('Réviser avec l’IA').first);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField)),
          'More concrete');
      await tester.tap(find.text('Réviser avec l’IA').last);
      await tester.pumpAndSettle();
      expect(fake.revisedDrafts.single['instruction'], 'More concrete');

      // Delete the second draft with confirm.
            await tester.tap(find.text('Supprimer le brouillon').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer le brouillon').last);
      await tester.pumpAndSettle();
      expect(fake.deletedDrafts, ['d2']);
      expect(find.text('Draft two'), findsNothing);
    });

    testWidgets('manual add keeps working while AI is down', (tester) async {
      final fake = _DraftsFake()..failDrafts = true;
      await _pump(tester,
          const TaskDraftsScreen(referenceInternshipId: 'internship-1'),
          fake: fake);
      await tester.enterText(
          find.byType(TextField).first, 'Set up the bench.');
      await tester.pump();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();
      // Localized AI error + manual hint, never raw text.
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('Ajouter un brouillon à la main'), findsWidgets);
      // Manual path works despite the outage.
      await tester.tap(find.text('Ajouter un brouillon à la main').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Handmade');
      await tester.pump();
            await tester.tap(find.text('Ajouter un brouillon à la main').last);
      await tester.pumpAndSettle();
      expect(
          fake.fakeDrafts
              .where((d) => d.title == 'Handmade')
              .length,
          1);
    });

    testWidgets('rate limit shows the wait hint, offline disables generation',
        (tester) async {
      await _pump(tester,
          const TaskDraftsScreen(referenceInternshipId: 'internship-1'),
          fake: _RateLimitedFake());
      await tester.enterText(
          find.byType(TextField).first, 'Set up the bench.');
      await tester.pump();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();
            expect(find.textContaining('Patientez'), findsWidgets);

      await _pump(tester,
          const TaskDraftsScreen(referenceInternshipId: 'internship-1'),
          online: false);
      final generate = tester.widget<StegButton>(
          find.widgetWithText(StegButton, 'Générer'));
      expect(generate.onPressed, isNull);
      expect(find.text('La génération IA nécessite une connexion.'),
          findsOneWidget);
    });
  });

  group('TaskDraftsScreen bulk-add', () {
    testWidgets('targets + schedule + per-pair result, no silent partial',
        (tester) async {
      final fake = _DraftsFake();
      await _pump(tester,
          const TaskDraftsScreen(referenceInternshipId: 'internship-1'),
          fake: fake);
      await tester.enterText(
          find.byType(TextField).first, 'Set up the bench.');
      await tester.pump();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();

      // Reference student targeted by default; adding the second
      // student makes bulk-add create 2 drafts × 2 students.
      await tester.tap(find.text('Yassine Trabelsi').last);
      await tester.pump();
      await tester.tap(find.text('Créer les tâches'));
      await tester.pumpAndSettle();
      expect(fake.bulkDraftCalls, 1);
      expect(find.text('4 tâche(s) créée(s).'), findsOneWidget);
      expect(find.text('Amira Ben Salah'), findsWidgets);
      expect(find.text('Yassine Trabelsi'), findsWidgets);
    });

    testWidgets('out-of-scope bulk failure surfaces honestly', (tester) async {
      await _pump(tester,
          const TaskDraftsScreen(referenceInternshipId: 'internship-1'),
          fake: _ForbiddenBulkFake());
      await tester.enterText(
          find.byType(TextField).first, 'Set up the bench.');
      await tester.pump();
      await tester.tap(find.text('Générer'));
      await tester.pumpAndSettle();
            await tester.tap(find.text('Créer les tâches'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('arabic RTL with translated chrome', (tester) async {
      await _pump(tester,
          const TaskDraftsScreen(referenceInternshipId: 'internship-1'),
          locale: const Locale('ar'), theme: StegTheme.dark());
      // AppBar title + section header share the key (findsWidgets).
      expect(
          find.text('إنشاء مهام بالذكاء الاصطناعي'), findsWidgets);
      expect(find.text('الوصف'), findsOneWidget);
    });
  });
}
