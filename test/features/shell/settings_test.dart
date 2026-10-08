import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/shell/presentation/about_screen.dart';
import 'package:stegappe/features/shell/presentation/auth_gate.dart';
import 'package:stegappe/features/shell/presentation/more_tab.dart';
import 'package:stegappe/features/shell/presentation/profile_screen.dart';

import '../../support/shell_harness.dart';
import '../../test_fixtures.dart';

const _intern = AppUser(id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);

class _FakeAuth implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<AppUser> login({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<void> logout() async {
    logoutCalls++;
  }
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => _intern;
}

Future<({FakeInternshipRepository repo, _FakeAuth auth})> pumpMore(
  WidgetTester tester, {
  FakeInternshipRepository? fake,
  Locale locale = const Locale('fr'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = fake ?? FakeInternshipRepository();
  final auth = _FakeAuth();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        internshipRepositoryProvider.overrideWithValue(repo),
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
        home: const Scaffold(body: MoreTab()),
      ),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
  return (repo: repo, auth: auth);
}

Future<AppLocalizations> loadL10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

/// The settings page is a lazily-built ListView: scroll the target into
/// view before tapping or asserting (drag the list directly — the tree
/// holds more than one scrollable, so the single-scrollable helpers fail).
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  // Nudge further in: a just-revealed edge row misses hit tests.
  await tester.drag(find.byType(ListView).first, const Offset(0, -120));
  await tester.pumpAndSettle();
}

void main() {
  group('T14 settings: sections, language, theme, about, logout', () {
    testWidgets('sections render with identity, no raw user id', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpMore(tester);
      expect(find.text('intern@u.tn'), findsWidgets);
      expect(find.text(l10n.accountTitle), findsOneWidget);
      expect(find.text(l10n.appearanceTitle), findsOneWidget);
      await scrollTo(tester, find.text(l10n.language));
      expect(find.text(l10n.language), findsOneWidget);
      await scrollTo(tester, find.text(l10n.aboutTitle));
      expect(find.text(l10n.aboutTitle), findsWidgets);
      await scrollTo(tester, find.text(l10n.logout));
      expect(find.text(l10n.logout), findsOneWidget);
      // The raw UUID carries no meaning for the user and stays out of
      // the UI (and therefore out of screenshots).
      expect(find.text('u1'), findsNothing);
    });

    testWidgets('language switch applies immediately and syncs best-effort',
        (tester) async {
      final h = await pumpMore(tester);
      await scrollTo(tester, find.text('English'));
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      final code = ProviderScope.containerOf(ctx)
          .read(localeProvider)
          ?.languageCode;
      expect(code, 'en');
      expect(h.repo.localeSyncCalls, 1);
      expect(h.repo.lastLocaleSynced, 'en');
    });

    testWidgets('a failed server sync never blocks the switch', (tester) async {
      final fake = FakeInternshipRepository()..failLocaleSync = true;
      final h = await pumpMore(tester, fake: fake);
      await scrollTo(tester, find.text('English'));
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(
          ProviderScope.containerOf(ctx).read(localeProvider)?.languageCode,
          'en');
      expect(h.repo.localeSyncCalls, 0);
    });

    testWidgets('theme switch persists across the provider', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpMore(tester);
      // Theme names come from the localized theme section.
      await scrollTo(tester, find.text('Sombre'));
      await tester.tap(find.text('Sombre'));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(
          ProviderScope.containerOf(ctx).read(themeModeProvider),
          StegThemeMode.dark);
      expect(l10n.themeDark, isNotEmpty);
    });

    testWidgets('about entry opens the about screen', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpMore(tester);
      final row = find.widgetWithText(ListTile, l10n.aboutTitle);
      await scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.text(l10n.aboutSupport), findsOneWidget);
    });

    testWidgets('profile entry opens the profile screen', (tester) async {
      await pumpMore(tester);
      final l10n = await loadL10n('fr');
      final row = find.widgetWithText(ListTile, l10n.profileTitle);
      await scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('logout asks for confirmation; cancel keeps the session',
        (tester) async {
      final h = await pumpMore(tester);
      final l10n = await loadL10n('fr');
      await scrollTo(tester, find.text(l10n.logout));
      await tester.tap(find.text(l10n.logout));
      await tester.pumpAndSettle();
      expect(find.text(l10n.logoutConfirmTitle), findsOneWidget);
      await tester.tap(find.text(l10n.cancelAction));
      await tester.pumpAndSettle();
      expect(h.auth.logoutCalls, 0);
      expect(find.byType(MoreTab), findsOneWidget);
    });

    testWidgets('logout confirm signs out', (tester) async {
      final h = await pumpMore(tester);
      final l10n = await loadL10n('fr');
      await scrollTo(tester, find.text(l10n.logout));
      await tester.tap(find.text(l10n.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.logout).last);
      await tester.pumpAndSettle();
      expect(h.auth.logoutCalls, 1);
    });

    testWidgets('arabic renders settings (RTL smoke)', (tester) async {
      await pumpMore(tester, locale: const Locale('ar'));
      final l10n = await loadL10n('ar');
      await scrollTo(tester, find.text(l10n.aboutTitle));
      expect(find.text(l10n.aboutTitle), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('T14 locale isolation across accounts', () {
    test('the controller can drop the device language choice', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsStore(await SharedPreferences.getInstance());
      final controller = LocaleController(prefs);
      await controller.setLocale(const Locale('ar'));
      expect(controller.state?.languageCode, 'ar');
      await controller.resetToDeviceDefault();
      expect(controller.state, isNull);
      expect(prefs.readLocale(), isNull);
    });

    testWidgets('sign-out clears the stored language (next user starts clean)',
        (tester) async {
      // A left the device in Arabic; B must not be greeted in it.
      await pumpAuthGate(
        tester,
        user: _intern,
        seedPrefs: {PrefsStore.kLocale: 'ar'},
      );
      final ctx = tester.element(find.byType(AuthGate));
      final container = ProviderScope.containerOf(ctx);
      expect(container.read(localeProvider)?.languageCode, 'ar');

      await container.read(authControllerProvider.notifier).logout();
      await tester.pumpAndSettle();

      expect(container.read(localeProvider), isNull);
      expect(container.read(prefsStoreProvider).readLocale(), isNull);
      expect(container.read(authControllerProvider),
          isA<AuthUnauthenticated>());
    });
  });
}
