import 'dart:typed_data';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/paged.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/internship.dart';
import '../../domain/entities/logbook.dart';
import '../../domain/entities/work_items.dart';
import '../models/internship_dtos.dart';

/// Thin HTTP wrapper over the internship/companion/notification/
/// messaging read endpoints (+ task status write). No business logic.
class InternshipRemoteDataSource {
  InternshipRemoteDataSource(this._client);

  final ApiClient _client;

  Future<Internship> getInternship(String id, String? bearer) =>
      _client.get(Endpoints.internship(id),
          bearer: bearer, decode: (j) => internshipFromJson(_map(j)));

  Future<List<InternshipAssignment>> getAssignments(
          String id, String? bearer) =>
      _client.get(Endpoints.assignments(id), bearer: bearer, decode: (j) {
        if (j is List) {
          return [
            for (final e in j)
              if (e is Map<String, dynamic>) assignmentFromJson(e),
          ];
        }
        return <InternshipAssignment>[];
      });

  Future<Paged<InternTask>> listTasks(
    String internshipId,
    String? bearer, {
    int page = 0,
    int size = 50,
    TaskStatus? status,
  }) {
    final q = pageQuery(page: page, size: size);
    if (status != null) q['status'] = taskStatusToApi(status);
    return _client.get(Endpoints.internshipTasks(internshipId),
        bearer: bearer,
        query: q,
        decode: (j) => Paged.fromJson(j, taskFromJson));
  }

  Future<InternTask> updateTaskStatus(
          String taskId, TaskStatus status, String? bearer) =>
      _client.patch(Endpoints.taskStatus(taskId),
          bearer: bearer,
          query: {'status': taskStatusToApi(status)},
          decode: (j) => taskFromJson(_map(j)));

  // --- D2 writes: tasks ---

  Future<InternTask> createTask(
    String internshipId,
    String? bearer, {
    required String title,
    String? description,
    DateTime? dueDate,
  }) =>
      _client.post(Endpoints.internshipTasks(internshipId),
          bearer: bearer,
          body: taskWriteJson(
              title: title, description: description, dueDate: dueDate),
          decode: (j) => taskFromJson(_map(j)));

  Future<InternTask> updateTask(
    String taskId,
    String? bearer, {
    required String title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
  }) =>
      _client.put(Endpoints.task(taskId),
          bearer: bearer,
          body: taskWriteJson(
              title: title,
              description: description,
              dueDate: dueDate,
              status: status),
          decode: (j) => taskFromJson(_map(j)));

  // --- D2 writes: journal (intern: create + submit) ---

  Future<JournalEntry> createJournal(
    String internshipId,
    String? bearer, {
    required String title,
    required String description,
    required DateTime entryDate,
  }) =>
      _client.post(Endpoints.journalEntries(internshipId),
          bearer: bearer,
          body: journalWriteJson(
              title: title,
              description: description,
              entryDate: entryDate),
          decode: (j) => journalFromJson(_map(j)));

  Future<JournalEntry> submitJournal(String entryId, String? bearer) =>
      _client.post(Endpoints.journalSubmit(entryId),
          bearer: bearer, decode: (j) => journalFromJson(_map(j)));

  // --- D2 writes: journal review (supervisor only, server-enforced) ---

  Future<JournalEntry> validateJournal(
          String entryId, String? bearer, String? comment) =>
      _client.post(Endpoints.journalValidate(entryId),
          bearer: bearer,
          body: {'comment': comment},
          decode: (j) => journalFromJson(_map(j)));

  Future<JournalEntry> rejectJournal(
          String entryId, String? bearer, String? comment) =>
      _client.post(Endpoints.journalReject(entryId),
          bearer: bearer,
          body: {'comment': comment},
          decode: (j) => journalFromJson(_map(j)));

  Future<List<JournalComment>> journalComments(
          String entryId, String? bearer) =>
      _client.get(Endpoints.journalComments(entryId),
          bearer: bearer, decode: (j) {
        if (j is List) {
          return [
            for (final e in j)
              if (e is Map<String, dynamic>)
                journalCommentFromJson(e),
          ];
        }
        return <JournalComment>[];
      });

  // --- D3: deliverables (multipart, versioned, reviewed) ---

  Future<DeliverableDetail> createDeliverable(
    String internshipId,
    String? bearer, {
    required String title,
    String? description,
    required String fileName,
    required Uint8List fileBytes,
    void Function(int sent, int total)? onProgress,
  }) =>
      _client.uploadMultipart(Endpoints.deliverables(internshipId),
          bearer: bearer,
          fields: {
            'title': title,
            if (description != null && description.isNotEmpty)
              'description': description,
          },
          fileField: 'file',
          fileName: fileName,
          contentType: 'application/pdf',
          bytes: fileBytes,
          onProgress: onProgress,
          decode: (j) => deliverableDetailFromJson(_map(j)));

