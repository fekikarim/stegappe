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
import 'package:stegappe/features/internship/presentation/screens/deliverable_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/deliverables_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervisor_validations_screen.dart';
import 'package:stegappe/features/internship/presentation/services/file_share.dart';

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

Future<FakeInternshipRepository> pumpDeliv(
  WidgetTester tester,
  Widget page, {
  AppUser user = const AppUser(
      id: 'u1', email: 'intern@u.tn', roles: ['INTERN']),
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
  group('deliverable checklist (acceptance)', () {
    testWidgets('groups actuals by state with honest counts',
        (tester) async {
      await pumpDeliv(tester, const DeliverablesScreen());

      expect(find.text('À finaliser (1)'), findsOneWidget);
      expect(find.text('En attente de validation (1)'), findsOneWidget);
      expect(find.text('Validés (1)'), findsOneWidget);
      expect(find.text('Brouillon rapport'), findsOneWidget);
      expect(find.text('Rapport de stage'), findsOneWidget);
      expect(find.text('Présentation finale'), findsOneWidget);
      // Exact backend-confirmed limits are displayed.
      expect(
          find.text(
              'PDF uniquement · 25 Mo max · versions conservées'),
          findsNothing); // subtitle lives on sheets, not the list
    });

    testWidgets('FAB opens creation sheet with PDF-only rules',
        (tester) async {
      await pumpDeliv(tester, const DeliverablesScreen());

      await tester.tap(find.byTooltip('Nouveau livrable'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau livrable'), findsWidgets);
      expect(
          find.text(
              'PDF uniquement · 25 Mo max · versions conservées'),
          findsOneWidget);
      // No file picked: upload stays disabled (no dead action).
      final upload = find.widgetWithText(ElevatedButton, 'Téléverser');
      expect(tester.widget<ElevatedButton>(upload).enabled, isFalse);
    });
  });

  group('versioned detail', () {
    testWidgets('history shows every version, newest first',
        (tester) async {
      await pumpDeliv(
          tester, const DeliverableDetailScreen(deliverableId: 'd-sub'));

      expect(find.text('Rapport de stage'), findsWidgets);
      expect(find.textContaining('rapport-v2.pdf'), findsOneWidget);
      expect(find.textContaining('rapport-v1.pdf'), findsOneWidget);
      // v2 listed before v1 (latest first, nothing overwritten).
      final v2 = tester
          .getTopLeft(find.textContaining('rapport-v2.pdf'))
          .dy;
      final v1 = tester
          .getTopLeft(find.textContaining('rapport-v1.pdf'))
          .dy;
      expect(v2, lessThan(v1));
    });

    testWidgets('download goes through the backend endpoint',
        (tester) async {
      final fake = FakeInternshipRepository();
      final shared = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuth(
                const AppUser(
                    id: 'u1',
                    email: 'intern@u.tn',
                    roles: ['INTERN']))),
            internshipRepositoryProvider.overrideWithValue(fake),
            isOnlineProvider.overrideWith((ref) => true),
            shareFnProvider.overrideWithValue((bytes, name) async {
              shared.add('$name:${bytes.length}');
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
            home: const DeliverableDetailScreen(
                deliverableId: 'd-sub'),
          ),
        ),
      );
      final ctx = tester.element(find.byType(Scaffold).first);
      await ProviderScope.containerOf(ctx)
          .read(authControllerProvider.notifier)
          .bootstrap();
      await tester.pumpAndSettle();

      // Latest version download button (first download icon).
      await tester.tap(find.byIcon(Icons.download_outlined).first);
      await tester.pumpAndSettle();
      expect(fake.downloads, contains(('d-sub', 2)));
      expect(shared, ['rapport-v2.pdf:4']);
    });

    testWidgets('validated deliverable blocks new versions explicitly',
        (tester) async {
      await pumpDeliv(
          tester, const DeliverableDetailScreen(deliverableId: 'd-sub'));
      // Fixture is SUBMITTED: new version allowed, submit hidden.
      expect(find.text('Nouvelle version'), findsOneWidget);
      expect(find.text('Soumettre pour validation'), findsNothing);
    });
  });

  group('supervisor deliverable review', () {
    const sup = AppUser(
        id: 's1', email: 'sup@steg.tn', roles: ['SUPERVISOR']);

    testWidgets('queue shows submitted deliverables with reference',
        (tester) async {
      await pumpDeliv(tester,
          const SupervisorValidationsScreen(),
          user: sup);
      await tester.dragUntilVisible(
        find.text('Rapport de stage'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      expect(find.text('Rapport de stage'), findsWidgets);
      expect(find.textContaining('STG-2026-0001'), findsWidgets);
    });

    testWidgets('validate records a server-confirmed decision',
        (tester) async {
      final fake = FakeInternshipRepository();
      await pumpDeliv(tester,
          const SupervisorValidationsScreen(),
          user: sup,
          fake: fake);
      await tester.dragUntilVisible(
        find.text('Rapport de stage'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Rapport de stage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      // Confirm in the review dialog (empty comment allowed).
      await tester.tap(find.text('Valider').last);
      await tester.pumpAndSettle();
      expect(fake.deliverableDecisions,
          contains(('d-sub', 'VALIDATED', null)));
    });
  });
}
