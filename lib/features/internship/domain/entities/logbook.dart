import 'package:equatable/equatable.dart';

/// Lifecycle of the official internship logbook, mirroring the backend
/// `LogbookStatus` (backend is the single source of truth).
/// DRAFT → SUBMITTED → VALIDATED / REJECTED → OFFICIAL
enum LogbookStatus {
  draft,
  submitted,
  validated,
  rejected,
  official,
  unknown;

  static LogbookStatus fromApi(String? raw) {
    switch (raw) {
      case 'DRAFT':
        return LogbookStatus.draft;
      case 'SUBMITTED':
        return LogbookStatus.submitted;
      case 'VALIDATED':
        return LogbookStatus.validated;
      case 'REJECTED':
        return LogbookStatus.rejected;
      case 'OFFICIAL':
        return LogbookStatus.official;
      default:
        return LogbookStatus.unknown;
    }
  }
}

/// Server-authoritative logbook record (maps the backend `LogbookResponse`).
/// Created from submission/validation/rejection responses and from GET, never
/// synthesized locally — the backend decides every state transition.
class LogbookState extends Equatable {
  const LogbookState({
    required this.id,
    required this.internshipId,
    required this.status,
    this.draftText,
    this.finalText,
    this.submittedById,
    this.submittedAt,
    this.validatedById,
    this.validatedAt,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String internshipId;
  final LogbookStatus status;
  final String? draftText;
  final String? finalText;
  final String? submittedById;
  final DateTime? submittedAt;
  final String? validatedById;
  final DateTime? validatedAt;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPendingReview => status == LogbookStatus.submitted;

  @override
  List<Object?> get props => [
        id,
        internshipId,
        status,
        draftText,
        finalText,
        submittedById,
        submittedAt,
        validatedById,
        validatedAt,
        rejectionReason,
        createdAt,
        updatedAt,
      ];
}
/// data (journal/tasks/deliverables) — the app sends nothing but the
/// internship id, so CIN/restricted documents structurally cannot reach
/// the model from this client. The draft is REVIEW-ONLY: the user edits
/// it before any use, and it never becomes an official record by itself.
///
/// AI must never: evaluate performance, approve deliverables/finance,
/// or alter internship status. This type carries no such capability.
class LogbookDraft extends Equatable {
  const LogbookDraft({
    required this.analysisId,
    required this.analysisType,
    required this.modelUsed,
    required this.cinExcluded,
    required this.createdAt,
    required this.draftText,
    this.recommendations = const [],
  });

  final String analysisId;
  final String analysisType;
  final String modelUsed;
  final bool cinExcluded;
  final DateTime createdAt;
  final String draftText;
  final List<String> recommendations;

  @override
  List<Object?> get props => [
        analysisId,
        analysisType,
        modelUsed,
        cinExcluded,
        createdAt,
        draftText,
        recommendations,
      ];
}