  Future<DeliverableDetail> uploadNewVersion(
    String deliverableId,
    String? bearer, {
    required String fileName,
    required Uint8List fileBytes,
    String? changeSummary,
    void Function(int sent, int total)? onProgress,
  }) =>
      _client.uploadMultipart(Endpoints.deliverableVersions(deliverableId),
          bearer: bearer,
          fields: {
            if (changeSummary != null && changeSummary.isNotEmpty)
              'changeSummary': changeSummary,
          },
          fileField: 'file',
          fileName: fileName,
          contentType: 'application/pdf',
          bytes: fileBytes,
          onProgress: onProgress,
          decode: (j) => deliverableDetailFromJson(_map(j)));

  Future<DeliverableDetail> getDeliverable(
          String deliverableId, String? bearer) =>
      _client.get(Endpoints.deliverable(deliverableId),
          bearer: bearer,
          decode: (j) => deliverableDetailFromJson(_map(j)));

  Future<List<DeliverableVersionInfo>> deliverableVersions(
          String deliverableId, String? bearer) =>
      _client.get(Endpoints.deliverableVersions(deliverableId),
          bearer: bearer, decode: (j) {
        if (j is List) {
          return [
            for (final e in j)
              if (e is Map<String, dynamic>)
                deliverableVersionFromJson(e),
          ];
        }
        return <DeliverableVersionInfo>[];
      });

  Future<DeliverableDetail> submitDeliverable(
          String deliverableId, String? bearer) =>
      _client.post(Endpoints.deliverableSubmit(deliverableId),
          bearer: bearer,
          decode: (j) => deliverableDetailFromJson(_map(j)));

  Future<DeliverableDetail> validateDeliverable(
          String deliverableId, String? bearer, String? comment) =>
      _client.post(Endpoints.deliverableValidate(deliverableId),
          bearer: bearer,
          body: {'comment': comment},
          decode: (j) => deliverableDetailFromJson(_map(j)));

  Future<DeliverableDetail> rejectDeliverable(
          String deliverableId, String? bearer, String? comment) =>
      _client.post(Endpoints.deliverableReject(deliverableId),
          bearer: bearer,
          body: {'comment': comment},
          decode: (j) => deliverableDetailFromJson(_map(j)));

  Future<Uint8List> downloadDeliverable(
    String deliverableId,
    String? bearer, {
    int? version,
  }) =>
      _client.downloadBytes(Endpoints.deliverableDownload(deliverableId),
          bearer: bearer,
          query: version == null ? null : {'version': '$version'});

  Future<List<JournalComment>> deliverableComments(
          String deliverableId, String? bearer) =>
      _client.get(Endpoints.deliverableComments(deliverableId),
          bearer: bearer, decode: (j) {
        if (j is List) {
          return [
            for (final e in j)
              if (e is Map<String, dynamic>)
                journalCommentFromJson(e),
          ];
        }
        return <JournalComment>[];
      });

  // --- D4: evaluations (template-driven, supervisor-authored) ---

  Future<List<EvaluationTemplate>> listTemplates(
    String? bearer, {
    bool activeOnly = true,
  }) =>
      _client.get(Endpoints.evaluationTemplates,
          bearer: bearer,
          query: {'activeOnly': '$activeOnly'},
          decode: (j) => [
                if (j is List)
                  for (final e in j)
                    if (e is Map<String, dynamic>)
                      templateFromJson(e),
              ]);
  Future<List<EvaluationCriterion>> templateCriteria(
          String templateId, String? bearer) =>
      _client.get(Endpoints.templateCriteria(templateId),
          bearer: bearer, decode: (j) {
        if (j is List) {
          return [
            for (final e in j)
              if (e is Map<String, dynamic>) criterionFromJson(e),
          ];
        }
        return <EvaluationCriterion>[];
      });

  Future<EvaluationSummary> createEvaluation(
    String internshipId,
    String? bearer, {
    String? templateId,
    required EvaluationKind kind,
    required DateTime date,
    String? feedback,
  }) =>
      _client.post(Endpoints.internshipEvaluations(internshipId),
          bearer: bearer,
          body: evaluationWriteJson(
              templateId: templateId,
              kind: kind,
              date: date,
              feedback: feedback),
          decode: (j) => evaluationFromJson(_map(j)));

  Future<void> submitScores(
    String evaluationId,
    String? bearer,
    List<Map<String, dynamic>> scores,
  ) =>
      _client.post(Endpoints.evaluationScores(evaluationId),
          bearer: bearer, body: scores, decode: (_) {});

