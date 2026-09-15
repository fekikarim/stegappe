import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/core/widgets/connectivity_banner.dart';
import 'package:stegappe/core/widgets/steg_button.dart';
import 'package:stegappe/core/widgets/steg_status_chip.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/shell/presentation/auth_gate.dart';
import 'package:stegappe/features/shell/presentation/role_shells.dart';

class _FakeRepo implements AuthRepository {
  _FakeRepo(this.user);
  final AppUser? user;

  @override
  Future<AppUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => user != null;
  @override
  Future<AppUser?> restoreSession() async => user;
}

Future<void> _pumpGate(
  WidgetTester tester, {
  AppUser? user,
  Locale locale = const Locale('fr'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(_FakeRepo(user)),
        // Force online so connectivity stream (async) cannot hide content.
        isOnlineProvider.overrideWith((ref) => true),
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
        home: const AuthGate(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Authenticated shells (acceptance)', () {
    testWidgets('intern shell renders 5 tabs', (tester) async {
      await _pumpGate(
        tester,
        user: const AppUser(
            id: 'i1', email: 'intern@u.tn', roles: ['INTERN']),
      );
      expect(find.byType(InternShell), findsOneWidget);
      for (final label in ['Accueil', 'Tâches', 'Journal', 'Messages', 'Plus']) {
        expect(find.text(label), findsWidgets);
      }
    });

    testWidgets('supervisor shell renders role tabs', (tester) async {
      await _pumpGate(
        tester,
        user: const AppUser(
            id: 's1', email: 'sup@steg.tn', roles: ['SUPERVISOR']),
      );
      expect(find.byType(SupervisorShell), findsOneWidget);
      expect(find.text('Stagiaires'), findsWidgets);
      expect(find.text('Validations'), findsWidgets);
    });

    testWidgets('unsupported backend role shows access-denied', (tester) async {
      await _pumpGate(
        tester,
        user: const AppUser(
            id: 'h1', email: 'hr@steg.tn', roles: ['HR']),
      );
      expect(find.byType(UnsupportedRoleScreen), findsOneWidget);
      expect(
          find.text(
              'Ce rôle n’est pas pris en charge dans l’application mobile.'),
          findsOneWidget);
    });

    testWidgets('no session shows login', (tester) async {
      await _pumpGate(tester);
      expect(find.text('Connexion'), findsWidgets);
      expect(find.text('Se connecter'), findsOneWidget);
    });
  });

  group('RTL verification on actual widgets', () {
    testWidgets('arabic pumps real RTL Directionality', (tester) async {
      await _pumpGate(tester,
          user: const AppUser(
              id: 'i1', email: 'intern@u.tn', roles: ['INTERN']),
          locale: const Locale('ar'));
      final ctx = tester.element(find.byType(InternShell));
      expect(Directionality.of(ctx), TextDirection.rtl);
      // Arabic labels render on real widgets, not just dir attribute.
      expect(find.text('الرئيسية'), findsWidgets);
      expect(find.text('المهام'), findsWidgets);
    });
  });

  group('Design system', () {
    testWidgets('StegButton meets 48px touch target + semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StegButton(
                label: 'Save changes',
                onPressed: () => tapped = true),
          ),
        ),
      );
      final box = tester.getSize(find.byType(StegButton));
      expect(box.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.byType(StegButton)),
        matchesSemantics(
            label: 'Save changes',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true),
      );
      await tester.tap(find.byType(StegButton));
      expect(tapped, isTrue);
      semantics.dispose();
    });

    testWidgets('StegStatusChip carries text label (never color-only)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StegStatusChip(
                label: 'En cours', kind: StegStatusKind.info),
          ),
        ),
      );
      expect(find.text('En cours'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('ConnectivityBanner announces offline state', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: StegLocales.supported,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: ConnectivityBanner(isOnline: false),
          ),
        ),
      );
      expect(find.textContaining('Hors ligne'), findsWidgets);
      expect(
        find.bySemanticsLabel(
            'Hors ligne — les données affichées peuvent être obsolètes.'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
