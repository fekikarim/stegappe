import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/queue_harness.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/core/widgets/steg_states.dart';
import 'package:stegappe/core/widgets/user_avatar.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/data/cache/assistant_history_store.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/calendar.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/domain/greeting.dart';
import 'package:stegappe/features/internship/presentation/providers/assistant_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/notify_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/assistant_screen.dart';
import 'package:stegappe/features/internship/presentation/widgets/dashboard_sections.dart';
import 'package:stegappe/features/internship/presentation/screens/intern_home_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_home_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_tasks_screen.dart';
import 'package:stegappe/features/internship/presentation/widgets/home_header.dart';

import '../../test_fixtures.dart';

const _intern = AppUser(id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);
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

Future<FakeInternshipRepository> pumpHome(
  WidgetTester tester,
  Widget page, {
  AppUser user = _intern,
  FakeInternshipRepository? fake,
  bool online = true,
  Locale locale = const Locale('fr'),
  List<Override> extra = const [],
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(user)),
        internshipRepositoryProvider.overrideWithValue(repo),
        assistantHistoryStoreProvider
            .overrideWithValue(MemoryAssistantHistoryStore()),
        isOnlineProvider.overrideWith((ref) => online),
        await queueOverride(),
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

Future<AppLocalizations> loadL10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

SupervisedIntern _row({
  required String id,
  required String name,
  int submittedJournal = 0,
  int pendingJournal = 0,
  int pendingDeliverables = 0,
}) =>
    SupervisedIntern(
      internshipId: id,
      reference: 'REF-$id',
      internName: name,
      status: InternshipStatus.inProgress,
      type: InternshipType.perfectionnement,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 3, 31),
      departmentName: 'DSI',
      tasksCompleted: 1,
      tasksTotal: 4,
      pendingJournal: pendingJournal,
      submittedJournal: submittedJournal,
      pendingDeliverables: pendingDeliverables,
      evaluationsCount: 0,
    );

