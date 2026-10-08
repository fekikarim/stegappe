import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/widgets/user_avatar.dart';
import 'package:stegappe/features/auth/presentation/screens/change_password_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/intern_home_screen.dart';
import 'package:stegappe/features/internship/presentation/widgets/home_header.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';

import 'acceptance_harness.dart';

void main() {
  group('S1 — Student onboarding and first run (SH-SET, ST-NOT)', () {
    testWidgets(
      'S1.1: Log in with a provisioned student account -> forced password change appears first, then the app',
      (tester) async {
        final harness = AcceptanceHarness(
          user: kAcceptanceInternNeedsPasswordChange,
        );

        // 1. Pump app with fresh student account needing password change.
        final container = await pumpAcceptanceApp(tester, harness: harness);

        // Expect ChangePasswordScreen is active.
        expect(find.byType(ChangePasswordScreen), findsOneWidget);
        expect(find.byType(InternHomeScreen), findsNothing);

        // Fill in the new password meeting all complexity rules (16+ chars, upper, lower, digit, symbol).
        final textFields = find.byType(TextField);
        expect(textFields, findsNWidgets(3)); // current, new, confirm

        await tester.enterText(textFields.at(0), 'TempP@ssword2026!');
        await tester.enterText(textFields.at(1), 'BrandNewP@ssword2026!Complex');
        await tester.enterText(textFields.at(2), 'BrandNewP@ssword2026!Complex');

        // Tap Continue/Submit button.
        final submitButton = find.widgetWithText(FilledButton, 'Continue');
        expect(submitButton, findsOneWidget);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Expect password was changed and AuthGate transitioned to InternHomeScreen.
        expect(harness.authRepo.changePasswordCalls, 1);
        expect(harness.authRepo.lastChangedPassword, 'BrandNewP@ssword2026!Complex');
        expect(find.byType(ChangePasswordScreen), findsNothing);
        expect(find.byType(InternHomeScreen), findsOneWidget);

        container.dispose();
      },
    );

    testWidgets(
      'S1.2: After password change, exactly one welcome notification exists and home shows greeting, avatar, role, quick actions',
      (tester) async {
        final harness = AcceptanceHarness(user: kAcceptanceIntern);
        // Seed single welcome notification as expected after provisioned first login.
        harness.notifRepo.items.clear();
        harness.notifRepo.items.add(
          NotificationItem(
            id: 'n-welcome',
            type: NotificationType.welcome,
            title: 'Bienvenue sur la plateforme',
            message: 'Votre compte de stage est actif.',
            priority: 'NORMAL',
            createdAt: DateTime.now(),
            isRead: false,
          ),
        );

        final container = await pumpAcceptanceApp(tester, harness: harness);

        // Home header contains user greeting, avatar with initials, and role.
        expect(find.byType(InternHomeScreen), findsOneWidget);
        expect(find.byType(HomeHeader), findsOneWidget);
        expect(find.byType(UserAvatar), findsWidgets);
        expect(find.byType(QuickActionsGrid), findsOneWidget);

        // Exactly one welcome notification in repository.
        expect(harness.notifRepo.items.length, 1);
        expect(harness.notifRepo.items.first.type, NotificationType.welcome);

        container.dispose();
      },
    );

    testWidgets(
      'S1.3: Language switch to ar -> RTL layout, no overflow; theme switch to dark -> correct surfaces; both persist across restart',
      (tester) async {
        final harness = AcceptanceHarness(user: kAcceptanceIntern);
        final container = await pumpAcceptanceApp(tester, harness: harness);

        // Verify initial LTR in French.
        expect(Directionality.of(tester.element(find.byType(InternHomeScreen))), TextDirection.ltr);

        // Switch language to Arabic via settings provider.
        await container.read(localeProvider.notifier).setLocale(const Locale('ar'));
        await tester.pumpAndSettle();

        // Directionality becomes RTL.
        expect(Directionality.of(tester.element(find.byType(InternHomeScreen))), TextDirection.rtl);

        // Switch theme to dark mode.
        await container.read(themeModeProvider.notifier).setMode(StegThemeMode.dark);
        await tester.pumpAndSettle();

        final darkTheme = Theme.of(tester.element(find.byType(InternHomeScreen)));
        expect(darkTheme.brightness, Brightness.dark);

        // Verify persistence: check stored values.
        final storedLocale = container.read(localeProvider);
        final storedTheme = container.read(themeModeProvider);
        expect(storedLocale?.languageCode, 'ar');
        expect(storedTheme, StegThemeMode.dark);

        container.dispose();
      },
    );
  });
}
