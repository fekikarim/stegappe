// T09/B6 — the student's journal generation flow (ST-JRN-04/05/06).
//
// The backend owns the AI call, the strict schema, the PDF and the deliverable;
// these tests pin the app's half: the chooser, the cancellable progress, the
// result actions (preview / regenerate with confirm / keep), the bounded text
// path, and the degraded AI state that keeps the manual path one tap away.
import 'dart:async';
import 'dart:typed_data';

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
import 'package:stegappe/features/internship/presentation/services/file_share.dart';

import '../../test_fixtures.dart';

const _eligible = JournalEligibility(
  eligible: true,
  reason: 'ELIGIBLE_WINDOW',
  daysUntilOpen: 0,
  windowDays: 30,
  taskCount: 4,
  approvedTasks: 4,
  belowThreshold: false,
);

class _Workspace {
  _Workspace(this.repo, this.shared);
  final FakeInternshipRepository repo;
  final List<(Uint8List, String)> shared;
}

Future<_Workspace> _pumpSheet(
  WidgetTester tester, {
  FakeInternshipRepository? fake,
  JournalEligibility eligibility = _eligible,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  repo.journalEligibilityFixture = eligibility;
  final shared = <(Uint8List, String)>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => true),
        shareFnProvider.overrideWithValue((bytes, fileName) async {
          shared.add((bytes, fileName));
        }),
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
        home: const Scaffold(
          body: JournalGenerationBar(internshipId: 'internship-1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Générer le journal de stage'));
  await tester.pumpAndSettle();
  return _Workspace(repo, shared);
}

StegButton _buttonLabelled(WidgetTester tester, String label) =>
    tester.widget<StegButton>(
      find.widgetWithText(StegButton, label),
    );

