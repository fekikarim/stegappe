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
const String kCodeAiUnavailable = 'AI_UNAVAILABLE';
const String kCodeAiTemporarilyUnavailable = 'AI_TEMPORARILY_UNAVAILABLE';
const String kCodeAiGenerationInvalid = 'AI_GENERATION_INVALID';
// T09/B5+B6 journal document: the server owns the window and the input bounds.
const String kCodeJournalNotEligible = 'JOURNAL_NOT_ELIGIBLE';
const String kCodeJournalTextTooShort = 'JOURNAL_TEXT_TOO_SHORT';
const String kCodeJournalTextTooLong = 'JOURNAL_TEXT_TOO_LONG';
const String kCodeRateLimitExceeded = 'RATE_LIMIT_EXCEEDED';
const String kCodePasswordChangeRequired = 'PASSWORD_CHANGE_REQUIRED';
const String kCodeCategoryChanged = 'CATEGORY_CHANGED';
const String kCodeCategoryNoCategories = 'CATEGORY_SUGGESTION_NO_CATEGORIES';
const String kCodeReviewReasonRequired = 'REVIEW_REASON_REQUIRED';
const String kCodeTaskNotCompleted = 'TASK_NOT_COMPLETED';
const String kCodeVisibleFromOutsidePeriod = 'VISIBLE_FROM_OUTSIDE_PERIOD';
const String kCodeTaskScheduleStaffOnly = 'TASK_SCHEDULE_STAFF_ONLY';
const String kCodeSpecTextInvalid = 'SPEC_TEXT_INVALID';
const String kCodeSpecTextTooLong = 'SPEC_TEXT_TOO_LONG';
const String kCodeMessageTooLong = 'MESSAGE_TOO_LONG';
const String kCodeContactDataNotAllowed = 'CONTACT_DATA_NOT_ALLOWED';
const String kCodeDuplicatePost = 'DUPLICATE_POST';
const String kCodeStudentMuted = 'STUDENT_MUTED';
const String kCodeReportAlreadyOpen = 'REPORT_ALREADY_OPEN';
const String kCodePostTooLong = 'POST_TOO_LONG';
const String kCodeCommentTooLong = 'COMMENT_TOO_LONG';
// T10/B7+B8+SU-VAL-01: final-week window + explicit validation document kind.
const String kCodeSubmissionNotInWindow = 'SUBMISSION_NOT_IN_WINDOW';
const String kCodeDocumentKindLocked = 'DOCUMENT_KIND_LOCKED';
const String kCodeDeliverableAlreadyValidated = 'DELIVERABLE_ALREADY_VALIDATED';
const String kCodeDeliverableNotInConversation =
    'DELIVERABLE_NOT_IN_CONVERSATION';

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
  // T03: the two actionable category codes first; every other
  // CATEGORY_*/APPLY_* validation (name, duplicate, colour, limit, reorder,
  // apply shape) shares one honest sentence — the backend message is never
  // rendered raw.
  if (code == kCodeCategoryChanged) {
    return UserError(
      message: l10n.errCategoryChanged,
      traceId: traceId,
      retryable: false,
    );
  }
  if (code == kCodeCategoryNoCategories) {
    return UserError(
      message: l10n.errCategoryNoCategories,
      traceId: traceId,
      retryable: false,
    );
  }
  // T04 supervisor review + scheduling codes get precise sentences.
  if (code == kCodeReviewReasonRequired) {
    return UserError(
      message: l10n.errReviewReason,
      traceId: traceId,
      retryable: false,
    );
  }
  if (code == kCodeTaskNotCompleted) {
    return UserError(
      message: l10n.errTaskNotCompleted,
      traceId: traceId,
      retryable: false,
    );
  }
  if (code == kCodeVisibleFromOutsidePeriod) {
    return UserError(
      message: l10n.errScheduleOutsidePeriod,
      traceId: traceId,
      retryable: false,
    );
  }
  if (code == kCodeTaskScheduleStaffOnly) {
    return UserError(
      message: l10n.errForbidden,
      traceId: traceId,
      retryable: false,
      forbidden: true,
    );
  }
  if (code.startsWith('BULK_') || code.startsWith('BULK_DRAFTS_')) {
    return UserError(
      message: l10n.errBulkInvalid,
      traceId: traceId,
      retryable: false,
    );
  }
  // T05 draft/spec validation (titles, lengths, dates, instructions, text
  // size) shares one actionable sentence — the backend message is never raw.
  if (code.startsWith('DRAFT_') ||
      code == kCodeSpecTextInvalid ||
      code == kCodeSpecTextTooLong) {
    return UserError(
      message: l10n.errDraftInvalid,
      traceId: traceId,
      retryable: false,
    );
  }
  // T07: message length is a server contract (`@Size(max=4000)`); the client
  // pre-check in ChatController.send reuses the same code so both paths get
  // one precise sentence — the backend message is never rendered raw.
  if (code == kCodeMessageTooLong) {
    return UserError(
      message: l10n.errMessageTooLong,
      traceId: traceId,
      retryable: false,
    );
  }
  // T08 community guardrails: each server refusal gets one actionable
  // sentence (the backend reason/detail is never rendered raw).
  if (code == kCodeContactDataNotAllowed) {
    return UserError(
      message: l10n.errCommunityContactData,
      traceId: traceId,
      retryable: false,
    );
  }
  if (code == kCodeDuplicatePost) {
    return UserError(
      message: l10n.errCommunityDuplicate,
      traceId: traceId,
      retryable: false,
    );
  }
  if (code == kCodeStudentMuted) {
    return UserError(
      message: l10n.errCommunityMuted,
      traceId: traceId,
      retryable: false,
    );
  }
  if (code == kCodeReportAlreadyOpen) {
    return UserError(
      message: l10n.errCommunityReportOpen,
      traceId: traceId,
      retryable: false,
    );
  }
  // T08: server length contracts shared with the composer pre-check.
  if (code == kCodePostTooLong || code == kCodeCommentTooLong) {
    return UserError(
      message: l10n.errCommunityTooLong,
      traceId: traceId,
      retryable: false,
    );
  }
  if (code.startsWith('CATEGORY_') || code.startsWith('APPLY_')) {
    return UserError(
      message: l10n.errCategoryInvalid,
      traceId: traceId,
      retryable: false,
    );
  }
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
    case kCodeAiUnavailable:
    case kCodeAiTemporarilyUnavailable:
    case kCodeAiGenerationInvalid:
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
    case kCodeJournalNotEligible:
      return UserError(
        message: l10n.errJournalNotEligible,
        traceId: traceId,
        retryable: false,
      );
    case kCodeJournalTextTooShort:
    case kCodeJournalTextTooLong:
      return UserError(
        message: l10n.errJournalTextInvalid,
        traceId: traceId,
        retryable: false,
      );
    // T10/B7: the server refused outside the final week — explain and point
    // at the supervisor chat, never an override (documented edge case).
    case kCodeSubmissionNotInWindow:
      return UserError(
        message: l10n.errSubmissionWindowClosed,
        traceId: traceId,
        retryable: false,
      );
    // T10/B8: the document's kind is locked (already assigned elsewhere or
    // the document is VALIDATED) — one honest sentence for both codes.
    case kCodeDocumentKindLocked:
    case kCodeDeliverableAlreadyValidated:
      return UserError(
        message: l10n.errDeliverableKindLocked,
        traceId: traceId,
        retryable: false,
      );
    case kCodeDeliverableNotInConversation:
      return UserError(
        message: l10n.errDocumentNotInConversation,
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
