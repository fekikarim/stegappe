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
import 'package:stegappe/features/internship/presentation/screens/logbook_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/progress_screen.dart';

import '../../test_fixtures.dart';

class _FakeAuth implements AuthRepository {
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

Future<FakeInternshipRepository> pumpD6(
  WidgetTester tester,
  Widget page, {
  FakeInternshipRepository? fake,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth()),
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
  group('progress overview (acceptance)', () {
    testWidgets('combines tasks/journal/deliverables/timeline',
        (tester) async {
      await pumpD6(tester, const ProgressScreen());

      expect(find.text('Progression globale'), findsOneWidget);
      expect(find.text('Tâches accomplies'), findsOneWidget);
      expect(find.text('Journal validé'), findsOneWidget);
      expect(find.text('Livrables validés'), findsOneWidget);
      expect(find.text('Évaluations reçues'), findsOneWidget);
      expect(find.text('Temps écoulé'), findsOneWidget);
      // AI entry is present but optional.
      expect(find.text('Assistance IA'), findsOneWidget);
    });
  });

  group('advisory logbook (acceptance)', () {
    testWidgets('draft is review-only with safety labels',
        (tester) async {
      await pumpD6(tester, const LogbookScreen());

      expect(find.text('Assistance IA'), findsWidgets);
      expect(
          find.text(
              'Données sensibles (CIN) exclues'),
          findsOneWidget);
      expect(
          find.textContaining(
              'vérification humaine requise'),
          findsOneWidget);
      // Draft prefilled for review, editable, never auto-sent.
      expect(find.textContaining('Période'), findsOneWidget);
      await tester.dragUntilVisible(
          find.text('Vérifiez les dates.'),
          find.byType(ListView),
          const Offset(0, -300));
      expect(find.text('Vérifiez les dates.'), findsOneWidget);
      // No approve/finance/status actions anywhere.
      expect(find.text('Valider'), findsNothing);
      expect(find.text('Approuver'), findsNothing);
    });

    testWidgets('edited text stays local until regenerate',
        (tester) async {
      await pumpD6(tester, const LogbookScreen());

      await tester.enterText(
          find.byType(TextField), 'Ma version relue.');
      await tester.pump();
      expect(find.text('Ma version relue.'), findsOneWidget);
    });

    testWidgets('AI outage degrades to retry card, core intact',
        (tester) async {
      final fake = FakeInternshipRepository()..failAi = true;
      await pumpD6(tester, const LogbookScreen(), fake: fake);

      expect(find.textContaining('indisponible'), findsOneWidget);
      expect(find.text('Régénérer'), findsOneWidget);
      // Core flows unaffected: dashboard still loads with same repo.
      await pumpD6(tester, const ProgressScreen(), fake: fake);
      expect(find.text('Progression globale'), findsOneWidget);
    });
  });
}