void main() {
  group('journal generation flow (ST-JRN-04/06, AC2/AC5)', () {
    testWidgets('from my tasks: progress then a result with preview and keep',
        (tester) async {
      final repo = FakeInternshipRepository();
      final gate = Completer<void>();
      repo.journalGate = gate;
      final ws = await _pumpSheet(tester, fake: repo);

      await tester.tap(find.text('À partir de mes tâches'));
      await tester.pump();

      // Cancellable progress, never a silent spinner.
      expect(find.text('Génération en cours…'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(ws.repo.journalGenerations, ['TASKS']);
      expect(find.text('Journal de stage — INT-2026-00001'), findsOneWidget);
      expect(find.text('Journal généré en brouillon (version 1).'), findsOneWidget);
      expect(find.text('Source : mes tâches'), findsOneWidget);
      expect(find.text('Ouvrir / partager le PDF'), findsOneWidget);
      expect(find.text('Régénérer'), findsOneWidget);
      expect(find.text('Conserver'), findsOneWidget);
      // Keeping notifies nobody (ST-JRN-06) — stated in the UI, not implied.
      expect(
        find.text(
            'Conserver n’envoie rien : personne n’est notifié tant que le livrable n’est pas soumis.'),
        findsOneWidget,
      );
    });

    testWidgets('preview downloads the authenticated artifact and shares it',
        (tester) async {
      final ws = await _pumpSheet(tester);
      await tester.tap(find.text('À partir de mes tâches'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ouvrir / partager le PDF'));
      await tester.pumpAndSettle();

      expect(ws.repo.downloads.single.$1, 'del-journal');
      expect(ws.shared.single.$2, 'journal-de-stage-INT-2026-00001.pdf');
      expect(ws.shared.single.$1, Uint8List.fromList([0x25, 0x50, 0x44, 0x46]));
    });

    testWidgets('regenerate asks for confirmation and discards the draft',
        (tester) async {
      final ws = await _pumpSheet(tester);
      await tester.tap(find.text('À partir de mes tâches'));
      await tester.pumpAndSettle();
      expect(ws.repo.journalGenerations.length, 1);

      await tester.tap(find.text('Régénérer'));
      await tester.pumpAndSettle();
      expect(
        find.text(
            'Régénérer le journal ? Le brouillon précédent sera remplacé.'),
        findsOneWidget,
      );

      // Cancelling the dialog changes nothing.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(ws.repo.journalGenerations.length, 1);

      await tester.tap(find.text('Régénérer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Régénérer').last);
      await tester.pumpAndSettle();
      expect(ws.repo.journalGenerations, ['TASKS', 'TASKS']);
    });

    testWidgets('keep closes the sheet — nothing is submitted or notified',
        (tester) async {
      final ws = await _pumpSheet(tester);
      await tester.tap(find.text('À partir de mes tâches'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Conserver'));
      await tester.pumpAndSettle();

      expect(find.text('Régénérer'), findsNothing);
      // No submit call was made by the flow.
      expect(ws.repo.submitted, isEmpty);
    });

    testWidgets('cancelling the wait never shows a late success',
        (tester) async {
      final repo = FakeInternshipRepository();
      final gate = Completer<void>();
      repo.journalGate = gate;
      await _pumpSheet(tester, fake: repo);

      await tester.tap(find.text('À partir de mes tâches'));
      await tester.pump();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Ouvrir / partager le PDF'), findsNothing);
      expect(find.text('Génération en cours…'), findsNothing);
    });

    testWidgets('degraded AI: localized message, manual path one tap away',
        (tester) async {
      final repo = FakeInternshipRepository()
        ..journalGenerationError = const ApiException(
          kind: ApiErrorKind.server,
          statusCode: 503,
          code: 'AI_UNAVAILABLE',
          message: 'AI unavailable',
        );
      await _pumpSheet(tester, fake: repo);

      await tester.tap(find.text('À partir de mes tâches'));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Le service IA est indisponible. Vous pouvez continuer manuellement.'),
        findsOneWidget,
      );
      expect(find.text('Écrire une entrée de journal manuellement'),
          findsOneWidget);
      // The raw provider message is never rendered.
      expect(find.text('AI unavailable'), findsNothing);
    });

    testWidgets('text path: counter, bounded start button, same pipeline',
        (tester) async {
      final ws = await _pumpSheet(tester);
      await tester.tap(find.text('À partir de mon texte'));
      await tester.pumpAndSettle();

      final field = find.byType(TextField);
      expect(field, findsOneWidget);
      expect(find.text('0 / 8000 caractères'), findsOneWidget);
      // Too short → the action is honestly disabled with the reason.
      expect(_buttonLabelled(tester, 'Lancer la génération').onPressed, isNull);
      expect(find.text('Au moins 40 caractères sont requis.'), findsOneWidget);

      await tester.enterText(field, 'x' * 60);
      await tester.pumpAndSettle();
      expect(find.text('60 / 8000 caractères'), findsOneWidget);
      expect(_buttonLabelled(tester, 'Lancer la génération').onPressed, isNotNull);

      await tester.tap(find.text('Lancer la génération'));
      await tester.pumpAndSettle();

      expect(ws.repo.journalGenerations.single, 'TEXT:${'x' * 60}');
      expect(find.text('Source : mon texte'), findsOneWidget);
    });

    testWidgets('a warning from the backend is repeated on the result',
        (tester) async {
      final repo = FakeInternshipRepository()
        ..journalResult = const JournalGenerationResult(
          deliverableId: 'del-journal',
          title: 'Journal de stage — INT-2026-00001',
          status: DeliverableStatus.draft,
          currentVersion: 2,
          fileName: 'journal-de-stage-INT-2026-00001.pdf',
          source: 'TASKS',
          taskCount: 3,
          approvedTasks: 1,
          belowThreshold: true,
          replacedDraft: true,
          previousSubmitted: false,
        );
      await _pumpSheet(tester, fake: repo, eligibility: _eligible);

      await tester.tap(find.text('À partir de mes tâches'));
      await tester.pumpAndSettle();

      expect(find.text('Journal généré en brouillon (version 2).'), findsOneWidget);
      expect(find.text('Le brouillon précédent a été remplacé.'), findsOneWidget);
      expect(
        find.text(
            'Seulement 1 sur 3 tâches approuvées : le journal peut échouer la vérification.'),
        findsOneWidget,
      );
    });

    testWidgets('a submitted journal stays immutable and the student is told',
        (tester) async {
      final repo = FakeInternshipRepository()
        ..journalResult = const JournalGenerationResult(
          deliverableId: 'del-journal-2',
          title: 'Journal de stage — INT-2026-00001 (nouveau)',
          status: DeliverableStatus.draft,
          currentVersion: 1,
          fileName: 'journal-de-stage-INT-2026-00001.pdf',
          source: 'TASKS',
          taskCount: 4,
          approvedTasks: 4,
          belowThreshold: false,
          replacedDraft: false,
          previousSubmitted: true,
        );
      await _pumpSheet(tester, fake: repo);

      await tester.tap(find.text('À partir de mes tâches'));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Un journal déjà soumis reste inchangé : ceci est un nouveau brouillon.'),
        findsOneWidget,
      );
    });

    testWidgets('the flow is localized (en)', (tester) async {
      final repo = FakeInternshipRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            internshipRepositoryProvider.overrideWithValue(repo),
            isOnlineProvider.overrideWith((ref) => true),
            shareFnProvider.overrideWithValue((_, _) async {}),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
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
      await tester.tap(find.text('Generate the internship journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From my tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Journal generated as a draft (version 1).'), findsOneWidget);
      expect(find.text('Open / share the PDF'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
