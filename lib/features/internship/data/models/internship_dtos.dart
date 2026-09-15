import '../../domain/entities/evaluation.dart';
import '../../domain/entities/internship.dart';
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

InternTask taskFromJson(Map<String, dynamic> json) => InternTask(
      id: _str(json['id']),
      title: _str(json['title']),
      description: json['description'] as String?,
      status: taskStatusFrom(json['status'] as String?),
      dueDate: _date(json['dueDate']),
      completedAt: _date(json['completedAt']),
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
  if (status != null) map['status'] = taskStatusToApi(status);
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
