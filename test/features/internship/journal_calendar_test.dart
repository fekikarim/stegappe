import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:stegappe/core/l10n/app_localizations.dart";
import "package:stegappe/core/theme/steg_theme.dart";
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/features/internship/presentation/providers/journal_calendar_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_list_screen.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/widgets/journal_calendar_view.dart';

import '../../test_fixtures.dart';
import 'journal_flow_test.dart' show pumpJournal;

/// The month calendar is the journal's main surface (STEG-JRN): it paints the
/// internship period as a coloured band, marks the days that already carry an
/// entry, and lets the student pick the band colour (a stored preference).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime.now();
  final month = DateTime(today.year, today.month);

  Future<void> pumpJournalCalendar(
    WidgetTester tester, {
    DateTime? selected,
    Set<DateTime> marked = const {},
    JournalAccent accent = JournalAccent.brand,
    Locale locale = const Locale('fr'),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          internshipRepositoryProvider
              .overrideWithValue(FakeInternshipRepository()),
          prefsStoreProvider.overrideWithValue(prefs),
          selectedDayProvider.overrideWith((ref) => selected ?? today),
          journalAccentProvider.overrideWith(
              (ref) => JournalAccentController(null)..set(accent)),
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
          home: Scaffold(
            body: ListView(
              children: [
                JournalMonthCalendar(
                  month: month,
                  selected: selected ?? today,
                  start: DateTime(today.year, today.month, 1),
                  end: DateTime(today.year, today.month, 28),
                  accent: accent,
                  markedDays: marked,
                  onSelect: (_) {},
                  onMonthChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('STEG-JRN month calendar', () {
    testWidgets('paints the internship period and marks recorded days',
        (tester) async {
      await pumpJournalCalendar(
        tester,
        marked: {DateTime(today.year, today.month, 10)},
      );

      // The calendar surface and its legend are present.
      expect(find.byType(JournalMonthCalendar), findsOneWidget);
      expect(find.text('Période de stage'), findsWidgets);
      expect(find.text('Entrée enregistrée'), findsOneWidget);

      // Every day of the period is reachable with a full touch target.
      final cell = find.ancestor(
        of: find.text('${DateTime(today.year, today.month, 1).day}'),
        matching: find.byType(InkWell),
      );
      expect(cell, findsWidgets);
    });

    testWidgets('selecting a day reports it to the caller', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      DateTime? picked;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsStoreProvider.overrideWithValue(prefs),
            journalAccentProvider.overrideWith(
                (ref) => JournalAccentController(null)),
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
            home: Scaffold(
              body: JournalMonthCalendar(
                month: month,
                selected: today,
                start: DateTime(today.year, today.month, 1),
                end: DateTime(today.year, today.month, 28),
                accent: JournalAccent.brand,
                onSelect: (d) => picked = d,
                onMonthChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('${today.day}'));
      await tester.pumpAndSettle();
      expect(picked, isNotNull);
    });

    testWidgets('the month arrows publish the shifted month', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final captured = <DateTime>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsStoreProvider.overrideWithValue(prefs),
            journalAccentProvider
                .overrideWith((ref) => JournalAccentController(null)),
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
            home: Scaffold(
              body: JournalMonthCalendar(
                month: DateTime(2026, 12),
                selected: DateTime(2026, 12, 15),
                start: DateTime(2026, 12, 1),
                end: DateTime(2026, 12, 31),
                accent: JournalAccent.brand,
                onSelect: (_) {},
                onMonthChanged: captured.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Regression: the arrows used to COMPUTE the new month and drop it, so
      // they never moved the calendar.
      await tester.tap(find.byTooltip('Mois suivant'));
      await tester.pumpAndSettle();
      expect(captured, [DateTime(2027, 1)]); // wraps into the next year

      // The widget is controlled: `month` is still December here, so the
      // previous arrow reports November. What matters is that it PUBLISHES.
      await tester.tap(find.byTooltip('Mois précédent'));
      await tester.pumpAndSettle();
      expect(captured, [DateTime(2027, 1), DateTime(2026, 11)]);
    });

    testWidgets('on the journal screen the arrows repaint the month',
        (tester) async {
      await pumpJournal(tester, const JournalListScreen());
      final now = DateTime.now();

      String monthTitle() {
        final texts = find
            .descendant(
                of: find.byType(JournalMonthCalendar), matching: find.byType(Text))
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .toList();
        return texts.firstWhere((t) => RegExp(r'\d{4}').hasMatch(t),
            orElse: () => 'NONE');
      }

      final before = monthTitle();
      expect(before, isNot('NONE'));

      // Next, then back: the painted month must actually change and restore.
      await tester.tap(find.byTooltip('Mois suivant'));
      await tester.pumpAndSettle();
      final next = monthTitle();
      expect(next, isNot(before));
      expect(next, contains('${DateTime(now.year, now.month + 1).year}'));

      await tester.tap(find.byTooltip('Mois précédent'));
      await tester.pumpAndSettle();
      expect(monthTitle(), before);
    });

    testWidgets('the accent choice is persisted as a preference',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final container = ProviderContainer(
        overrides: [prefsStoreProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final controller =
          container.read(journalAccentProvider.notifier);
      expect(container.read(journalAccentProvider), JournalAccent.brand);
      await controller.set(JournalAccent.violet);

      // Same key the production store reads back on next launch.
      expect(prefs.readRaw(kJournalAccentPrefsKey),
          JournalAccent.violet.storageKey);
    });
  });
}