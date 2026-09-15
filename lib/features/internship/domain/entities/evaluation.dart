import 'package:equatable/equatable.dart';

import 'internship.dart';

/// Evaluation template + criterion come from the backend
/// (`EvaluationTemplate` / `EvaluationCriterion`). Official STEG criteria
/// are NOT hard-coded anywhere in the app (the seeded placeholder is
/// explicitly marked TODO — STEG VALIDATION REQUIRED server-side).
class EvaluationTemplate extends Equatable {
  const EvaluationTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.active,
  });

  final String id;
  final String name;
  final String? description;
  final bool active;

  @override
  List<Object?> get props => [id, name, description, active];
}

class EvaluationCriterion extends Equatable {
  const EvaluationCriterion({
    required this.id,
    required this.templateId,
    required this.name,
    this.description,
    required this.weight,
    required this.maxScore,
  });

  final String id;
  final String templateId;
  final String name;
  final String? description;
  final double weight;
  final double maxScore;

  @override
  List<Object?> get props =>
      [id, templateId, name, description, weight, maxScore];
}

class EvaluationScore extends Equatable {
  const EvaluationScore({
    required this.criterionId,
    required this.criterionName,
    required this.score,
    required this.maxScore,
    required this.weight,
    this.comment,
  });

  final String criterionId;
  final String criterionName;
  final double score;
  final double maxScore;
  final double weight;
  final String? comment;

  @override
  List<Object?> get props =>
      [criterionId, criterionName, score, maxScore, weight, comment];
}

class EvaluationTaskReview extends Equatable {
  const EvaluationTaskReview({
    required this.taskId,
    required this.taskTitle,
    required this.completed,
    this.score,
    this.comment,
  });

  final String taskId;
  final String taskTitle;
  final bool completed;
  final double? score;
  final String? comment;

  @override
  List<Object?> get props =>
      [taskId, taskTitle, completed, score, comment];
}

/// Evaluation types (backend-owned).
enum EvaluationKind { daily, weekly, midTerm, final_, custom }

EvaluationKind evaluationKindFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'DAILY' => EvaluationKind.daily,
      'WEEKLY' => EvaluationKind.weekly,
      'MID_TERM' => EvaluationKind.midTerm,
      'FINAL' => EvaluationKind.final_,
      _ => EvaluationKind.custom,
    };

String evaluationKindToApi(EvaluationKind k) => switch (k) {
      EvaluationKind.daily => 'DAILY',
      EvaluationKind.weekly => 'WEEKLY',
      EvaluationKind.midTerm => 'MID_TERM',
      EvaluationKind.final_ => 'FINAL',
      EvaluationKind.custom => 'CUSTOM',
    };

/// Live estimate preview. Mirrors the backend formula
/// (Σ score/max×weight / Σweight × 20) for UX ONLY — the submitted
/// response displayed afterwards is the authoritative server value.
/// Returns null when nothing is scorable (backend returns null too).
double? estimateTotal(Map<String, double> scores,
    List<EvaluationCriterion> criteria) {
  var weightedSum = 0.0;
  var totalWeight = 0.0;
  for (final c in criteria) {
    final s = scores[c.id];
    if (s == null) continue;
    if (c.maxScore <= 0 || c.weight <= 0) continue;
    weightedSum += s / c.maxScore * c.weight;
    totalWeight += c.weight;
  }
  if (totalWeight <= 0) return null;
  final raw = weightedSum / totalWeight * 20;
  // HALF_UP to 2 decimals, matching backend RoundingMode.
  return (raw * 100).round() / 100;
}

/// Supervised intern card: backend-sourced progress, never invented.
class SupervisedIntern extends Equatable {
  const SupervisedIntern({
    required this.internshipId,
    required this.reference,
    required this.internName,
    required this.status,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.departmentName,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.pendingJournal,
    required this.pendingDeliverables,
    required this.evaluationsCount,
  });

  final String internshipId;
  final String reference;
  final String internName;
  final InternshipStatus status;
  final InternshipType? type;
  final DateTime startDate;
  final DateTime endDate;
  final String departmentName;
  final int tasksCompleted;
  final int tasksTotal;
  final int pendingJournal;
  final int pendingDeliverables;
  final int evaluationsCount;

  double? get tasksFraction =>
      tasksTotal == 0 ? null : tasksCompleted / tasksTotal;

  bool get needsAttention =>
      pendingJournal > 0 || pendingDeliverables > 0;

  @override
  List<Object?> get props => [
        internshipId,
        reference,
        internName,
        status,
        type,
        startDate,
        endDate,
        departmentName,
        tasksCompleted,
        tasksTotal,
        pendingJournal,
        pendingDeliverables,
        evaluationsCount,
      ];
}
