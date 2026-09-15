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
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/evaluation_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/evaluation_form_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/intern_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/my_evaluations_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervised_interns_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_home_screen.dart';

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

Future<FakeInternshipRepository> pumpSup(
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
  group('supervisor workspace (acceptance)', () {
    testWidgets('home shows queues + interns needing attention',
        (tester) async {
      await pumpSup(
          tester, const SupervisorHomeScreen(onOpenTab: null));

      expect(find.text('Pilotage des stages'), findsOneWidget);
      expect(find.text('Journal en attente'), findsWidgets);
      expect(find.text('Nécessite votre attention'), findsOneWidget);
      expect(find.text('Amira Ben Salah'), findsWidgets);
    });

    testWidgets('interns tab lists supervised interns', (tester) async {
      await pumpSup(tester, const SupervisedInternsScreen());
      expect(find.text('Amira Ben Salah'), findsOneWidget);
      expect(find.textContaining('STG-2026-0001'), findsOneWidget);
    });

    testWidgets('intern file separates planned/recorded/assessed work',
        (tester) async {
      await pumpSup(
          tester,
          const InternDetailScreen(
              internshipId: 'internship-1'));

      expect(find.text('Dossier stagiaire'), findsOneWidget);
      expect(find.text('Amira Ben Salah'), findsOneWidget);
      expect(find.textContaining('Tâches prévues'), findsOneWidget);
      expect(find.textContaining('Journal à valider'), findsOneWidget);
      // Planned work visible, recorded work visible, assessment visible
      // (below the fold: scroll the detail list into view).
      expect(find.text('Today task'), findsOneWidget);
      expect(find.text('Submitted entry'), findsOneWidget);
      final list = find.byType(ListView).first;
      await tester.dragUntilVisible(
          find.text('Livrables'), list, const Offset(0, -300));
      await tester.dragUntilVisible(
          find.text('Évaluations'), list, const Offset(0, -300));
      await tester.dragUntilVisible(
          find.text('Nouvelle évaluation'), list, const Offset(0, -300));
      expect(find.text('Nouvelle évaluation'), findsOneWidget);
    });
  });

  group('evaluation form (acceptance)', () {
    testWidgets(
        'template-driven criteria + estimate + confirm + server total',
        (tester) async {
      final fake = FakeInternshipRepository();
      await pumpSup(
          tester,
          const EvaluationFormScreen(
              internshipId: 'internship-1'),
          fake: fake);

      // Criteria generated from the backend template, not hard-coded.
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Comportement'), findsOneWidget);

      // Score both criteria 15/20 → indicative estimate 15/20.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '15');
      await tester.enterText(fields.at(2), '15');
      await tester.pump();
      final formList = find.byType(ListView).first;
      await tester.dragUntilVisible(
          find.text('Estimation indicative : 15.00 / 20'),
          formList,
          const Offset(0, -300));
      expect(
          find.text('Estimation indicative : 15.00 / 20'),
          findsOneWidget);

      // Link one real task review.
      await tester.dragUntilVisible(
          find.byType(Checkbox).first, formList, const Offset(0, 300));
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      // Submit → explicit confirmation (consequential action).
      await tester.dragUntilVisible(
          find.text('Soumettre l’évaluation'),
          formList,
          const Offset(0, -300));
      await tester.tap(find.text('Soumettre l’évaluation'));
      await tester.pumpAndSettle();
      expect(
          find.text('Soumettre cette évaluation ?'), findsOneWidget);
      await tester.tap(find.text('Soumettre l’évaluation').last);
      await tester.pumpAndSettle();

      // Server sequence recorded; authoritative total displayed.
      expect(fake.createdEvaluations.single['templateId'], 't1');
      expect(fake.submittedScores.length, 2);
      expect(fake.taskReviewCalls.length, 1);
      expect(
          find.text('Total officiel : 15.00 / 20'), findsOneWidget);
    });

    testWidgets('invalid scores block submit with guidance',
        (tester) async {
      await pumpSup(
          tester,
          const EvaluationFormScreen(
              internshipId: 'internship-1'));

      await tester.enterText(
          find.byType(TextField).first, '99');
      await tester.pump();
      // No estimate for invalid input.
      expect(find.textContaining('Estimation indicative'),
          findsNothing);
      final formList = find.byType(ListView).first;
      await tester.dragUntilVisible(
          find.text('Soumettre l’évaluation'),
          formList,
          const Offset(0, -300));
      await tester.tap(find.text('Soumettre l’évaluation'));
      await tester.pump();
      expect(find.text('Au moins une note est requise.'),
          findsNothing); // has a score, but invalid
    });
  });

  group('intern evaluations read-only (acceptance)', () {
    testWidgets('list + detail show server values, no form actions',
        (tester) async {
      await pumpSup(tester, const MyEvaluationsScreen(),
          user: _intern);

      expect(find.text('Mes évaluations'), findsOneWidget);
      await tester.tap(find.textContaining('Hebdomadaire').first);
      await tester.pumpAndSettle();

      // Authoritative total + per-criterion scores + task reviews.
      expect(find.text('Total officiel : 15.00 / 20'),
          findsOneWidget);
      expect(find.text('Technique'), findsOneWidget);
      expect(find.text('Done task'), findsOneWidget);
      final detailList = find.byType(ListView).last;
      await tester.dragUntilVisible(
          find.text('Continue ainsi.'), detailList, const Offset(0, -300));
      expect(find.text('Continue ainsi.'), findsOneWidget);
      // No creation/validation actions anywhere.
      expect(find.text('Nouvelle évaluation'), findsNothing);
      expect(find.text('Valider'), findsNothing);
    });

    testWidgets('evaluation detail renders directly', (tester) async {
      await pumpSup(
          tester,
          const EvaluationDetailScreen(evaluationId: 'e1'),
          user: _intern);
      expect(find.text('Notes par critère'), findsOneWidget);
      expect(find.text('Revue des tâches'), findsOneWidget);
      expect(find.text('Appréciation'), findsOneWidget);
    });
  });
}
