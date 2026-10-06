import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/network/error_messages.dart';

AppLocalizations _fr() => const AppLocalizations(Locale('fr'));
AppLocalizations _en() => const AppLocalizations(Locale('en'));
AppLocalizations _ar() => const AppLocalizations(Locale('ar'));

ApiException _err(String code, int status) => ApiException(
    kind: ApiErrorKind.values.firstWhere(
      (k) => switch (status) {
        503 => k == ApiErrorKind.server,
        422 => k == ApiErrorKind.validation,
        409 => k == ApiErrorKind.conflict,
        _ => k == ApiErrorKind.unknown,
      },
    ),
    message: code,
    statusCode: status,
    code: code);

void main() {
  group('T03 error mapping (centralized, never raw)', () {
    test('AI outage and malformed output share the degraded sentence', () {
      for (final code in [
        'AI_UNAVAILABLE',
        'AI_TEMPORARILY_UNAVAILABLE',
        'AI_GENERATION_INVALID',
        'AI_GENERATION_FAILED',
      ]) {
        final fr = userErrorOf(_err(code, 503), _fr());
        expect(fr.message, _fr().errAiUnavailable);
        expect(fr.message, isNot(contains('AI_UNAVAILABLE')));
        expect(fr.message, isNot(contains('Exception')));
      }
    });

    test('stale classification explains reload (never overwrites silently)',
        () {
      final err = userErrorOf(_err('CATEGORY_CHANGED', 409), _fr());
      expect(err.message, _fr().errCategoryChanged);
      expect(err.retryable, isFalse);
    });

    test('missing categories explains the manual path first', () {
      final err =
          userErrorOf(_err('CATEGORY_SUGGESTION_NO_CATEGORIES', 422), _fr());
      expect(err.message, _fr().errCategoryNoCategories);
    });

    test('other category/apply validations share one honest sentence', () {
      for (final code in [
        'CATEGORY_NAME_INVALID',
        'CATEGORY_NAME_DUPLICATE',
        'CATEGORY_COLOR_INVALID',
        'CATEGORY_LIMIT_REACHED',
        'CATEGORY_REORDER_INVALID',
        'APPLY_EMPTY',
        'APPLY_TOO_LARGE',
      ]) {
        final err = userErrorOf(_err(code, 422), _fr());
        expect(err.message, _fr().errCategoryInvalid);
        expect(err.message, isNot(contains(code)));
      }
    });

    test('sentences are localized in fr/en/ar', () {
      expect(_en().errCategoryChanged, isNot(_fr().errCategoryChanged));
      expect(_ar().errCategoryChanged, isNot(_fr().errCategoryChanged));
      expect(_en().errCategoryInvalid, isNotEmpty);
      expect(_ar().errCategoryNoCategories, isNotEmpty);
      expect(_ar().catAcceptAll, isNotEmpty);
    });
  });
}
