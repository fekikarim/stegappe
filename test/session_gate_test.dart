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
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/shell/presentation/auth_gate.dart';

import 'test_fixtures.dart';
import 'features/messaging/messaging_widget_test.dart'
    show FakeMessagingRepo, FakeNotifRepo, FakeStomp;
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';

class _GateAuth implements AuthRepository {
  var loggedOut = false;

  @override
  Future<AppUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => const AppUser(
      id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);
}

/// D7 gate: logout tears down the session completely — tokens revoked
/// (repo), socket disconnected, fresh service on next login — and the
/// UI returns to the login screen (crash-free transition).
void main() {
  testWidgets('logout disconnects socket and returns to login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final auth = _GateAuth();
    final stomp = FakeStomp();
    stomp.setState(ChatConnectionState.connected);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          internshipRepositoryProvider
              .overrideWithValue(FakeInternshipRepository()),
          messagingRepositoryProvider.overrideWithValue(
              FakeMessagingRepo(stomp: stomp)),
          notificationRepositoryProvider
              .overrideWithValue(FakeNotifRepo()),
          stompChatServiceProvider.overrideWithValue(stomp),
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
          home: const AuthGate(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Authenticated shell with bell + dashboard.
    expect(find.text('Accueil'), findsWidgets);
    expect(auth.loggedOut, isFalse);

    await tester.tap(find.byTooltip('Déconnexion'));
    await tester.pumpAndSettle();

    expect(auth.loggedOut, isTrue);
    expect(stomp.currentState, ChatConnectionState.disconnected);
    // Back at login, no crash, no leftover shell.
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Accueil'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
