import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/network/error_messages.dart';

/// T00 · acceptance criterion 3 — one central error → localized sentence.
void main() {
  const fr = AppLocalizations(Locale('fr'));
  const en = AppLocalizations(Locale('en'));
  const ar = AppLocalizations(Locale('ar'));

  ApiException of(ApiErrorKind kind,
          {int? status, String? code, List<FieldError> fields = const []}) =>
      ApiException(
          kind: kind, message: 'raw backend text', statusCode: status, code: code,
          fieldErrors: fields);

  group('one case per ApiErrorKind', () {
    test('network → connection-required message, retryable, offline flag', () {
      final e = userErrorOf(ApiException.network(), fr);
      expect(e.message, fr.errNetwork);
      expect(e.requiresConnectivity, isTrue);
      expect(e.retryable, isTrue);
    });

    test('unauthorized → session expired, not retryable (revocation path)', () {
      final e = userErrorOf(of(ApiErrorKind.unauthorized, status: 401), fr);
      expect(e.message, fr.errSessionExpired);
      expect(e.sessionExpired, isTrue);
      expect(e.retryable, isFalse);
    });

    test('forbidden → permission message', () {
      final e = userErrorOf(of(ApiErrorKind.forbidden, status: 403), fr);
      expect(e.message, fr.errForbidden);
      expect(e.forbidden, isTrue);
      expect(e.retryable, isFalse);
    });

    test('notFound → not-found message', () {
      final e = userErrorOf(of(ApiErrorKind.notFound, status: 404), fr);
      expect(e.message, fr.errNotFound);
      expect(e.notFound, isTrue);
    });

    test('conflict → refresh-and-retry message', () {
      final e = userErrorOf(of(ApiErrorKind.conflict, status: 409), fr);
      expect(e.message, fr.errConflict);
    });

    test('validation without field details → bad-request sentence', () {
      final e = userErrorOf(of(ApiErrorKind.validation, status: 422), fr);
      expect(e.message, fr.errBadRequest);
      expect(e.retryable, isFalse);
    });

    test('validation with field details → form sentence + field messages', () {
      final e = userErrorOf(
        of(ApiErrorKind.validation, status: 400, fields: const [
          FieldError(field: 'email', message: 'must be a valid email'),
        ]),
        fr,
      );
      expect(e.message, fr.errValidation);
      expect(e.fieldMessage('email'), 'must be a valid email');
    });

    test('badRequest → request rejected', () {
      final e = userErrorOf(of(ApiErrorKind.badRequest, status: 400), fr);
      expect(e.message, fr.errBadRequest);
    });

    test('server → temporary-unavailable message', () {
      final e = userErrorOf(of(ApiErrorKind.server, status: 500), fr);
      expect(e.message, fr.errServer);
    });

    test('unknown → generic sentence', () {
      final e = userErrorOf(of(ApiErrorKind.unknown), fr);
      expect(e.message, fr.errGeneric);
    });
  });

  group('named backend codes', () {
    test('INVALID_STATUS_TRANSITION → not-allowed sentence, no retry', () {
      final e = userErrorOf(
          of(ApiErrorKind.conflict,
              status: 409, code: kCodeInvalidTransition),
          fr);
      expect(e.message, fr.errInvalidTransition);
      expect(e.retryable, isFalse);
    });

    test('MALWARE_SCAN_FAILED → upload rejected sentence', () {
      final e = userErrorOf(
          of(ApiErrorKind.badRequest,
              status: 400, code: kCodeMalwareScanFailed),
          fr);
      expect(e.message, fr.errUploadRejected);
      expect(e.retryable, isFalse);
    });

    test('AI_GENERATION_FAILED → AI unavailable with a manual fallback', () {
      final e = userErrorOf(
          of(ApiErrorKind.server, status: 502, code: kCodeAiGenerationFailed),
          fr);
      expect(e.message, fr.errAiUnavailable);
    });

    test('PASSWORD_CHANGE_REQUIRED → forced-change sentence', () {
      final e = userErrorOf(
          of(ApiErrorKind.forbidden,
              status: 403, code: kCodePasswordChangeRequired),
          fr);
      expect(e.message, fr.errPasswordChangeRequired);
      expect(e.retryable, isFalse);
    });

    test('rate-limit code and HTTP 429 both → rate-limited sentence', () {
      final byCode = userErrorOf(
          of(ApiErrorKind.unknown, code: kCodeRateLimitExceeded), fr);
      expect(byCode.message, fr.errRateLimited);
      expect(byCode.rateLimited, isTrue);

      final byStatus = userErrorOf(
          of(ApiErrorKind.unknown, status: 429), fr);
      expect(byStatus.message, fr.errRateLimited);
      expect(byStatus.rateLimited, isTrue);
    });
  });

  group('non-ApiException + never leaks raw text', () {
    test('plain Exception → generic sentence', () {
      final e = userErrorOf(Exception('offline'), fr);
      expect(e.message, fr.errGeneric);
    });

    test('StateError → generic sentence, not retryable', () {
      final e = userErrorOf(StateError('no-internhip'), fr);
      expect(e.message, fr.errGeneric);
      expect(e.retryable, isFalse);
    });

    test('no mapped sentence ever contains the raw exception text', () {
      final errors = <Object>[
        ApiException.network(),
        ApiException.unknown(),
        of(ApiErrorKind.server, status: 500),
        Exception('SECRET-INTERNAL-DETAIL'),
        StateError('SECRET-INTERNAL-DETAIL'),
      ];
      for (final error in errors) {
        final message = userErrorOf(error, fr).message;
        expect(message.contains('Exception'), isFalse);
        expect(message.contains('SECRET-INTERNAL-DETAIL'), isFalse);
      }
    });

    test('the trace id is preserved for support (not mixed into the sentence)',
        () {
      const e = ApiException(
          kind: ApiErrorKind.server, message: 'boom', traceId: 'trace-42');
      final user = userErrorOf(e, fr);
      expect(user.traceId, 'trace-42');
      expect(user.message.contains('trace-42'), isFalse);
    });
  });

  group('localized in all three languages', () {
    test('the same failure reads differently per locale', () {
      final error = ApiException.network();
      final f = userMessageOf(error, fr);
      final e = userMessageOf(error, en);
      final a = userMessageOf(error, ar);
      expect(f, fr.errNetwork);
      expect(e, en.errNetwork);
      expect(a, ar.errNetwork);
      expect({f, e, a}.length, 3, reason: 'fr/en/ar must differ');
    });

    test('userMessageOf is the message of userErrorOf', () {
      final error = of(ApiErrorKind.forbidden, status: 403);
      expect(userMessageOf(error, fr), userErrorOf(error, fr).message);
    });
  });
}
