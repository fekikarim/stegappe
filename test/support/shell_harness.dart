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
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/shell/presentation/auth_gate.dart';

import '../test_fixtures.dart';

/// Auth repository that restores a fixed user (or none) without network.
class HarnessAuthRepository implements AuthRepository {
  HarnessAuthRepository(this.user);

  final AppUser? user;

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
  Future<bool> refreshSession() async => user != null;

  @override
  Future<AppUser?> restoreSession() async => user;
}

/// Pumps the real [AuthGate] with a fixed session so the role → shell routing
/// can be asserted end to end.
Future<void> pumpAuthGate(
  WidgetTester tester, {
  AppUser? user,
  Locale locale = const Locale('fr'),
  Map<String, Object> seedPrefs = const {},
  bool reduceMotion = false,
}) async {
  SharedPreferences.setMockInitialValues(seedPrefs);
  final prefs = await PrefsStore.load();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(HarnessAuthRepository(user)),
        isOnlineProvider.overrideWith((ref) => true),
        internshipRepositoryProvider
            .overrideWithValue(FakeInternshipRepository()),
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
        // T15 motion: the platform's reduce-motion flag is read from the
        // ambient MediaQuery (`MediaQueryData.disableAnimations`), so the
        // shell's swap can be exercised in both states. `copyWith` keeps the
        // window metrics the framework already resolved.
        home: Builder(
          builder: (context) {
            if (!reduceMotion) return const AuthGate();
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: true),
              child: const AuthGate(),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
