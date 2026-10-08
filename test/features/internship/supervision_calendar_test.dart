import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import '../../support/queue_harness.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/realtime/realtime_sync.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/core/widgets/steg_states.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/calendar.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/intern_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervised_interns_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_calendar_screen.dart';

import '../../test_fixtures.dart';

const _sup = AppUser(id: 's1', email: 'sup@steg.tn', roles: ['SUPERVISOR']);

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.user);
  final AppUser user;

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
  Future<AppUser?> restoreSession() async => user;
}

SupervisedIntern _intern({
  required String id,
  required String name,
  required DateTime start,
  required DateTime end,
  InternshipStatus status = InternshipStatus.inProgress,
}) =>
    SupervisedIntern(
      internshipId: id,
      reference: 'REF-$id',
      internName: name,
      status: status,
      type: InternshipType.perfectionnement,
      startDate: start,
      endDate: end,
      departmentName: 'DSI',
      tasksCompleted: 1,
      tasksTotal: 4,
      pendingJournal: 0,
      pendingDeliverables: 0,
      evaluationsCount: 0,
    );

Future<FakeInternshipRepository> pumpSupervised(
  WidgetTester tester, {
  FakeInternshipRepository? fake,
  bool online = true,
  Locale locale = const Locale('fr'),
  DateTime? month,
  List<Override> extra = const [],
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(_sup)),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => online),
        await queueOverride(),
        if (month != null)
          calendarMonthProvider.overrideWith((ref) => month),
        ...extra,
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
        home: const Scaffold(body: SupervisedInternsScreen()),
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

