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
import 'package:stegappe/features/internship/presentation/screens/intern_home_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/progress_screen.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/messaging/presentation/screens/chat_screen.dart';

import 'test_fixtures.dart';
import 'features/messaging/messaging_widget_test.dart'
    show FakeMessagingRepo, FakeNotifRepo, FakeStomp;
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';

class _FakeAuth implements AuthRepository {
  @override
  Future<AppUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => const AppUser(
      id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);
}

/// D6 audit: 2x text scaling + Arabic RTL must not overflow or crash on
/// key screens (WCAG text-spacing/zoom resilience).
Future<void> pumpStressed(
  WidgetTester tester,
  Widget page, {
  FakeInternshipRepository? fake,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  final stomp = FakeStomp();
  stomp.setState(ChatConnectionState.connected);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth()),
        internshipRepositoryProvider.overrideWithValue(repo),
        messagingRepositoryProvider.overrideWithValue(
            FakeMessagingRepo(stomp: stomp)),
        notificationRepositoryProvider
            .overrideWithValue(FakeNotifRepo()),
        stompChatServiceProvider.overrideWithValue(stomp),
        isOnlineProvider.overrideWith((ref) => true),
      ],
      child: MediaQuery(
        data: const MediaQueryData(
            textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          locale: const Locale('ar'),
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
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
}

void main() {
  group('D6 a11y stress (2x text + Arabic RTL)', () {
    testWidgets('dashboard survives', (tester) async {
      const user = AppUser(
          id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);
      await pumpStressed(
          tester, const InternHomeScreen(user: user));
      expect(find.text('اليوم'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('progress + logbook entry survive', (tester) async {
      await pumpStressed(tester, const ProgressScreen());
      expect(find.text('التقدم العام'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chat survives', (tester) async {
      await pumpStressed(
          tester,
          const ChatScreen(
              conversationId: 'c1', title: 't'));
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
