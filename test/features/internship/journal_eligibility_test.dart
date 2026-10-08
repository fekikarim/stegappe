// T09/B5 — the journal generation action reflects the SERVER window
// (ST-JRN-01/02, BR-20/BR-21/BR-61).
//
// The app never computes a window from the device clock: every state below is
// driven by the eligibility payload, and the disabled states always carry the
// reason (never a silently missing action).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/core/widgets/steg_button.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_generation_sheet.dart';

import '../../test_fixtures.dart';

JournalEligibility _eligibility({
  bool eligible = true,
  String reason = 'ELIGIBLE_WINDOW',
  int daysUntilOpen = 0,
  int windowDays = 30,
  int taskCount = 4,
  int approvedTasks = 4,
  bool belowThreshold = false,
}) =>
    JournalEligibility(
      eligible: eligible,
      reason: reason,
      daysUntilOpen: daysUntilOpen,
      windowDays: windowDays,
      taskCount: taskCount,
      approvedTasks: approvedTasks,
      belowThreshold: belowThreshold,
    );

Future<FakeInternshipRepository> _pumpBar(
  WidgetTester tester, {
  required JournalEligibility eligibility,
  bool online = true,
  Locale locale = const Locale('fr'),
  FakeInternshipRepository? fake,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  repo.journalEligibilityFixture = eligibility;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => online),
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
        theme: StegTheme.light(),
        home: const Scaffold(
          body: JournalGenerationBar(internshipId: 'internship-1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

StegButton _button(WidgetTester tester) =>
    tester.widget<StegButton>(find.byType(StegButton));

void main() {
  group('JournalGenerationBar (ST-JRN-03, AC1)', () {
    testWidgets('inside the window the red action is enabled and opens the flow',
        (tester) async {
      final repo = await _pumpBar(tester, eligibility: _eligibility());

      expect(find.text('Générer le journal de stage'), findsOneWidget);
      expect(_button(tester).onPressed, isNotNull);
      expect(_button(tester).variant, StegButtonVariant.destructive);

      await tester.tap(find.text('Générer le journal de stage'));
      await tester.pumpAndSettle();

      // The chooser offers both paths and explains them; the AI advisory note
      // is visible (BR-48).
      expect(find.text('À partir de mes tâches'), findsOneWidget);
      expect(find.text('À partir de mon texte'), findsOneWidget);
      expect(find.text('Le document est produit par le serveur en PDF : période du stage et tableau des tâches.'),
          findsOneWidget);
      expect(repo.eligibilityCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('before the window the action is disabled WITH the remaining days',
        (tester) async {
      await _pumpBar(
        tester,
        eligibility: _eligibility(
            eligible: false, reason: 'BEFORE_WINDOW', daysUntilOpen: 12),
      );

      expect(_button(tester).onPressed, isNull);
      expect(find.text('Disponible dans 12 jour(s)'), findsOneWidget);
    });

    testWidgets('a late internship keeps the action enabled and says so',
        (tester) async {
      await _pumpBar(
        tester,
        eligibility: _eligibility(reason: 'ELIGIBLE_LATE'),
      );

      expect(_button(tester).onPressed, isNotNull);
      await tester.tap(find.text('Générer le journal de stage'));
      await tester.pumpAndSettle();
      expect(find.text('Période terminée : génération possible (en retard).'),
          findsOneWidget);
    });

    testWidgets('cancelled and period-less internships explain the refusal',
        (tester) async {
      await _pumpBar(
        tester,
        eligibility: _eligibility(eligible: false, reason: 'CANCELLED'),
      );
      expect(_button(tester).onPressed, isNull);
      expect(find.text('Stage annulé : génération impossible.'), findsOneWidget);

      await _pumpBar(
        tester,
        eligibility: _eligibility(eligible: false, reason: 'NO_PERIOD'),
      );
      expect(_button(tester).onPressed, isNull);
      expect(find.text('Aucune période de stage : génération impossible.'),
          findsOneWidget);
    });

    testWidgets('offline the action is disabled and asks for connectivity (D12)',
        (tester) async {
      await _pumpBar(tester, eligibility: _eligibility(), online: false);

      expect(_button(tester).onPressed, isNull);
      expect(find.text('Connexion requise pour générer le journal.'),
          findsOneWidget);
    });

    testWidgets('an eligibility read failure never crashes the screen',
        (tester) async {
      final repo = FakeInternshipRepository()
        ..eligibilityError =
            const ApiException(kind: ApiErrorKind.server, message: 'boom');
      await _pumpBar(tester, eligibility: _eligibility(), fake: repo);

      expect(_button(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the <75 % warning is shown before generating (BR-24)',
        (tester) async {
      await _pumpBar(
        tester,
        eligibility: _eligibility(
            taskCount: 9, approvedTasks: 5, belowThreshold: true),
      );

      await tester.tap(find.text('Générer le journal de stage'));
      await tester.pumpAndSettle();
      expect(
        find.text(
            'Seulement 5 sur 9 tâches approuvées : le journal peut échouer la vérification.'),
        findsOneWidget,
      );
    });

    testWidgets('zero tasks are announced before generating', (tester) async {
      await _pumpBar(
        tester,
        eligibility: _eligibility(taskCount: 0, approvedTasks: 0),
      );

      await tester.tap(find.text('Générer le journal de stage'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune tâche enregistrée : le tableau du journal sera vide.'),
          findsOneWidget);
    });

    testWidgets('every state is localized (en + ar, RTL renders)', (tester) async {
      await _pumpBar(
        tester,
        eligibility:
            _eligibility(eligible: false, reason: 'BEFORE_WINDOW', daysUntilOpen: 3),
        locale: const Locale('en'),
      );
      expect(find.text('Generate the internship journal'), findsOneWidget);
      expect(find.text('Available in 3 day(s)'), findsOneWidget);

      await _pumpBar(
        tester,
        eligibility:
            _eligibility(eligible: false, reason: 'BEFORE_WINDOW', daysUntilOpen: 3),
        locale: const Locale('ar'),
      );
      expect(find.text('إنشاء دفتر التربص'), findsOneWidget);
      expect(find.text('متاح بعد 3 يوم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