Future<AppLocalizations> loadL10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  group('T12 calendar math: server dates projected, never computed', () {
    test('monthCells pads leading and trailing to full weeks', () {
      // March 2026 starts on a Sunday: Monday-first needs 6 leading pads.
      final cells = monthCells(2026, 3, DateTime.monday);
      expect(cells.length % 7, 0);
      expect(cells.whereType<DateTime>(), hasLength(31));
      expect(cells.first, isNull);
      expect(cells[6], DateTime(2026, 3, 1));
      // February 2026 (28 days, starts Sunday): 6 + 28 = 34 → 35 cells.
      expect(monthCells(2026, 2, DateTime.monday).length, 35);
    });

    test('monthCells honors a Sunday-first week', () {
      final cells = monthCells(2026, 3, DateTime.sunday);
      expect(cells[0], DateTime(2026, 3, 1));
    });

    test('periodOverlapsMonth is inclusive on both boundaries', () {
      expect(periodOverlapsMonth(DateTime(2026, 1, 10), DateTime(2026, 4, 1), 2026, 3), isTrue);
      expect(periodOverlapsMonth(DateTime(2026, 4, 1), DateTime(2026, 5, 1), 2026, 3), isFalse);
      // Ends exactly on the month start / starts exactly on the month end.
      expect(periodOverlapsMonth(DateTime(2026, 1, 1), DateTime(2026, 3, 1), 2026, 3), isTrue);
      expect(periodOverlapsMonth(DateTime(2026, 3, 31), DateTime(2026, 4, 30), 2026, 3), isTrue);
      // Adjacent but disjoint: ends Feb 28, starts Apr 1.
      expect(periodOverlapsMonth(DateTime(2026, 1, 1), DateTime(2026, 2, 28), 2026, 3), isFalse);
      expect(periodOverlapsMonth(DateTime(2026, 4, 1), DateTime(2026, 5, 1), 2026, 3), isFalse);
    });

    test('weekSegment clamps to the 7-day window', () {
      // Full week.
      expect(
        weekSegment(DateTime(2026, 3, 1), DateTime(2026, 3, 31),
            DateTime(2026, 3, 9)),
        (offset: 0, length: 7),
      );
      // Starts Wednesday of the week.
      expect(
        weekSegment(DateTime(2026, 3, 11), DateTime(2026, 3, 31),
            DateTime(2026, 3, 9)),
        (offset: 2, length: 5),
      );
      // Ends Tuesday of the week.
      expect(
        weekSegment(DateTime(2026, 3, 1), DateTime(2026, 3, 10),
            DateTime(2026, 3, 9)),
        (offset: 0, length: 2),
      );
      // Disjoint weeks.
      expect(
        weekSegment(DateTime(2026, 3, 1), DateTime(2026, 3, 7),
            DateTime(2026, 3, 9)),
        isNull,
      );
      expect(
        weekSegment(DateTime(2026, 3, 20), DateTime(2026, 3, 31),
            DateTime(2026, 3, 9)),
        isNull,
      );
    });

    test('isSameDay compares calendar days only', () {
      expect(isSameDay(DateTime(2026, 3, 1, 8), DateTime(2026, 3, 1, 20)), isTrue);
      expect(isSameDay(DateTime(2026, 3, 1), DateTime(2026, 3, 2)), isFalse);
    });

    test('filterSupervised matches name or reference, case-insensitive', () {
      final rows = [
        _intern(id: 'a', name: 'Amira Ben Salah', start: DateTime(2026, 1, 1), end: DateTime(2026, 3, 31)),
        _intern(id: 'b', name: 'Karim Gharbi', start: DateTime(2026, 1, 1), end: DateTime(2026, 3, 31)),
      ];
      expect(filterSupervised(rows, ''), hasLength(2));
      expect(filterSupervised(rows, 'amira').single.internshipId, 'a');
      expect(filterSupervised(rows, 'REF-B').single.internshipId, 'b');
      expect(filterSupervised(rows, 'zzz'), isEmpty);
    });

    test('sortSupervised orders by name, end date and status', () {
      final rows = [
        _intern(id: 'b', name: 'Karim', start: DateTime(2026, 1, 1), end: DateTime(2026, 5, 31), status: InternshipStatus.validated),
        _intern(id: 'a', name: 'Amira', start: DateTime(2026, 1, 1), end: DateTime(2026, 3, 31), status: InternshipStatus.inProgress),
      ];
      expect(sortSupervised(rows, SupervisedSort.name).map((e) => e.internshipId), ['a', 'b']);
      expect(sortSupervised(rows, SupervisedSort.endDate).map((e) => e.internshipId), ['a', 'b']);
      expect(sortSupervised(rows, SupervisedSort.status).map((e) => e.internshipId), ['a', 'b']);
    });
  });

  group('T12 supervised row parsing (B2 wire shape)', () {
    test('a full row decodes with server values intact', () {
      final row = supervisedInternFromJson(_row());
      expect(row.internshipId, 'i1');
      expect(row.reference, 'STG-2026-0042');
      expect(row.internName, 'Amira Ben Salah');
      expect(row.status, InternshipStatus.inProgress);
      expect(row.type, InternshipType.pfe);
      expect(row.startDate, DateTime(2026, 1, 5));
      expect(row.endDate, DateTime(2026, 3, 31));
      expect(row.departmentName, 'DSI');
      expect(row.tasksTotal, 9);
      expect(row.tasksCompleted, 3);
      expect(row.pendingJournal, 2);
      expect(row.pendingDeliverables, 1);
      expect(row.evaluationsCount, 1);
    });

    test('blank names fall back, missing counts default to zero', () {
      final row = supervisedInternFromJson(
          _row(internName: '  ', departmentName: null)
            ..remove('tasksTotal'));
      expect(row.internName, '—');
      expect(row.departmentName, '—');
      expect(row.tasksTotal, 0);
    });

    test('a row without period dates throws (never a fabricated bar)', () {
      expect(
        () => supervisedInternFromJson(_row(startDate: null)),
        throwsFormatException,
      );
      expect(
        () => supervisedInternFromJson(_row(endDate: null)),
        throwsFormatException,
      );
    });
  });

  group('T12 realtime: document frames converge the supervised list', () {
    test('documents targets include the supervised list', () {
      expect(
        RiverpodRealtimeSync((_) {})
            .targetsFor(RealtimeCategory.documents),
        contains(supervisedInternsProvider),
      );
    });
  });

  group('T12 candidates list: search, sort, stale, error', () {
    testWidgets('cards render with the attention badge', (tester) async {
      await pumpSupervised(tester);
      expect(find.text('Amira Ben Salah'), findsOneWidget);
      // pendingJournal(1) + pendingDeliverables(1) = badge "2".
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('search filters by name; empty result is honest',
        (tester) async {
      final fake = FakeInternshipRepository()
        ..supervisedOverride = [
          _intern(id: 'a', name: 'Amira Ben Salah', start: DateTime(2026, 1, 1), end: DateTime(2026, 3, 31)),
          _intern(id: 'b', name: 'Karim Gharbi', start: DateTime(2026, 1, 1), end: DateTime(2026, 3, 31)),
        ];
      await pumpSupervised(tester, fake: fake);
      await tester.enterText(find.byType(TextField), 'karim');
      await tester.pumpAndSettle();
      expect(find.text('Karim Gharbi'), findsOneWidget);
      expect(find.text('Amira Ben Salah'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Karim Gharbi'), findsNothing);
    });

    testWidgets('sort by end date reorders the rows', (tester) async {
      final fake = FakeInternshipRepository()
        ..supervisedOverride = [
          _intern(id: 'b', name: 'Karim Gharbi', start: DateTime(2026, 1, 1), end: DateTime(2026, 3, 31)),
          _intern(id: 'a', name: 'Amira Ben Salah', start: DateTime(2026, 1, 1), end: DateTime(2026, 5, 31)),
        ];
      await pumpSupervised(tester, fake: fake);
      Finder row(String name) => find.ancestor(
          of: find.text(name), matching: find.byType(Card));
      // Default sort is by name: Amira above Karim.
      expect(
        tester.getTopLeft(row('Amira Ben Salah')).dy,
        lessThan(tester.getTopLeft(row('Karim Gharbi')).dy),
      );

      await tester.tap(find.byIcon(Icons.sort_outlined));
      await tester.pumpAndSettle();
      final l10n = await loadL10n('fr');
      await tester.tap(find.text(l10n.supSortEndDate));
      await tester.pumpAndSettle();
      // By end date Karim (March) comes first.
      expect(
        tester.getTopLeft(row('Karim Gharbi')).dy,
        lessThan(tester.getTopLeft(row('Amira Ben Salah')).dy),
      );
    });

    testWidgets('the list needs no conversation (single scoped source)',
        (tester) async {
      final fake = FakeInternshipRepository();
      await pumpSupervised(tester, fake: fake);
      // The fake models zero conversations; rows still render from the
      // scoped endpoint shape, and ids derive from the same rows.
      expect(find.text('Amira Ben Salah'), findsOneWidget);
      expect(await fake.supervisedInternshipIds(), ['internship-1']);
    });

    testWidgets('offline shows the stale list with a label', (tester) async {
      final cached = [
        _intern(id: 'a', name: 'Amira Ben Salah', start: DateTime(2026, 1, 1), end: DateTime(2026, 3, 31)),
      ];
      final fake = FakeInternshipRepository()..failSupervised = true;
      await pumpSupervised(tester,
          fake: fake,
          online: false,
          extra: [
            lastSupervisedProvider.overrideWith((ref) => cached),
          ]);
      // The live read failed offline, but the warm cache stays visible.
      expect(find.text('Amira Ben Salah'), findsOneWidget);
    });

    testWidgets('error offers retry and recovers', (tester) async {
      final fake = FakeInternshipRepository()..failSupervised = true;
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester, fake: fake);
      expect(find.byType(StegErrorView), findsOneWidget);
      fake.failSupervised = false;
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();
      expect(find.text('Amira Ben Salah'), findsOneWidget);
    });
  });

  group('T12 calendar: month view of supervised periods', () {
    testWidgets('bars render with names; toggle switches views',
        (tester) async {
      final fake = FakeInternshipRepository()
        ..supervisedOverride = [
          _intern(id: 'a', name: 'Amira Ben Salah', start: DateTime(2026, 3, 2), end: DateTime(2026, 3, 20)),
          _intern(id: 'b', name: 'Karim Gharbi', start: DateTime(2026, 3, 10), end: DateTime(2026, 4, 30)),
        ];
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester,
          fake: fake, month: DateTime(2026, 3, 1));
      // List view first.
      expect(find.text('Amira Ben Salah'), findsOneWidget);
      await tester.tap(find.text(l10n.supViewCalendar));
      await tester.pumpAndSettle();
      expect(
          find.text(DateFormat.yMMMM('fr').format(DateTime(2026, 3, 1))),
          findsOneWidget);
      // Overlapping periods stack: both names visible as lanes.
      expect(find.text('Amira Ben Salah'), findsWidgets);
      expect(find.text('Karim Gharbi'), findsWidgets);
    });

    testWidgets('tapping a lane opens the intern file', (tester) async {
      final fake = FakeInternshipRepository()
        ..supervisedOverride = [
          _intern(id: 'a', name: 'Amira Ben Salah', start: DateTime(2026, 3, 2), end: DateTime(2026, 3, 20)),
        ];
      await pumpSupervised(tester,
          fake: fake, month: DateTime(2026, 3, 1));
      final l10n = await loadL10n('fr');
      await tester.tap(find.text(l10n.supViewCalendar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amira Ben Salah').first);
      await tester.pumpAndSettle();
      expect(find.byType(InternDetailScreen), findsOneWidget);
    });

    testWidgets('month boundaries clip periods honestly', (tester) async {
      final fake = FakeInternshipRepository()
        ..supervisedOverride = [
          _intern(id: 'a', name: 'Ends January', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31)),
          _intern(id: 'b', name: 'Starts February', start: DateTime(2026, 2, 1), end: DateTime(2026, 2, 28)),
        ];
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester,
          fake: fake, month: DateTime(2026, 2, 1));
      await tester.tap(find.text(l10n.supViewCalendar));
      await tester.pumpAndSettle();
      expect(find.text('Ends January'), findsNothing);
      expect(find.text('Starts February'), findsWidgets);
    });

    testWidgets('prev/next/today navigate the cursor', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester, month: DateTime(2026, 3, 1));
      await tester.tap(find.text(l10n.supViewCalendar));
      await tester.pumpAndSettle();
      final march = DateFormat.yMMMM('fr').format(DateTime(2026, 3, 1));
      final april = DateFormat.yMMMM('fr').format(DateTime(2026, 4, 1));
      expect(find.text(march), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.supNextMonth));
      await tester.pumpAndSettle();
      expect(find.text(april), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.supPrevMonth));
      await tester.pumpAndSettle();
      expect(find.text(march), findsOneWidget);
    });

    testWidgets('arabic renders the calendar (RTL smoke)', (tester) async {
      await pumpSupervised(tester, locale: const Locale('ar'));
      final l10n = await loadL10n('ar');
      await tester.tap(find.text(l10n.supViewCalendar));
      await tester.pumpAndSettle();
      expect(find.text('Amira Ben Salah'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('very long names never overflow', (tester) async {
      final fake = FakeInternshipRepository()
        ..supervisedOverride = [
          _intern(
              id: 'a',
              name: 'Amina Ben Salah Ep. Trabelsi Ep. Gharbi Ep. Mansouri',
              start: DateTime(2026, 3, 2),
              end: DateTime(2026, 3, 20)),
        ];
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester,
          fake: fake, month: DateTime(2026, 3, 1));
      await tester.tap(find.text(l10n.supViewCalendar));
      await tester.pumpAndSettle();
      expect(
          find.text('Amina Ben Salah Ep. Trabelsi Ep. Gharbi Ep. Mansouri'),
          findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('T12 l10n: calendar keys', () {
    test('calendar keys exist in fr/en/ar', () async {
      for (final locale in ['fr', 'en', 'ar']) {
        final l10n = await loadL10n(locale);
        expect(l10n.supViewList.trim(), isNotEmpty);
        expect(l10n.supViewCalendar.trim(), isNotEmpty);
        expect(l10n.supSearchHint.trim(), isNotEmpty);
        expect(l10n.supSortName.trim(), isNotEmpty);
        expect(l10n.supSortEndDate.trim(), isNotEmpty);
        expect(l10n.supSortStatus.trim(), isNotEmpty);
        expect(l10n.supPrevMonth.trim(), isNotEmpty);
        expect(l10n.supNextMonth.trim(), isNotEmpty);
        expect(l10n.supEmptyMonth.trim(), isNotEmpty);
      }
    });
  });
}

/// Test-only JSON builder mirroring SupervisedInternshipResponse.
Map<String, dynamic> _row({
  String? startDate = '2026-01-05',
  String? endDate = '2026-03-31',
  String? internName = 'Amira Ben Salah',
  String? departmentName = 'DSI',
}) =>
    {
      'internshipId': 'i1',
      'reference': 'STG-2026-0042',
      'internName': internName,
      'status': 'IN_PROGRESS',
      'type': 'PFE',
      'startDate': startDate,
      'endDate': endDate,
      'departmentName': departmentName,
      'tasksTotal': 9,
      'tasksCompleted': 3,
      'pendingJournal': 2,
      'pendingDeliverables': 1,
      'evaluationsCount': 1,
    };
