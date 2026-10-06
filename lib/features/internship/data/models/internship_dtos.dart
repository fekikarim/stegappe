import '../../domain/entities/evaluation.dart';
import '../../domain/entities/internship.dart';
import '../../domain/entities/logbook.dart';
import '../../domain/entities/task_classification.dart';
import '../../domain/entities/work_items.dart';

DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

DateTime _dateOrNow(dynamic v) => _date(v) ?? DateTime.now();

String _str(dynamic v, [String fallback = '']) =>
    v is String ? v : fallback;

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Internship internshipFromJson(Map<String, dynamic> json) => Internship(
      id: _str(json['id']),
      reference: _str(json['reference']),
      startDate: _dateOrNow(json['startDate']),
      endDate: _dateOrNow(json['endDate']),
      status: internshipStatusFrom(json['status'] as String?),
      type: internshipTypeFrom(json['type'] as String?),
      requirement: _str(json['requirement']),
      paymentEligible: json['paymentEligible'] == true,
      subject: json['subject'] as String?,
      candidateFullName: json['candidateFullName'] as String?,
    );

InternshipAssignment assignmentFromJson(Map<String, dynamic> json) =>
    InternshipAssignment(
      id: _str(json['id']),
      departmentName: _str(json['departmentName']),
      supervisorName: _str(json['supervisorName']),
      status: _str(json['status']),
      startDate: _date(json['startDate']),
      endDate: _date(json['endDate']),
    );

/// `TaskResponse` → domain. Every field the board needs is read from the
/// authoritative contract: status (all six values), the denial reason
/// (`reviewReason`, BR-12), the review timestamp and the authorship ids that
/// decide whether the student may edit the task (BR-14).
InternTask taskFromJson(Map<String, dynamic> json) => InternTask(
      id: _str(json['id']),
      title: _str(json['title']),
      description: json['description'] as String?,
      status: taskStatusFrom(json['status'] as String?),
      dueDate: _date(json['dueDate']),
      completedAt: _date(json['completedAt']),
      createdById: json['createdById']?.toString(),
      assignedToId: json['assignedToId']?.toString(),
      reviewReason: json['reviewReason'] as String?,
      reviewedAt: _date(json['reviewedAt']),
    );

JournalEntry journalFromJson(Map<String, dynamic> json) => JournalEntry(
      id: _str(json['id']),
      title: _str(json['title']),
      description: json['description'] as String?,
      status: journalStatusFrom(json['status'] as String?),
      entryDate: _dateOrNow(json['entryDate']),
      validatedByName: json['validatedByName'] as String?,
      submittedAt: _date(json['submittedAt']),
      validatedAt: _date(json['validatedAt']),
    );

DeliverableSummary deliverableFromJson(Map<String, dynamic> json) =>
    DeliverableSummary(
      id: _str(json['id']),
      title: _str(json['title']),
      status: deliverableStatusFrom(json['status'] as String?),
      currentVersion: (json['currentVersion'] as num?)?.toInt() ?? 1,
    );

EvaluationSummary evaluationFromJson(Map<String, dynamic> json) =>    EvaluationSummary(
      id: _str(json['id']),
      type: _str(json['type']),
      evaluationDate: _dateOrNow(json['evaluationDate']),
      totalScore: (json['totalScore'] as num?)?.toDouble(),
      feedback: json['feedback'] as String?,
    );

DeliverableVersionInfo deliverableVersionFromJson(
        Map<String, dynamic> json) =>
    DeliverableVersionInfo(
      id: _str(json['id']),
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 1,
      fileName: _str(json['fileName']),
      mimeType: _str(json['mimeType']),
      size: (json['size'] as num?)?.toInt() ?? 0,
      uploadedByEmail: _str(json['uploadedByEmail']),
      changeSummary: json['changeSummary'] as String?,
      uploadedAt: _dateOrNow(json['uploadedAt']),
    );

DeliverableDetail deliverableDetailFromJson(Map<String, dynamic> json,
        [List<DeliverableVersionInfo> versions = const []]) =>
    DeliverableDetail(
      id: _str(json['id']),
      title: _str(json['title']),
      description: json['description'] as String?,
      status: deliverableStatusFrom(json['status'] as String?),
      currentVersion: (json['currentVersion'] as num?)?.toInt() ?? 1,
      submittedAt: _date(json['submittedAt']),
      validatedAt: _date(json['validatedAt']),
      validatedByName: json['validatedByName'] as String?,
      versions: versions,
    );

AppNotification notificationFromJson(Map<String, dynamic> json) =>
    AppNotification(
      id: _str(json['id']),
      title: _str(json['title']),
      message: _str(json['message']),
      priority: _str(json['priority'], 'NORMAL'),
      createdAt: _dateOrNow(json['createdAt']),
      isRead: json['read'] == true,
    );

