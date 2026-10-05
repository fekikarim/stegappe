import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'api_exception.dart';

/// Centralized mapping from any thrown error to a localized, user-facing
/// sentence plus the flags the UI needs to react correctly.
///
/// **Rule (T00 / SKILL.md §4):** screens never render `error.toString()`, a raw
/// HTTP status or a backend stack message. They call [userErrorOf] (or the
/// `context.userError(e)` extension) once and render [UserError.message].
/// The backend keeps the authority for *why* something failed; this only
/// turns the typed result into a human sentence in the user's language.
class UserError {
  const UserError({
    required this.message,
    this.traceId,
    this.retryable = true,
    this.requiresConnectivity = false,
    this.sessionExpired = false,
    this.forbidden = false,
    this.notFound = false,
    this.rateLimited = false,
    this.fieldErrors = const [],
  });

  /// Localized sentence safe to show to the user.
  final String message;

  /// Correlation id from the backend envelope, shown only as a copyable
  /// technical detail (never mixed into the sentence).
  final String? traceId;

  /// Whether offering "retry" makes sense for this failure.
  final bool retryable;

  /// True when the operation needs connectivity (offline / transport failure).
  /// AI calls, document generation and submissions keep this true so a screen
  /// can say "connection required" instead of pretending to work.
  final bool requiresConnectivity;

  /// The session ended (revoked, expired, credentials changed) → the app must
  /// route to the session handler, not offer a retry of the failed action.
  final bool sessionExpired;

  final bool forbidden;
  final bool notFound;
  final bool rateLimited;
  final List<FieldError> fieldErrors;

  /// Field-level message for typed forms.
  String? fieldMessage(String field) {
    for (final e in fieldErrors) {
      if (e.field == field || e.field.endsWith('.$field')) return e.message;
    }
    return null;
  }
}

/// Backend error codes translated explicitly. They come from
/// `BusinessRuleException(errorCode, …)` / the global exception handler.
const String kCodeInvalidTransition = 'INVALID_STATUS_TRANSITION';
const String kCodeMalwareScanFailed = 'MALWARE_SCAN_FAILED';
const String kCodeAiGenerationFailed = 'AI_GENERATION_FAILED';
const String kCodeRateLimitExceeded = 'RATE_LIMIT_EXCEEDED';
const String kCodePasswordChangeRequired = 'PASSWORD_CHANGE_REQUIRED';

/// Maps one error to a [UserError]. Never returns a raw exception string.
UserError userErrorOf(Object error, AppLocalizations l10n) {
  if (error is! ApiException) {
    // Client-side markers such as `StateError('no-internship')` are handled by
    // the screen that owns them; everything else gets the generic sentence.
    return UserError(
      message: l10n.errGeneric,
      retryable: error is! StateError,
    );
  }

  final traceId = error.traceId;
  final code = (error.code ?? '').toUpperCase();

  // Rate limiting is actionable, not a bug: the user can wait and retry.
  if (error.statusCode == 429 || code == kCodeRateLimitExceeded) {
    return UserError(
      message: l10n.errRateLimited,
      traceId: traceId,
      rateLimited: true,
    );
  }

  // Named business-rule codes get a precise sentence.
  switch (code) {
    case kCodeInvalidTransition:
      return UserError(
        message: l10n.errInvalidTransition,
        traceId: traceId,
        retryable: false,
      );
    case kCodeMalwareScanFailed:
      return UserError(
        message: l10n.errUploadRejected,
        traceId: traceId,
        retryable: false,
      );
    case kCodeAiGenerationFailed:
      return UserError(
        message: l10n.errAiUnavailable,
        traceId: traceId,
      );
    case kCodePasswordChangeRequired:
      return UserError(
        message: l10n.errPasswordChangeRequired,
        traceId: traceId,
        retryable: false,
      );
  }

  return switch (error.kind) {
    ApiErrorKind.network => UserError(
        message: l10n.errNetwork,
        traceId: traceId,
        requiresConnectivity: true,
      ),
    ApiErrorKind.unauthorized => UserError(
        message: l10n.errSessionExpired,
        traceId: traceId,
        retryable: false,
        sessionExpired: true,
      ),
    ApiErrorKind.forbidden => UserError(
        message: l10n.errForbidden,
        traceId: traceId,
        retryable: false,
        forbidden: true,
      ),
    ApiErrorKind.notFound => UserError(
        message: l10n.errNotFound,
        traceId: traceId,
        retryable: false,
        notFound: true,
      ),
    ApiErrorKind.conflict => UserError(
        message: l10n.errConflict,
        traceId: traceId,
        notFound: false,
      ),
    // A validation failure with no field details is a rejected request, not a
    // form error (the live backend answers 422 for bad credentials).
    ApiErrorKind.validation => UserError(
        message: error.fieldErrors.isEmpty ? l10n.errBadRequest : l10n.errValidation,
        traceId: traceId,
        retryable: false,
        fieldErrors: error.fieldErrors,
      ),
    ApiErrorKind.badRequest => UserError(
        message: l10n.errBadRequest,
        traceId: traceId,
        retryable: false,
      ),
    ApiErrorKind.server => UserError(
        message: l10n.errServer,
        traceId: traceId,
      ),
    ApiErrorKind.unknown => UserError(message: l10n.errGeneric, traceId: traceId),
  };
}

/// The localized sentence alone — the API named by the T00 task
/// (`userMessageOf(Object error, AppLocalizations l10n)`). Prefer [userErrorOf]
/// when the screen also needs the retry / trace / session flags.
String userMessageOf(Object error, AppLocalizations l10n) =>
    userErrorOf(error, l10n).message;

/// `context.userError(e).message` — the single call site pattern for screens
/// that render synchronously (widget builders, `mounted`-guarded callbacks).
extension UserErrorContext on BuildContext {
  UserError userError(Object error) =>
      userErrorOf(error, AppLocalizations.of(this));
}