  Future<void> addTaskReview(
    String evaluationId,
    String? bearer,
    Map<String, dynamic> review,
  ) =>
      _client.post(Endpoints.evaluationTaskReviews(evaluationId),
          bearer: bearer, body: review, decode: (_) {});

  Future<EvaluationSummary> evaluationDetail(
          String evaluationId, String? bearer) =>
      _client.get(Endpoints.evaluation(evaluationId),
          bearer: bearer,
          decode: (j) => evaluationFromJson(_map(j)));

  Future<List<EvaluationScore>> evaluationScores(
          String evaluationId, String? bearer) =>
      _client.get(Endpoints.evaluationScores(evaluationId),
          bearer: bearer, decode: (j) {
        if (j is List) {
          return [
            for (final e in j)
              if (e is Map<String, dynamic>) evalScoreFromJson(e),
          ];
        }
        return <EvaluationScore>[];
      });

  Future<List<EvaluationTaskReview>> evaluationTaskReviews(
          String evaluationId, String? bearer) =>
      _client.get(Endpoints.evaluationTaskReviews(evaluationId),
          bearer: bearer, decode: (j) {
        if (j is List) {
          return [
            for (final e in j)
              if (e is Map<String, dynamic>) taskReviewFromJson(e),
          ];
        }
        return <EvaluationTaskReview>[];
      });

  Future<List<JournalComment>> evaluationComments(
          String evaluationId, String? bearer) =>
      _client.get(Endpoints.evaluationComments(evaluationId),
          bearer: bearer, decode: (j) {
        if (j is List) {
          return [
            for (final e in j)
              if (e is Map<String, dynamic>)
                journalCommentFromJson(e),
          ];
        }
        return <JournalComment>[];
      });

  Future<Paged<JournalEntry>> listJournal(
    String internshipId,
    String? bearer, {
    int page = 0,
    int size = 20,
    JournalStatus? status,
    DateTime? day,
  }) {
    final q = pageQuery(page: page, size: size);
    if (status != null) q['status'] = journalStatusToApi(status);
    if (day != null) {
      final d =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      q['startDate'] = d;
      q['endDate'] = d;
    }
    return _client.get(Endpoints.journalEntries(internshipId),
        bearer: bearer,
        query: q,
        decode: (j) => Paged.fromJson(j, journalFromJson));
  }

  Future<Paged<DeliverableSummary>> listDeliverables(
    String internshipId,
    String? bearer, {
    int page = 0,
    int size = 20,
  }) =>
      _client.get(Endpoints.deliverables(internshipId),
          bearer: bearer,
          query: pageQuery(page: page, size: size),
          decode: (j) => Paged.fromJson(j, deliverableFromJson));

  Future<Paged<EvaluationSummary>> listEvaluations(
    String internshipId,
    String? bearer, {
    int page = 0,
    int size = 20,
  }) =>
      _client.get(Endpoints.evaluations(internshipId),
          bearer: bearer,
          query: pageQuery(page: page, size: size),
          decode: (j) => Paged.fromJson(j, evaluationFromJson));

  Future<Paged<AppNotification>> listNotifications(
    String? bearer, {
    int page = 0,
    int size = 20,
    bool unreadOnly = false,
  }) {
    final q = pageQuery(page: page, size: size);
    if (unreadOnly) q['unreadOnly'] = 'true';
    return _client.get(Endpoints.notifications,
        bearer: bearer,
        query: q,
        decode: (j) => Paged.fromJson(j, notificationFromJson));
  }

  Future<void> markAllNotificationsRead(String? bearer) =>
      _client.post(Endpoints.notificationsReadAll,
          bearer: bearer, decode: (_) {});

  Future<List<ConversationLink>> listConversations(String? bearer) =>
      _client.get(Endpoints.conversations,
          bearer: bearer,
          decode: (j) => [
                if (j is List)
                  for (final e in j)
                    if (e is Map<String, dynamic>)
                      ConversationLink.fromJson(e),
              ]);

  Future<int> unreadMessageTotal(String? bearer) =>
      _client.get(Endpoints.unreadCounts, bearer: bearer, decode: (j) {
        if (j is! List) return 0;
        var total = 0;
        for (final e in j) {
          if (e is Map<String, dynamic>) {
            total += unreadCountFromJson(e);
          }
        }
        return total;
      });

  // --- D6: advisory logbook draft (participant-authorized) ---

  Future<LogbookDraft> generateLogbookDraft(
          String internshipId, String? bearer) =>
      _client.post(Endpoints.aiLogbook(internshipId),
          bearer: bearer,
          decode: (j) => logbookDraftFromJson(_map(j)));

  static Map<String, dynamic> _map(dynamic j) =>
      j is Map<String, dynamic> ? j : <String, dynamic>{};
}
