import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/features/auth/presentation/screens/change_password_screen.dart';
import 'package:stegappe/features/auth/presentation/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoginScreen allows pasting via keyboard shortcut',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': 'test-intern@steg.com.tn'};
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('fr'),
          supportedLocales: StegLocales.supported,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify NO paste button exists in the UI
    expect(find.byTooltip('Coller / Paste'), findsNothing);

    // Tap the email field to focus it
    final emailFieldFinder = find.byType(TextField).first;
    await tester.tap(emailFieldFinder);
    await tester.pumpAndSettle();

    // Send Cmd+V (meta + V)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    // Verify text was pasted into the field
    expect(find.text('test-intern@steg.com.tn'), findsOneWidget);
  });

  testWidgets('ChangePasswordScreen allows pasting via keyboard shortcut',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': 'TempPass12345678!'};
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('fr'),
          supportedLocales: StegLocales.supported,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ChangePasswordScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify NO paste button exists in the UI
    expect(find.byTooltip('Coller / Paste'), findsNothing);

    // Tap first text field (current temporary password)
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));
    await tester.tap(textFields.at(0));
    await tester.pumpAndSettle();

    // Send Cmd+V (meta + V)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    final currentField = tester.widget<TextField>(textFields.at(0));
    expect(currentField.controller?.text, 'TempPass12345678!');
  });
}