void main() {
  group('T13 greeting: deterministic bands, display only', () {
    test('band edges are exact', () {
      expect(greetingBand(DateTime(2026, 1, 1, 4, 59)), DayBand.night);
      expect(greetingBand(DateTime(2026, 1, 1, 5, 0)), DayBand.morning);
      expect(greetingBand(DateTime(2026, 1, 1, 11, 59)), DayBand.morning);
      expect(greetingBand(DateTime(2026, 1, 1, 12, 0)), DayBand.afternoon);
      expect(greetingBand(DateTime(2026, 1, 1, 17, 59)), DayBand.afternoon);
      expect(greetingBand(DateTime(2026, 1, 1, 18, 0)), DayBand.evening);
      expect(greetingBand(DateTime(2026, 1, 1, 22, 59)), DayBand.evening);
      expect(greetingBand(DateTime(2026, 1, 1, 23, 0)), DayBand.night);
      expect(greetingBand(DateTime(2026, 1, 1, 0, 0)), DayBand.night);
    });

    test('homeFirstName takes the first token, never crashes', () {
      expect(homeFirstName('Amira Ben Salah'), 'Amira');
      expect(homeFirstName('sup@steg.tn'), 'Sup');
      expect(homeFirstName('  '), '');
      expect(homeFirstName(''), '');
    });

    test('greeting sentences exist in fr/en/ar for every band', () async {
      for (final locale in ['fr', 'en', 'ar']) {
        final l10n = await loadL10n(locale);
        final now = DateTime(2026, 1, 1, 9);
        expect(greetingFor(l10n, 'Amira Ben Salah', now), contains('Amira'));
        expect(
            greetingFor(l10n, 'Amira Ben Salah',
                DateTime(2026, 1, 1, 15)),
            contains('Amira'));
      }
    });
  });

  group('T13 summary parsing: same rows as the lists', () {
    test('nested page sections decode with authoritative totals', () {
      final summary = internshipSummaryFromJson({
        'internship': {
          'id': 'i1',
          'reference': 'STG-1',
          'status': 'IN_PROGRESS',
          'startDate': '2026-01-01',
          'endDate': '2026-03-31',
        },
        'assignments': [
          {
            'id': 'a1',
            'departmentName': 'DSI',
            'supervisorName': 'S',
            'status': 'ACTIVE',
          },
        ],
        'tasks': {
          'content': [
            {'id': 't1', 'title': 'T', 'status': 'TODO'},
          ],
          'page': {'totalElements': 7, 'totalPages': 1, 'number': 0},
        },
        'tasksCompletedTotal': 2,
        'tasksGrandTotal': 7,
        'journal': {
          'content': [
            {
              'id': 'j1',
              'title': 'J',
              'status': 'DRAFT',
              'entryDate': '2026-02-01'
            },
          ],
          'page': {'totalElements': 4, 'totalPages': 1, 'number': 0},
        },
        'pendingJournalTotal': 3,
        'journalValidatedTotal': 1,
        'deliverables': {
          'content': [
            {
              'id': 'd1',
              'title': 'R',
              'status': 'SUBMITTED',
              'currentVersion': 1
            },
          ],
          'page': {'totalElements': 2, 'totalPages': 1, 'number': 0},
        },
        'deliverablesTotal': 2,
        'evaluations': {'content': [], 'page': {'totalElements': 0}},
        'notifications': {'content': [], 'page': {'totalElements': 0}},
      });
      expect(summary.internship.reference, 'STG-1');
      expect(summary.assignments, hasLength(1));
      expect(summary.tasks.single.title, 'T');
      // Totals are server values, never recomputed from the page.
      expect(summary.tasksGrandTotal, 7);
      expect(summary.tasksCompletedTotal, 2);
      expect(summary.pendingJournalTotal, 3);
      expect(summary.journalValidatedTotal, 1);
      expect(summary.deliverablesTotal, 2);
    });

    test('absent sections degrade to empty, never throw', () {
      final summary = internshipSummaryFromJson({
        'internship': {'id': 'i1', 'reference': 'STG-1'},
      });
      expect(summary.tasks, isEmpty);
      expect(summary.tasksGrandTotal, 0);
      expect(summary.assignments, isEmpty);
      expect(summary.notifications, isEmpty);
    });
  });

  group('T13 provider: one summary read replaces the fan-out', () {
    test('dashboard loads through internshipSummary exactly once',
        () async {
      final fake = FakeInternshipRepository();
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(_intern)),
        internshipRepositoryProvider.overrideWithValue(fake),
        isOnlineProvider.overrideWith((ref) => true),
      ]);
      addTearDown(container.dispose);
      await container
          .read(authControllerProvider.notifier)
          .bootstrap();
      final data =
          await container.read(dashboardProvider.future);
      expect(data.tasksTotal, 4);
      expect(fake.summaryCalls, 1);
      // The 13-call fan-out is gone: no section endpoint was touched.
      expect(fake.sectionCalls, isEmpty);
      // A rebuild reuses the cached snapshot (no duplicate request).
      await container.read(dashboardProvider.future);
      expect(fake.summaryCalls, 1);
    });
  });

  group('T13 queue totals: submitted-only journal tile', () {
    test('sums submitted rows, ignoring drafts and rejected', () {
      final totals = queueTotals([
        _row(id: 'a', name: 'A', submittedJournal: 2, pendingJournal: 5, pendingDeliverables: 1),
        _row(id: 'b', name: 'B', submittedJournal: 3, pendingJournal: 0, pendingDeliverables: 2),
      ]);
      expect(totals.submittedJournal, 5);
      expect(totals.submittedDeliverables, 3);
    });
  });

  group('T13 intern home: greeting, actions, sections', () {
    testWidgets('header, quick actions and sections render', (tester) async {
      final tabs = <int>[];
      await pumpHome(
          tester, InternHomeScreen(user: _intern, onOpenTab: tabs.add));
      final l10n = await loadL10n('fr');
      // Greeting carries the intern's first name; avatar + role present.
      expect(find.textContaining('Amira'), findsWidgets);
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.text(l10n.roleIntern), findsOneWidget);
      // Four quick actions, no more.
      for (final label in [
        l10n.qaTasks,
        l10n.qaJournal,
        l10n.qaAssistant,
        l10n.qaMessages
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      // Existing sections still fed by the same DashboardData.
      expect(find.text(l10n.myProgress), findsOneWidget);
      expect(find.text('${l10n.pendingJournalTitle} (1)'), findsOneWidget);
    });

    testWidgets('quick actions navigate to existing destinations',
        (tester) async {
      final tabs = <int>[];
      final l10n = await loadL10n('fr');
      await pumpHome(
          tester, InternHomeScreen(user: _intern, onOpenTab: tabs.add));

      await tester.tap(find.text(l10n.qaTasks));
      await tester.pumpAndSettle();
      expect(tabs, [1]);

      await tester.tap(find.text(l10n.qaJournal));
      await tester.pumpAndSettle();
      expect(tabs, [1, 2]);

      await tester.tap(find.text(l10n.qaAssistant));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantScreen), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.qaMessages));
      await tester.pumpAndSettle();
      expect(tabs, [1, 2, 3]);
    });

    testWidgets('no internship shows the honest empty state', (tester) async {
      final fake = FakeInternshipRepository()..noInternship = true;
      final l10n = await loadL10n('fr');
      await pumpHome(tester, InternHomeScreen(user: _intern),
          fake: fake);
      expect(find.text(l10n.noInternshipTitle), findsOneWidget);
      expect(fake.summaryCalls, 0);
    });

    testWidgets('offline renders the stale snapshot with a label',
        (tester) async {
      final fake = FakeInternshipRepository();
      await pumpHome(tester, InternHomeScreen(user: _intern),
          fake: fake, online: false);
      final l10n = await loadL10n('fr');
      // The fake serves reads offline (connectivity only gates writes);
      // the screen marks the snapshot stale instead of failing.
      expect(find.text(l10n.myProgress), findsOneWidget);
      expect(find.byType(StaleNotice), findsOneWidget);
      expect(fake.summaryCalls, 1);
    });

    testWidgets('arabic renders the home (RTL smoke)', (tester) async {
      await pumpHome(tester, InternHomeScreen(user: _intern),
          locale: const Locale('ar'));
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('T13 supervisor home: greeting, actions, scoped tiles', () {
    testWidgets('header, actions and T12-sourced tiles render', (tester) async {
      final tabs = <int>[];
      final fake = FakeInternshipRepository()
        ..supervisedOverride = [
          _row(id: 'a', name: 'Amira Ben Salah', submittedJournal: 2),
          _row(id: 'b', name: 'Karim Gharbi', submittedJournal: 3, pendingDeliverables: 1),
        ];
      final l10n = await loadL10n('fr');
      await pumpHome(tester,
          SupervisorHomeScreen(user: _sup, onOpenTab: tabs.add),
          user: _sup,
          fake: fake);

      expect(find.textContaining('Sup'), findsWidgets);
      expect(find.text(l10n.roleSupervisor), findsOneWidget);
      expect(find.text(l10n.supManageTasks), findsOneWidget);
      expect(find.text(l10n.qaValidations), findsOneWidget);
      expect(find.text(l10n.qaCalendar), findsOneWidget);
      // SU-HOME-02: the notify-to-prepare quick action is on the home.
      expect(find.text(l10n.notifyPrepareAsk), findsOneWidget);
      // "My interns" labels both the quick action and the list section.
      expect(find.text(l10n.myInterns), findsWidgets);
      // Tiles sum the scoped rows: journal 2+3, deliverables 0+1.
      expect(find.text('5'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Amira Ben Salah'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      expect(find.text('Amira Ben Salah'), findsWidgets);
    });

    testWidgets('calendar action opens the Interns tab in calendar view',
        (tester) async {
      final tabs = <int>[];
      final l10n = await loadL10n('fr');
      ProviderContainer? held;
      await pumpHome(tester,
          SupervisorHomeScreen(user: _sup, onOpenTab: tabs.add),
          user: _sup);
      final ctx = tester.element(find.byType(Scaffold).first);
      held = ProviderScope.containerOf(ctx);
      await tester.tap(find.text(l10n.qaCalendar));
      await tester.pumpAndSettle();
      expect(tabs, [1]);
      expect(
          held.read(supervisedViewProvider), SupervisedView.calendar);
    });

    testWidgets('notify-to-prepare opens the scoped list in select mode',
        (tester) async {
      final tabs = <int>[];
      final l10n = await loadL10n('fr');
      await pumpHome(tester,
          SupervisorHomeScreen(user: _sup, onOpenTab: tabs.add),
          user: _sup);
      final ctx = tester.element(find.byType(Scaffold).first);
      final container = ProviderScope.containerOf(ctx);
      expect(container.read(notifySelectModeProvider), isFalse);

      await tester.tap(find.text(l10n.notifyPrepareAsk));
      await tester.pumpAndSettle();

      // The Interns tab (1) in list view, with multi-select already on: the
      // supervisor picks the students from the server-scoped rows and the
      // send bar performs the call.
      expect(tabs, [1]);
      expect(container.read(notifySelectModeProvider), isTrue);
      expect(container.read(supervisedViewProvider), SupervisedView.list);
    });

    testWidgets('validations action opens the queue tab', (tester) async {
      final tabs = <int>[];
      final l10n = await loadL10n('fr');
      await pumpHome(tester,
          SupervisorHomeScreen(user: _sup, onOpenTab: tabs.add),
          user: _sup);
      await tester.tap(find.text(l10n.qaValidations));
      await tester.pumpAndSettle();
      expect(tabs, [2]);
    });

    testWidgets('manage tasks pushes the existing screen', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpHome(tester, SupervisorHomeScreen(user: _sup),
          user: _sup);
      await tester.tap(find.text(l10n.supManageTasks));
      await tester.pumpAndSettle();
      expect(find.byType(SupervisorTasksScreen), findsOneWidget);
    });

    testWidgets('error offers retry and recovers', (tester) async {
      final fake = FakeInternshipRepository()..failSupervised = true;
      final l10n = await loadL10n('fr');
      await pumpHome(tester, SupervisorHomeScreen(user: _sup),
          user: _sup, fake: fake);
      expect(find.byType(StegErrorView), findsOneWidget);
      fake.failSupervised = false;
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();
      // Recovery is proven by the error view disappearing; the intern rows
      // live in a lazily-built sliver under the (T14-extended) quick
      // actions, so scroll once to build them before asserting.
      expect(find.byType(StegErrorView), findsNothing);
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Amira Ben Salah'), findsWidgets);
    });

    testWidgets('empty scope is an empty state, not an error', (tester) async {
      final fake = FakeInternshipRepository()..supervisedOverride = [];
      final l10n = await loadL10n('fr');
      await pumpHome(tester, SupervisorHomeScreen(user: _sup),
          user: _sup, fake: fake);
      expect(find.text(l10n.noSupervised), findsOneWidget);
    });
  });

  group('T13 l10n: home keys', () {
    test('greeting and action keys exist in fr/en/ar', () async {
      for (final locale in ['fr', 'en', 'ar']) {
        final l10n = await loadL10n(locale);
        expect(l10n.homeGreetMorning('X').trim(), isNotEmpty);
        expect(l10n.homeGreetAfternoon('X').trim(), isNotEmpty);
        expect(l10n.homeGreetEvening('X').trim(), isNotEmpty);
        expect(l10n.homeGreetNight('X').trim(), isNotEmpty);
        expect(l10n.homeQuickActions.trim(), isNotEmpty);
        expect(l10n.qaTasks.trim(), isNotEmpty);
        expect(l10n.qaJournal.trim(), isNotEmpty);
        expect(l10n.qaAssistant.trim(), isNotEmpty);
        expect(l10n.qaMessages.trim(), isNotEmpty);
        expect(l10n.qaValidations.trim(), isNotEmpty);
        expect(l10n.qaCalendar.trim(), isNotEmpty);
      }
    });
  });
}
