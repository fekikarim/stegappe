import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/data/cache/composer_draft_store.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_composer_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_list_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_validations_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/task_list_screen.dart';

import '../../test_fixtures.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.user);
  final AppUser user;

  @override
  Future<AppUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => user;
}

Future<FakeInternshipRepository> pumpLoop(
  WidgetTester tester,
  Widget page, {
  AppUser user = const AppUser(
      id: 'u1', email: 'intern@u.tn', roles: ['INTERN']),
  FakeInternshipRepository? fake,
  MemoryComposerDraftStore? drafts,
  bool online = true,
  DateTime? selectedDay,
  List<Override> extra = const [],
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(user)),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => online),
        if (drafts != null)
          composerDraftStoreProvider.overrideWithValue(drafts),
        if (selectedDay != null)
          selectedDayProvider.overrideWith((ref) => selectedDay),
        ...extra,
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: StegLocales.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: StegTheme.light(),
        home: Scaffold(body: page),
      ),
    ),
  );
  // Drive auth to Authenticated (screens gate editing on the role).
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('task create/edit loop', () {
    testWidgets('FAB opens editor; empty title is rejected inline',
        (tester) async {
      final fake = FakeInternshipRepository();
      await pumpLoop(tester, const TaskListScreen(), fake: fake);

      await tester.tap(find.byTooltip('Nouvelle tâche'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle tâche'), findsWidgets);

      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      expect(find.text('Veuillez saisir un titre.'), findsOneWidget);
      expect(fake.createdTasks, isEmpty);
    });

    testWidgets('valid task is created on the server', (tester) async {
      final fake = FakeInternshipRepository();
      await pumpLoop(tester, const TaskListScreen(), fake: fake);

      await tester.tap(find.byTooltip('Nouvelle tâche'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Prep demo');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(fake.createdTasks.single['title'], 'Prep demo');
      expect(find.text('Tâche enregistrée.'), findsOneWidget);
    });

    testWidgets('failed toggle rolls back, never stuck confirmed',
        (tester) async {
      final fake = FakeInternshipRepository()..failWrites = true;
      await pumpLoop(tester, const TaskListScreen(), fake: fake);

      // Hold the server call so the optimistic frame is observable.
      fake.statusGate = Completer<void>();
      final box = find.byType(Checkbox).first;
      expect(tester.widget<Checkbox>(box).value, isFalse);
      await tester.tap(box);
      await tester.pump(); // optimistic frame
      expect(tester.widget<Checkbox>(box).value, isTrue);
      fake.statusGate!.complete(); // server rejects
      await tester.pumpAndSettle(); // rollback
      expect(tester.widget<Checkbox>(box).value, isFalse);
      expect(fake.statusUpdates, isEmpty);
    });
  });

  group('journal loop', () {
    testWidgets('composer autosaves locally, then creates + submits',
        (tester) async {
      final fake = FakeInternshipRepository();
      final drafts = MemoryComposerDraftStore();
      final day = DateTime.now();
      await pumpLoop(
        tester,
        JournalComposerScreen(internshipId: 'internship-1', day: day),
        fake: fake,
        drafts: drafts,
      );

      await tester.enterText(find.byType(TextField).first, 'Jour 3');
      await tester.enterText(find.byType(TextField).last, 'Fait X');
      await tester.pump(const Duration(milliseconds: 800));
      final saved = await drafts.load('internship-1', day);
      expect(saved?.title, 'Jour 3');

      await tester.tap(find.text('Soumettre pour validation'));
      await tester.pumpAndSettle();
      expect(fake.createdJournals.single['title'], 'Jour 3');
      expect(fake.submitted, contains('j-new'));
      expect(await drafts.load('internship-1', day), isNull);
    });

    testWidgets('day strip filters server-side; empty day is honest',
        (tester) async {
      final fake = FakeInternshipRepository(now: DateTime(2026, 9, 15));
      await pumpLoop(tester, const JournalListScreen(),
          fake: fake, selectedDay: DateTime(2026, 9, 15));
      // Only entries recorded on the selected day are shown.
      expect(find.text('Draft entry'), findsOneWidget);
      expect(find.text('Submitted entry'), findsNothing);

      // Jump a week back: no fixture entries there.
      await tester.tap(find.byTooltip('‹'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune entrée pour le moment.'), findsOneWidget);
    });

    testWidgets('detail shows comments + submit for drafts',
        (tester) async {
      final fake = FakeInternshipRepository(now: DateTime(2026, 9, 15));
      await pumpLoop(tester, const JournalListScreen(),
          fake: fake, selectedDay: DateTime(2026, 9, 15));

      await tester.tap(find.text('Draft entry'));
      await tester.pumpAndSettle();
      expect(find.text('Détail de l’entrée'), findsOneWidget);
      expect(
          find.text('Bien détaillé, continue.'), findsOneWidget);

      await tester.tap(find.text('Soumettre pour validation'));
      await tester.pumpAndSettle();
      expect(fake.submitted, contains('j-draft'));
    });
  });

  group('supervisor validation loop', () {
    const sup = AppUser(
        id: 's1', email: 'sup@steg.tn', roles: ['SUPERVISOR']);

    testWidgets('queue lists submitted entries', (tester) async {
      await pumpLoop(tester,
          const SupervisorValidationsScreen(),
          user: sup);
      expect(find.text('Submitted entry'), findsOneWidget);
      expect(find.textContaining('STG-2026-0001'), findsOneWidget);
    });

    testWidgets('reject requires a comment; then records decision',
        (tester) async {
      final fake = FakeInternshipRepository();
      await pumpLoop(tester,
          const SupervisorValidationsScreen(),
          user: sup,
          fake: fake);

      await tester.tap(find.text('Submitted entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demander une correction'));
      await tester.pumpAndSettle();

      // Empty comment is refused inline; nothing sent.
      await tester.tap(find.text('Demander une correction').last);
      await tester.pump();
      expect(find.text('Veuillez expliquer la correction demandée.'),
          findsOneWidget);
      expect(fake.decisions, isEmpty);

      await tester.enterText(find.byType(TextField).last, 'Ajoute les chiffres.');
      await tester.tap(find.text('Demander une correction').last);
      await tester.pumpAndSettle();
      expect(
          fake.decisions,
          contains(
              ('j-sub', 'REJECTED', 'Ajoute les chiffres.')));
      expect(find.text('Correction demandée.'), findsOneWidget);
    });

    testWidgets('offline decision visibly fails, never pretends success',
        (tester) async {
      final fake = FakeInternshipRepository()..failWrites = true;
      await pumpLoop(tester,
          const SupervisorValidationsScreen(),
          user: sup,
          fake: fake,
          online: false);

      await tester.tap(find.text('Submitted entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider').last);
      await tester.pumpAndSettle();
      // Dialog stays open with the failure; queue unchanged.
      expect(find.text('Réviser l’entrée'), findsOneWidget);
      expect(find.text('Exception: offline'), findsOneWidget);
      expect(fake.decisions, isEmpty);
    });
  });
}
