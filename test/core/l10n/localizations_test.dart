import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('every key has fr, en and ar translations', () {
      for (final entry in AppLocalizations.allValues.entries) {
        for (final lang in ['fr', 'en', 'ar']) {
          expect(entry.value[lang],
              isNotNullWhere((_) => true, reason: '${entry.key} missing $lang'),
              reason: '${entry.key} missing $lang');
          expect(entry.value[lang]!.trim().isNotEmpty, isTrue,
              reason: '${entry.key} empty for $lang');
        }
      }
    });

    test('arabic is rtl, french/english are ltr', () {
      expect(StegLocales.isRtl(StegLocales.arabic), isTrue);
      expect(StegLocales.isRtl(StegLocales.french), isFalse);
      expect(StegLocales.isRtl(StegLocales.english), isFalse);
    });

    test('french is default fallback', () {
      expect(StegLocales.resolve(null).languageCode, 'fr');
      expect(StegLocales.resolve('xx').languageCode, 'fr');
      expect(StegLocales.resolve('ar').languageCode, 'ar');
    });
  });
}

Matcher isNotNullWhere(bool Function(dynamic _) test, {String? reason}) =>
    isNotNull;
