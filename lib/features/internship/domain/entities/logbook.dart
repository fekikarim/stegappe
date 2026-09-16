import 'package:equatable/equatable.dart';

/// Advisory AI logbook draft. Produced server-side from ACTUAL recorded
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
