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
import 'package:stegappe/features/internship/domain/entities/logbook.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/logbook_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/logbook_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_validations_screen.dart';

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

const _sup =
    AppUser(id: 's1', email: 'sup@steg.tn', roles: ['SUPERVISOR']);
const _intern =
    AppUser(id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);

Future<FakeInternshipRepository> _pump(
  WidgetTester tester,
  Widget page, {
  AppUser user = _sup,
  FakeInternshipRepository? fake,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(user)),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => true),
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
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('supervisor logbook review (acceptance)', () {
    testWidgets('submitted logbook opens with content + both actions',
        (tester) async {
      final fake = FakeInternshipRepository()..seedSubmittedLogbook();
      await _pump(tester,
          const LogbookDetailScreen(internshipId: 'internship-1'),
          fake: fake);

      expect(find.text('Carnet de stage'), findsOneWidget);
      expect(find.text('Contenu soumis'), findsOneWidget);
      expect(find.textContaining('Rapport final du carnet'),
          findsOneWidget);
      expect(find.text('Soumis pour validation'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);
      expect(find.text('Demander une correction'), findsOneWidget);
    });

    testWidgets('validate is server-confirmed and locks the logbook',
        (tester) async {
      final fake = FakeInternshipRepository()..seedSubmittedLogbook();
      await _pump(tester,
          const LogbookDetailScreen(internshipId: 'internship-1'),
          fake: fake);

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      // Confirmation dialog -> confirm.
      await tester.tap(find.text('Valider').last);
      await tester.pumpAndSettle();

      // Backend now authoritative VALIDATED; snackbar confirms.
      expect(fake.logbooks['internship-1']!.status,
          LogbookStatus.validated);
      expect(find.text('Carnet validé.'), findsOneWidget);
      // Decision row gone: nothing left to approve.
      expect(find.text('Demander une correction'), findsNothing);
      expect(find.text('Valider'), findsNothing);
    });

    testWidgets('reject requires a reason (no local bypass)',
        (tester) async {
      final fake = FakeInternshipRepository()..seedSubmittedLogbook();
      await _pump(tester,
          const LogbookDetailScreen(internshipId: 'internship-1'),
          fake: fake);

      await tester.tap(find.text('Demander une correction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demander une correction').last);
      await tester.pump();

      expect(find.text('Veuillez indiquer un motif.'), findsOneWidget);
      expect(fake.logbooks['internship-1']!.status,
          LogbookStatus.submitted); // unchanged
    });

    testWidgets('reject with reason records the server state and reason',
        (tester) async {
      final fake = FakeInternshipRepository()..seedSubmittedLogbook();
      await _pump(tester,
          const LogbookDetailScreen(internshipId: 'internship-1'),
          fake: fake);

      await tester.tap(find.text('Demander une correction'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField), 'Dates à revoir.');
      await tester.tap(find.text('Demander une correction').last);
      await tester.pumpAndSettle();

      expect(fake.logbooks['internship-1']!.status,
          LogbookStatus.rejected);
      expect(fake.logbooks['internship-1']!.rejectionReason,
          'Dates à revoir.');
      expect(find.text('Carnet renvoyé pour correction.'),
          findsOneWidget);
    });

    testWidgets('validations queue lists the submitted logbook and opens it',
        (tester) async {
      final fake = FakeInternshipRepository()..seedSubmittedLogbook();
      await _pump(tester, const SupervisorValidationsScreen(),
          fake: fake);

      await tester.dragUntilVisible(
          find.text('Carnets en attente (1)'),
          find.byType(CustomScrollView),
          const Offset(0, -300));
      expect(find.text('STG-2026-0001'), findsWidgets);

      await tester.tap(find.byIcon(Icons.menu_book_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('Contenu soumis'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);
      expect(find.text('Demander une correction'), findsOneWidget);
    });

    testWidgets('intern detail shows the logbook status entry point',
        (tester) async {
      final fake = FakeInternshipRepository()..seedSubmittedLogbook();
      await _pump(tester,
          const LogbookDetailScreen(internshipId: 'internship-1'),
          fake: fake);
      expect(find.text('Carnet de stage'), findsOneWidget);
    });
  });

  group('intern logbook status flow (acceptance)', () {
    testWidgets('rejected logbook shows the reason and resubmits',
        (tester) async {
      final fake = FakeInternshipRepository();
      fake.logbooks['internship-1'] = LogbookState(
        id: 'logbook-1',
        internshipId: 'internship-1',
        status: LogbookStatus.rejected,
        finalText: 'Version à corriger.',
        rejectionReason: 'Dates à revoir.',
        submittedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _pump(tester, const LogbookScreen(), user: _intern,
          fake: fake);

      // Banner carries the supervisor's reason.
      expect(find.text('Votre carnet a été renvoyé : Dates à revoir.'),
          findsOneWidget);
      // Editor keeps the submitted text for editing.
      expect(find.text('Version à corriger.'), findsOneWidget);

      await tester.dragUntilVisible(
          find.text('Resoumettre pour validation'),
          find.byType(ListView),
          const Offset(0, -300));
      await tester.tap(find.text('Resoumettre pour validation'));
      await tester.pumpAndSettle();

      expect(fake.submittedLogbooks, hasLength(1));
      expect(fake.submittedLogbooks.single.text, 'Version à corriger.');
      expect(fake.logbooks['internship-1']!.status,
          LogbookStatus.submitted);
    });

    testWidgets('validated logbook is read-only with no submit action',
        (tester) async {
      final fake = FakeInternshipRepository();
      fake.logbooks['internship-1'] = LogbookState(
        id: 'logbook-1',
        internshipId: 'internship-1',
        status: LogbookStatus.validated,
        finalText: 'Version finale validée.',
        submittedAt: DateTime.now(),
        validatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await _pump(tester, const LogbookScreen(), user: _intern,
          fake: fake);

      expect(
          find.text('Votre carnet a été validé par votre encadrant.'),
          findsOneWidget);
      expect(find.text('Contenu soumis'), findsOneWidget);
      expect(find.text('Version finale validée.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Soumettre pour validation'), findsNothing);
      expect(find.text('Resoumettre pour validation'), findsNothing);
    });
  });
}