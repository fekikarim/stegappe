import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/core/widgets/user_avatar.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/auth/presentation/screens/change_password_screen.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/shell/presentation/profile_screen.dart';

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

Future<FakeInternshipRepository> pumpProfile(
  WidgetTester tester, {
  AppUser user = _intern,
  FakeInternshipRepository? fake,
  Locale locale = const Locale('fr'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(user)),
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
        home: const Scaffold(body: ProfileScreen()),
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
  group('T14 profile: read-only identity, no sensitive data', () {
    testWidgets('intern sees avatar, email, role and internship facts',
        (tester) async {
      final l10n = await loadL10n('fr');
      await pumpProfile(tester);
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(find.text('intern@u.tn'), findsWidgets);
      expect(find.text(l10n.roleIntern), findsOneWidget);
      expect(find.text(l10n.profileReadOnly), findsOneWidget);
      expect(find.text(l10n.profileInternship), findsOneWidget);
      // No editable affordance anywhere on the screen.
      expect(find.byType(TextField), findsNothing);
      expect(find.text(l10n.profileChangePassword), findsOneWidget);
    });

    testWidgets('no CIN, password, token or raw id appears', (tester) async {
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(' ');
      expect(texts.contains('u1'), isFalse);
      expect(texts.toLowerCase().contains('token'), isFalse);
      expect(texts.toLowerCase().contains('bearer'), isFalse);
      expect(texts.contains('CIN'), isFalse);
      // No password input anywhere (the change-password screen owns it).
      expect(
          find.byWidgetPredicate(
              (w) => w is TextField && w.obscureText == true),
          findsNothing);
    });

    testWidgets('change-password entry opens the existing flow',
        (tester) async {
      final l10n = await loadL10n('fr');
      await pumpProfile(tester);
      await tester.tap(find.text(l10n.profileChangePassword));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('supervisor sees scope count instead of an internship',
        (tester) async {
      final l10n = await loadL10n('fr');
      await pumpProfile(tester, user: _sup);
      expect(find.text('sup@steg.tn'), findsWidgets);
      expect(find.text(l10n.roleSupervisor), findsOneWidget);
      expect(find.text(l10n.profileInternship), findsNothing);
      expect(find.text(l10n.myInterns), findsOneWidget);
    });

    testWidgets('arabic renders the profile (RTL smoke)', (tester) async {
      await pumpProfile(tester, locale: const Locale('ar'));
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