JournalComment journalCommentFromJson(Map<String, dynamic> json) =>
    JournalComment(
      id: _str(json['id']),
      content: _str(json['content']),
      authorEmail: _str(json['authorEmail']),
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
    );

/// Parses the server-authoritative LogbookResponse.
LogbookState logbookFromJson(Map<String, dynamic> json) => LogbookState(
      id: _str(json['id']),
      internshipId: _str(json['internshipId']),
      status: LogbookStatus.fromApi(json['status'] as String?),
      draftText: json['draftText'] as String?,
      finalText: json['finalText'] as String?,
      submittedById: json['submittedById'] as String?,
      submittedAt: _date(json['submittedAt']),
      validatedById: json['validatedById'] as String?,
      validatedAt: _date(json['validatedAt']),
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );

/// Parses AiAnalysisResultResponse (LOGBOOK_GENERATION).
LogbookDraft logbookDraftFromJson(Map<String, dynamic> json) {
  final analysis =
      (json['analysis'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
  final recs = <String>[];
  final rawRecs = json['recommendations'];
  if (rawRecs is List) {
    for (final e in rawRecs) {
      if (e is Map<String, dynamic>) {
        final text = (e['recommendationText'] ?? '').toString();
        if (text.isNotEmpty) recs.add(text);
      }
    }
  }
  return LogbookDraft(
    analysisId: _str(analysis['id']),
    analysisType: _str(analysis['type'], 'LOGBOOK_GENERATION'),
    modelUsed: _str(analysis['modelUsed']),
    cinExcluded: analysis['cinExcluded'] != false,
    createdAt: _dateOrNow(analysis['createdAt']),
    draftText: (json['responseText'] ?? '').toString(),
    recommendations: recs,
  );
}

EvaluationTemplate templateFromJson(Map<String, dynamic> json) =>
    EvaluationTemplate(
      id: _str(json['id']),
      name: _str(json['name']),
      description: json['description'] as String?,
      active: json['active'] != false,
    );

EvaluationCriterion criterionFromJson(Map<String, dynamic> json) =>
    EvaluationCriterion(
      id: _str(json['id']),
      templateId: _str(json['templateId']),
      name: _str(json['name']),
      description: json['description'] as String?,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
    );

EvaluationScore evalScoreFromJson(Map<String, dynamic> json) =>
    EvaluationScore(
      criterionId: _str(json['criterionId']),
      criterionName: _str(json['criterionName']),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
    );

EvaluationTaskReview taskReviewFromJson(Map<String, dynamic> json) =>
    EvaluationTaskReview(
      taskId: _str(json['taskId']),
      taskTitle: _str(json['taskTitle']),
      completed: json['completed'] == true,
      score: (json['score'] as num?)?.toDouble(),
      comment: json['comment'] as String?,
    );

/// Write payloads mirror EvaluationRequest / EvaluationScoreRequest /
/// EvaluationTaskReviewRequest.
Map<String, dynamic> evaluationWriteJson({
  String? templateId,
  required EvaluationKind kind,
  required DateTime date,
  String? feedback,
}) {
  final map = <String, dynamic>{
    'type': evaluationKindToApi(kind),
    'evaluationDate': _ymd(date),
  };
  if (templateId != null) map['templateId'] = templateId;
  if (feedback != null && feedback.isNotEmpty) {
    map['feedback'] = feedback;
  }
  return map;
}

Map<String, dynamic> scoreWriteJson({
  required String criterionId,
  required double score,
  String? comment,
}) {
  final map = <String, dynamic>{
    'criterionId': criterionId,
    'score': score,
  };
  if (comment != null && comment.isNotEmpty) {
    map['comment'] = comment;
  }
  return map;
}

Map<String, dynamic> taskReviewWriteJson({
  required String taskId,
  required bool completed,
  double? score,
  String? comment,
}) {
  final map = <String, dynamic>{
    'taskId': taskId,
    'completed': completed,
  };
  if (score != null) map['score'] = score;
  if (comment != null && comment.isNotEmpty) {
    map['comment'] = comment;
  }
  return map;
}

/// Minimal PRIVATE-conversation projection for internship-id discovery.
class ConversationLink {
  const ConversationLink({required this.type, this.internshipId});

  final String type;
  final String? internshipId;

  factory ConversationLink.fromJson(Map<String, dynamic> json) =>
      ConversationLink(
        type: _str(json['type']),
        internshipId: json['internshipId'] as String?,
      );
}

int unreadCountFromJson(Map<String, dynamic> json) =>
    (json['unreadCount'] as num?)?.toInt() ?? 0;

/// Write payloads mirror TaskRequest / JournalEntryRequest.
Map<String, dynamic> taskWriteJson({
  required String title,
  String? description,
  DateTime? dueDate,
  TaskStatus? status,
}) {
  final map = <String, dynamic>{'title': title};
  if (description != null) map['description'] = description;
  if (dueDate != null) map['dueDate'] = _ymd(dueDate);
  if (status != null) {
    final api = taskStatusToApi(status);
    // `unknown` is not a backend value: never send it.
    if (api != null) map['status'] = api;
  }
  return map;
}

Map<String, dynamic> journalWriteJson({
  required String title,
  required String description,
  required DateTime entryDate,
}) =>
    {
      'title': title,
      'description': description,
      'entryDate': _ymd(entryDate),
    };

// --- T03 task classification (student-defined categories + AI proposals) ---

TaskCategory taskCategoryFromJson(Map<String, dynamic> json) =>
    TaskCategory(
      id: _str(json['id']),
      name: _str(json['name']),
      // Unknown future colour tokens survive verbatim (tolerant parse);
      // the chip renderer falls back to the default swatch.
      colorToken: json['color'] as String?,
      position: (json['position'] as num?)?.toInt() ?? 0,
    );

/// `TaskCategoryBoardResponse`: categories + task→category assignments.
/// Malformed category rows are skipped (never a crash); malformed
/// assignment pairs are ignored (never trusted blindly).
ClassificationBoard classificationBoardFromJson(dynamic json) {
  if (json is! Map<String, dynamic>) return ClassificationBoard.empty;
  final rawCats = json['categories'];
  final categories = <TaskCategory>[];
  if (rawCats is List) {
    for (final e in rawCats) {
      if (e is! Map<String, dynamic>) continue;
      final cat = taskCategoryFromJson(e);
      if (cat.id.isEmpty || cat.name.trim().isEmpty) continue;
      categories.add(cat);
    }
  }
  final assignments = <String, String>{};
  final rawAssign = json['assignments'];
  if (rawAssign is Map) {
    rawAssign.forEach((k, v) {
      final taskId = k.toString();
      final catId = v?.toString() ?? '';
      if (taskId.isNotEmpty && catId.isNotEmpty) {
        assignments[taskId] = catId;
      }
    });
  }
  return ClassificationBoard(categories: categories, assignments: assignments);
}

/// `CategoryProposalResponse`: tolerant — a proposal without a task id is
/// dropped; confidence outside 0..1 is clamped.
CategoryProposal? categoryProposalFromJson(dynamic json) {
  if (json is! Map<String, dynamic>) return null;
  final taskId = json['taskId']?.toString() ?? '';
  if (taskId.isEmpty) return null;
  final categoryId = json['categoryId']?.toString();
  final newName = json['newCategoryName'] as String?;
  final rawConfidence = json['confidence'];
  double confidence = 0.5;
  if (rawConfidence is num) {
    confidence = rawConfidence.toDouble().clamp(0.0, 1.0);
  }
  return CategoryProposal(
    taskId: taskId,
    categoryId: (categoryId == null || categoryId.isEmpty) ? null : categoryId,
    newCategoryName:
        (newName == null || newName.trim().isEmpty) ? null : newName.trim(),
    confidence: confidence,
  );
}

List<CategoryProposal> categoryProposalsFromJson(dynamic json) {
  final raw = json is Map<String, dynamic> ? json['proposals'] : null;
  if (raw is! List) return const [];
  final out = <CategoryProposal>[];
  for (final e in raw) {
    final p = categoryProposalFromJson(e);
    if (p != null) out.add(p);
  }
  return out;
}

List<ApplyCategoryResult> applyResultsFromJson(dynamic json) {
  final raw = json is Map<String, dynamic> ? json['items'] : null;
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map<String, dynamic> &&
          (e['taskId']?.toString() ?? '').isNotEmpty)
        ApplyCategoryResult(
          taskId: e['taskId'].toString(),
          status: (e['status']?.toString() ?? 'UNKNOWN').toUpperCase(),
          categoryId: e['categoryId']?.toString(),
        ),
  ];
}

Map<String, dynamic> assignCategoryJson({
  String? categoryId,
  String? expectedCategoryId,
  bool force = false,
}) =>
    {
      'categoryId': categoryId,
      'expectedCategoryId': expectedCategoryId,
      'force': force,
    };

Map<String, dynamic> applyItemJson({
  required String taskId,
  String? categoryId,
  String? newCategoryName,
  String? expectedCategoryId,
}) {
  final map = <String, dynamic>{
    'taskId': taskId,
    'expectedCategoryId': expectedCategoryId,
  };
  if (categoryId != null) map['categoryId'] = categoryId;
  if (newCategoryName != null) map['newCategoryName'] = newCategoryName;
  return map;
}
