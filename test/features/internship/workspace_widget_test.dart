import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/intern_home_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/task_list_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/timeline_screen.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';

import '../../test_fixtures.dart';

const _intern =
    AppUser(id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<AppUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => _intern;
}

Future<void> pumpWorkspace(
  WidgetTester tester,
  Widget page, {
  FakeInternshipRepository? fake,
  bool online = true,
  Locale locale = const Locale('fr'),
  List<Override> extra = const [],
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => online),
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
}

void main() {
  group('Intern dashboard (acceptance)', () {
    testWidgets('shows today, progress, journal, deliverables, notifications',
        (tester) async {
      await pumpWorkspace(
          tester, const InternHomeScreen(user: _intern));

      // "What should I do?"
      expect(find.text('Aujourd’hui'), findsWidgets);
      expect(find.text('Today task'), findsOneWidget);
      expect(find.text('Overdue task'), findsOneWidget);
      // "How am I progressing?"
      expect(find.text('Ma progression'), findsOneWidget);
      expect(find.text('Tâches accomplies'), findsOneWidget);
      // "What did I do?"
      expect(find.textContaining('Journal en attente'), findsOneWidget);
      expect(find.text('Livrables'), findsOneWidget);
      expect(find.text('Notifications (1)'), findsOneWidget);
      // Backend-derived identity.
      expect(find.text('STG-2026-0001'), findsOneWidget);
      expect(find.textContaining('DSI'), findsOneWidget);
    });

    testWidgets('no linked internship shows honest empty state',
        (tester) async {
      final fake = FakeInternshipRepository()..noInternship = true;
      await pumpWorkspace(tester,
          const InternHomeScreen(user: _intern),
          fake: fake);
      expect(
          find.text('Aucun stage lié pour le moment'), findsOneWidget);
    });

    testWidgets('offline with cache shows stale notice, not blank',
        (tester) async {
      final data = fixtureDashboard(DateTime.now());
      await pumpWorkspace(
        tester,
        const InternHomeScreen(user: _intern),
        online: false,
        extra: [
          dashboardProvider.overrideWith((ref) {
            throw ApiException.network();
          }),
          lastDashboardProvider.overrideWith((ref) => data),
        ],
      );
      expect(
          find.text(
              'Données hors ligne — peuvent être obsolètes.'),
          findsOneWidget);
      expect(find.text('STG-2026-0001'), findsOneWidget);
    });

    testWidgets('arabic dashboard is genuinely RTL', (tester) async {
      await pumpWorkspace(
          tester, const InternHomeScreen(user: _intern),
          locale: const Locale('ar'));
      final ctx = tester.element(find.byType(InternHomeScreen));
      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(find.text('اليوم'), findsWidgets);
      expect(find.text('المهام المنجزة'), findsOneWidget);
    });

    testWidgets('timeline shows phase and backend milestones',
        (tester) async {
      await pumpWorkspace(tester, const TimelineScreen());
      expect(find.text('Chronologie du stage'), findsOneWidget);
      expect(find.text('Stage en cours'), findsOneWidget);
      expect(find.text('Début du stage'), findsOneWidget);
      expect(find.text('Fin du stage'), findsOneWidget);
      expect(find.textContaining('DSI'), findsOneWidget);
    });
  });

  group('Task list', () {
    testWidgets('renders filter chips and tasks', (tester) async {
      await pumpWorkspace(tester, const TaskListScreen());
      expect(find.text('Toutes'), findsOneWidget);
      // 'À faire' labels both the filter chip and open-task status chips.
      expect(find.text('À faire'), findsWidgets);
      expect(find.text('En cours'), findsWidgets);
      expect(find.text('Terminées'), findsOneWidget);
      expect(find.text('Today task'), findsOneWidget);
    });

    testWidgets('filter chip queries the backend with status',
        (tester) async {
      final fake = FakeInternshipRepository();
      await pumpWorkspace(tester, const TaskListScreen(), fake: fake);
      await tester.tap(find.text('Terminées'));
      await tester.pumpAndSettle();
      expect(fake.lastStatusFilter?.name, 'completed');
      expect(find.text('Done task'), findsOneWidget);
      expect(find.text('Today task'), findsNothing);
    });

    testWidgets('detail sheet offers server-confirmed transitions',
        (tester) async {
      final fake = FakeInternshipRepository();
      await pumpWorkspace(tester, const TaskListScreen(), fake: fake);
      // Explicit details chevron next to 'Today task' (checkbox taps
      // must never open the sheet as a side effect).
      await tester.tap(find.byTooltip('Today task'));
      await tester.pumpAndSettle();
      expect(find.text('Marquer comme terminée'), findsOneWidget);
      await tester.tap(find.text('Marquer comme terminée'));
      await tester.pumpAndSettle();
      expect(fake.statusUpdates,
          contains(('t-today', TaskStatus.completed)));
    });
  });
}
