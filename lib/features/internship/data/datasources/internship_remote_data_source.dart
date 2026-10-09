import 'dart:typed_data';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/paged.dart';
import '../../domain/dashboard.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/internship.dart';
import '../../domain/entities/logbook.dart';
import '../../domain/entities/supervisor_tasks.dart';
import '../../domain/entities/task_drafts.dart';
import '../../domain/entities/task_classification.dart';
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

  Future<Internship?> getMyInternship(String? bearer) =>
      _client.get(Endpoints.internshipMine,
          bearer: bearer,
          decode: (j) => j == null ? null : internshipFromJson(_map(j)));

  /// T13/B13: one-call student home snapshot (same sections as the lists).
  Future<InternshipSummary> internshipSummary(
          String internshipId, String? bearer) =>
      _client.get(Endpoints.internshipSummary(internshipId),
          bearer: bearer,
          decode: (j) => internshipSummaryFromJson(_map(j)));

  /// T14/D14: ask own students to prepare validation documents. The
  /// idempotency key makes a double submit replay without duplicating.
  Future<int> notifyDocumentsPreparation(
          List<String> internshipIds, String? bearer,
          {String? idempotencyKey}) =>
      _client.post(Endpoints.notifyDocumentPreparation,
          bearer: bearer,
          headers: idempotencyKey == null
              ? null
              : {'X-Idempotency-Key': idempotencyKey},
          body: {'internshipIds': internshipIds},
          decode: (j) =>
              (_map(j)['notified'] as num?)?.toInt() ?? 0);

  /// T14: best-effort server sync of the UI locale (never blocks the switch).
  Future<void> syncLocale(String code, String? bearer) => _client.put(
      Endpoints.userLocale,
      bearer: bearer,
      body: {'locale': code},
      decode: (_) {});

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
    final api = status == null ? null : taskStatusToApi(status);
    if (api != null) q['status'] = api;
    return _client.get(Endpoints.internshipTasks(internshipId),
        bearer: bearer,
        query: q,
        decode: (j) => Paged.fromJson(j, taskFromJson));
  }

  Future<InternTask> updateTaskStatus(
      String taskId, TaskStatus status, String? bearer,
      {String? idempotencyKey}) {
    final api = taskStatusToApi(status);
    if (api == null) {
      // T02/BR-10: `unknown` is not part of the backend vocabulary and is
      // never sent; the board offers no transition for such a task.
      throw StateError('unknown-task-status');
    }
    return _client.patch(Endpoints.taskStatus(taskId),
        bearer: bearer,
        query: {'status': api},
        headers: idempotencyKey == null
            ? null
            : {'X-Idempotency-Key': idempotencyKey},
        decode: (j) => taskFromJson(_map(j)));
  }

  // --- D2 writes: tasks ---

  Future<InternTask> createTask(
    String internshipId,
    String? bearer, {
    required String title,
    String? description,
    DateTime? dueDate,
    DateTime? visibleFrom,
  }) =>
      _client.post(Endpoints.internshipTasks(internshipId),
          bearer: bearer,
          body: taskWriteJson(
              title: title,
              description: description,
              dueDate: dueDate,
              visibleFrom: visibleFrom),
          decode: (j) => taskFromJson(_map(j)));

  Future<InternTask> updateTask(
    String taskId,
    String? bearer, {
    required String title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    DateTime? visibleFrom,
  }) =>
      _client.put(Endpoints.task(taskId),
          bearer: bearer,
          body: taskWriteJson(
              title: title,
              description: description,
              dueDate: dueDate,
              status: status,
              visibleFrom: visibleFrom),
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

  // --- T09/B5+B6: journal eligibility window + AI journal document ---

  /// Server-authoritative window + task ratio (BR-21: never the device clock).
  Future<JournalEligibility> journalEligibility(
          String internshipId, String? bearer) =>
      _client.get(Endpoints.journalEligibility(internshipId),
          bearer: bearer, decode: (j) => journalEligibilityFromJson(_map(j)));

  /// Generate the journal PDF from the internship's own tasks.
  Future<JournalGenerationResult> generateJournalFromTasks(
          String internshipId, String? bearer) =>
      _client.post(Endpoints.journalGenerate(internshipId),
          bearer: bearer, decode: (j) => journalGenerationFromJson(_map(j)));

  /// Generate the journal PDF from the student's bounded description.
  Future<JournalGenerationResult> generateJournalFromText(
          String internshipId, String? bearer, String text) =>
      _client.post(Endpoints.journalGenerateFromText(internshipId),
          bearer: bearer,
          body: {'text': text},
          decode: (j) => journalGenerationFromJson(_map(j)));

  // --- D3: deliverables (multipart, versioned, reviewed) ---

  Future<DeliverableDetail> createDeliverable(
    String internshipId,
    String? bearer, {
    required String title,
    String? description,
    String? documentKind,
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
            // T10/B8: explicit validation document kind (JOURNAL/REPORT);
            // absent means a free document with no validation slot.
            if (documentKind != null && documentKind.isNotEmpty)
              'documentKind': documentKind,
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

  /// T10/B7 — the server-owned final-week submission window (BR-22,
  /// `Africa/Tunis`). Read so the app shows/hides the submit action honestly.
  Future<SubmissionWindow> submissionWindow(
          String internshipId, String? bearer) =>
      _client.get(Endpoints.submissionWindow(internshipId),
          bearer: bearer, decode: (j) => submissionWindowFromJson(_map(j)));

  /// T10/B8 + SU-VAL-01 — register a deliverable as the internship's journal
  /// or report (one per kind; VALIDATED documents are locked server-side).
  Future<DeliverableDetail> registerDocumentKind(
          String deliverableId, String? bearer, String documentKind) =>
      _client.post(Endpoints.deliverableDocumentKind(deliverableId),
          bearer: bearer,
          body: {'documentKind': documentKind},
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

  /// T12/B2: own-scope supervised internships with server counts (one call;
  /// D1b own-students semantics even for an ADMIN caller).
  Future<List<SupervisedIntern>> supervisedInternships(String? bearer) =>
      _client.get(Endpoints.supervisedInternships,
          bearer: bearer,
          decode: (j) => [
                if (j is List)
                  for (final e in j)
                    if (e is Map<String, dynamic>)
                      supervisedInternFromJson(e),
              ]);

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

  /// Submit reviewed logbook text for supervisor validation.
  Future<void> submitLogbook(
          String internshipId, String finalText, String? bearer) =>
      _client.post(Endpoints.logbookSubmit(internshipId),
          bearer: bearer,
          body: {'finalText': finalText},
          decode: (_) {});

  /// Read the server-authoritative logbook for an internship. Throws on 404
  /// when no logbook exists yet (caller decides how to surface that).
  Future<LogbookState> getLogbook(String internshipId, String? bearer) =>
      _client.get(Endpoints.logbook(internshipId),
          bearer: bearer, decode: (j) => logbookFromJson(_map(j)));

  /// Supervisor/HAL: approve a SUBMITTED logbook (server-enforced; reason
  /// comment is optional, no local business rule).
  Future<LogbookState> validateLogbook(
          String internshipId, String logbookId, String? bearer) =>
      _client.post(Endpoints.logbookValidate(internshipId, logbookId),
          bearer: bearer, decode: (j) => logbookFromJson(_map(j)));

  /// Supervisor/HAL: reject a SUBMITTED logbook with a required reason
  /// (server-enforced; the backend rejects empty reasons).
  Future<LogbookState> rejectLogbook(
          String internshipId, String logbookId, String? bearer,
          {required String reason}) =>
      _client.post(Endpoints.logbookReject(internshipId, logbookId),
          bearer: bearer,
          body: {'reason': reason},
          decode: (j) => logbookFromJson(_map(j)));

  /// HR/ADMIN: finalize a VALIDATED logbook as OFFICIAL (server-enforced).
  Future<LogbookState> promoteLogbookOfficial(
          String internshipId, String logbookId, String? bearer) =>
      _client.post(Endpoints.logbookOfficial(internshipId, logbookId),
          bearer: bearer, decode: (j) => logbookFromJson(_map(j)));

  /// Intern assistant answer (role-scoped RAG; key stays on the backend).
  /// Returns the advisory answer text; throws ApiException on outage/rate-limit.
  Future<String> askAssistant(String question, String? bearer) =>
      _client.post(Endpoints.aiAssistant,
          bearer: bearer,
          body: {'question': question},
          decode: (j) => assistantAnswerFromJson(_map(j)));

  static Map<String, dynamic> _map(dynamic j) =>
      j is Map<String, dynamic> ? j : <String, dynamic>{};
}

extension TaskClassificationDataSource on InternshipRemoteDataSource {
  // --- T03 student task classification (intern only, server-authoritative) ---

  Future<ClassificationBoard> getClassificationBoard(
    String internshipId,
    String? bearer,
  ) =>
      _client.get(Endpoints.taskCategories(internshipId),
          bearer: bearer,
          decode: (j) => classificationBoardFromJson(j));

  Future<TaskCategory> createCategory(
    String internshipId,
    String? bearer, {
    required String name,
    String? color,
  }) {
    final body = <String, dynamic>{'name': name};
    if (color != null) body['color'] = color;
    return _client.post(Endpoints.taskCategories(internshipId),
        bearer: bearer,
        body: body,
        decode: (j) =>
            taskCategoryFromJson(InternshipRemoteDataSource._map(j)));
  }

  Future<TaskCategory> renameCategory(
    String categoryId,
    String? bearer, {
    String? name,
    String? color,
  }) {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (color != null) body['color'] = color;
    return _client.put(Endpoints.taskCategory(categoryId),
        bearer: bearer,
        body: body,
        decode: (j) =>
            taskCategoryFromJson(InternshipRemoteDataSource._map(j)));
  }

  Future<List<TaskCategory>> reorderCategories(
    String? bearer,
    List<String> orderedIds,
  ) =>
      _client.put(Endpoints.taskCategoriesOrder,
          bearer: bearer,
          body: {
            'orderedIds': orderedIds,
          },
          decode: (j) => [
            if (j is List)
              for (final e in j)
                if (e is Map<String, dynamic>) taskCategoryFromJson(e),
          ]);

  Future<void> deleteCategory(String categoryId, String? bearer) =>
      _client.delete<void>(Endpoints.taskCategory(categoryId),
          bearer: bearer, decode: (_) {});

  Future<void> assignTaskCategory(
    String taskId,
    String? bearer, {
    String? categoryId,
    String? expectedCategoryId,
    bool force = false,
  }) =>
      _client.put<void>(Endpoints.taskCategoryAssign(taskId),
          bearer: bearer,
          body: assignCategoryJson(
              categoryId: categoryId,
              expectedCategoryId: expectedCategoryId,
              force: force),
          decode: (_) {});

  Future<ClassificationSuggestion> suggestCategories(
    String internshipId,
    String? bearer,
  ) =>
      _client.post(Endpoints.taskCategoriesSuggest(internshipId),
          bearer: bearer,
          decode: (j) {
            final map = InternshipRemoteDataSource._map(j);
            return ClassificationSuggestion(
              proposals: categoryProposalsFromJson(map),
              unclassifiedCount:
                  (map['unclassifiedTaskCount'] as num?)?.toInt() ?? 0,
              capped: map['capped'] == true,
            );
          });

  Future<ApplyCategoriesResult> applyCategories(
    String internshipId,
    String? bearer, {
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
  }) =>
      _client.post(Endpoints.taskCategoriesApply(internshipId),
          bearer: bearer,
          headers: {'X-Idempotency-Key': idempotencyKey},
          body: {
            'items': items,
          },
          decode: (j) {
            final map = InternshipRemoteDataSource._map(j);
            return ApplyCategoriesResult(
              batchId: map['batchId']?.toString(),
              items: applyResultsFromJson(map),
            );
          });

  Future<List<ApplyCategoryResult>> undoApplyBatch(
    String batchId,
    String? bearer,
  ) =>
      _client.post(Endpoints.taskCategoryUndo(batchId),
          bearer: bearer,
          decode: (j) => applyResultsFromJson(
              InternshipRemoteDataSource._map(j)));
}

extension SupervisorTaskDataSource on InternshipRemoteDataSource {
  // --- T04 supervisor lifecycle (staff, scoped + validated server-side) ---

  Future<void> deleteTask(String taskId, String? bearer) =>
      _client.delete<void>(Endpoints.task(taskId),
          bearer: bearer, decode: (_) {});

  /// Review a COMPLETED task: approve (→ APPROVED) or deny with a required
  /// reason (→ DENIED). The backend refuses anything else.
  Future<InternTask> reviewTask(
    String taskId,
    String? bearer, {
    required bool approve,
    String? comment,
  }) =>
      _client.post(Endpoints.taskReview(taskId),
          bearer: bearer,
          body: taskReviewJson(approve: approve, comment: comment),
          decode: (j) => taskFromJson(InternshipRemoteDataSource._map(j)));

  /// Atomic bulk (all-or-nothing server-side) with a client idempotency key
  /// so a double submit replays instead of duplicating.
  Future<SupervisorBulkResult> bulkTasks(
    String? bearer, {
    required List<Map<String, dynamic>> mutations,
    required String idempotencyKey,
  }) =>
      _client.post(Endpoints.tasksBulk,
          bearer: bearer,
          headers: {'X-Idempotency-Key': idempotencyKey},
          body: mutations,
          decode: (j) => supervisorBulkResultFromJson(j));
}

extension TaskDraftDataSource on InternshipRemoteDataSource {
  // --- T05 supervisor AI task drafts (staff, scoped server-side) ---

  /// Generate drafts from a specifications PDF (multipart). Progress
  /// reports upload bytes; the server caps (25 MB, 50 pages, magic bytes).
  Future<List<TaskDraft>> generateDraftsFromPdf(
    String internshipId,
    String? bearer, {
    required String fileName,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) =>
      _client.uploadMultipart(Endpoints.taskDraftsGenerate,
          bearer: bearer,
          fields: {'internshipId': internshipId},
          fileField: 'file',
          fileName: fileName,
          contentType: 'application/pdf',
          bytes: bytes,
          onProgress: onProgress,
          decode: (j) => taskDraftListFromJson(j));

  /// Generate drafts from pasted specification text (same pipeline).
  Future<List<TaskDraft>> generateDraftsFromText(
    String internshipId,
    String? bearer, {
    required String specText,
  }) =>
      _client.post(Endpoints.taskDraftsGenerateFromText,
          bearer: bearer,
          body: {'internshipId': internshipId, 'specText': specText},
          decode: (j) => taskDraftListFromJson(j));

  /// My drafts, optionally for one reference internship.
  Future<List<TaskDraft>> listDrafts(
    String? bearer, {
    String? internshipId,
  }) =>
      _client.get(Endpoints.taskDrafts,
          bearer: bearer,
          query: internshipId == null ? null : {'internshipId': internshipId},
          decode: (j) {
        if (j is List) return taskDraftListFromJson(j);
        return const <TaskDraft>[];
      });

  /// Manual draft (works even when AI is unavailable).
  Future<TaskDraft> addDraftManual(
    String? bearer, {
    required String referenceInternshipId,
    required String title,
    String? description,
    DateTime? dueDate,
  }) =>
      _client.post(Endpoints.taskDrafts,
          bearer: bearer,
          body: manualDraftJson(
              referenceInternshipId: referenceInternshipId,
              title: title,
              description: description,
              dueDate: dueDate),
          decode: (j) {
        final draft =
            taskDraftFromJson(InternshipRemoteDataSource._map(j));
        if (draft == null) throw StateError('draft-malformed');
        return draft;
      });

  Future<TaskDraft> updateDraft(
    String draftId,
    String? bearer, {
    String? title,
    String? description,
    DateTime? dueDate,
  }) =>
      _client.put(Endpoints.taskDraft(draftId),
          bearer: bearer,
          body: updateDraftJson(
              title: title, description: description, dueDate: dueDate),
          decode: (j) {
        final draft =
            taskDraftFromJson(InternshipRemoteDataSource._map(j));
        if (draft == null) throw StateError('draft-malformed');
        return draft;
      });

  /// AI revision of one draft from a free-text instruction.
  Future<TaskDraft> reviseDraft(
    String draftId,
    String? bearer, {
    required String instruction,
  }) =>
      _client.post(Endpoints.taskDraftRevise(draftId),
          bearer: bearer,
          body: {'instruction': instruction},
          decode: (j) {
        final draft =
            taskDraftFromJson(InternshipRemoteDataSource._map(j));
        if (draft == null) throw StateError('draft-malformed');
        return draft;
      });

  Future<void> deleteDraft(String draftId, String? bearer) =>
      _client.delete<void>(Endpoints.taskDraft(draftId),
          bearer: bearer, decode: (_) {});

  /// Atomic bulk-add of approved drafts (all-or-nothing server-side) with
  /// a client idempotency key. Optional batch schedule (T04 D8 rule).
  Future<DraftBulkResult> bulkAddDrafts(
    String? bearer, {
    required List<String> draftIds,
    required List<String> internshipIds,
    required String idempotencyKey,
    DateTime? visibleFrom,
  }) =>
      _client.post(Endpoints.taskDraftsBulkAdd,
          bearer: bearer,
          headers: {'X-Idempotency-Key': idempotencyKey},
          body: bulkAddDraftsJson(
              draftIds: draftIds,
              internshipIds: internshipIds,
              visibleFrom: visibleFrom),
          decode: (j) => draftBulkResultFromJson(j));
}
