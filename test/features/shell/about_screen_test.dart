import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/shell/presentation/about_screen.dart';

Future<AppLocalizations> loadL10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

Future<void> pumpAbout(WidgetTester tester,
    {Locale locale = const Locale('fr')}) async {
  await tester.pumpWidget(
    ProviderScope(
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
        home: const Scaffold(body: AboutScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('T14 about: safe public information only', () {
    testWidgets('brand, version, licences, support and privacy render',
        (tester) async {
      final l10n = await loadL10n('fr');
      await pumpAbout(tester);
      expect(find.text(l10n.aboutTitle), findsWidgets);
      expect(find.text(l10n.aboutSupport), findsOneWidget);
      expect(find.text(l10n.aboutSupportBody), findsOneWidget);
      expect(find.text(l10n.aboutPrivacy), findsOneWidget);
      expect(find.text(l10n.aboutPrivacyBody), findsOneWidget);
      expect(find.text(l10n.aboutLicenses), findsWidgets);
    });

    testWidgets('version row renders from platform metadata', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpAbout(tester);
      // In widget tests there is no platform channel, so the row falls
      // back to the localized label with an ellipsis — never blank, never
      // a hardcoded string. (Real devices resolve the pubspec version.)
      expect(find.text(l10n.aboutVersion('…')), findsOneWidget);
    });

    testWidgets('licences open the platform licence page', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpAbout(tester);
      await tester.tap(find.widgetWithText(ListTile, l10n.aboutLicenses));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('no secret, token, URL or personal data leaks', (tester) async {
      await pumpAbout(tester);
      await tester.pumpAndSettle();
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(' ')
          .toLowerCase();
      // Technical leak markers only: the privacy statement intentionally
      // names "CIN / mot de passe" as categories it never displays.
      for (final needle in [
        'bearer',
        'token',
        'secret',
        'http://',
        'https://',
        'resend',
        'gemini',
        '@',
      ]) {
        expect(texts.contains(needle), isFalse,
            reason: 'about screen leaks "$needle"');
      }
    });

    testWidgets('arabic renders the about page (RTL smoke)', (tester) async {
      await pumpAbout(tester, locale: const Locale('ar'));
      final l10n = await loadL10n('ar');
      expect(find.text(l10n.aboutPrivacy), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
