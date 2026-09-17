import 'dart:typed_data';

import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/internship.dart';
import '../../domain/entities/logbook.dart';
import '../../domain/entities/work_items.dart';
import '../../domain/repositories/internship_repository.dart';
import '../../../../core/network/paged.dart';
import '../cache/internship_id_store.dart';
import '../datasources/internship_remote_data_source.dart';

/// Coordinates remote DS + token storage + cached internship id.
///
/// Internship-id resolution (no `GET /api/internships/mine` exists in the
/// current contract — flagged as backend follow-up):
///   1. cached id -> verify with GET detail (handles reassignment drift);
///   2. else PRIVATE conversation carrying `internshipId` (backend
///      auto-creates the thread on assignment) -> verify + cache;
///   3. else null -> UI shows the "no linked internship" empty state.
///
/// Verification failures with 403/404 invalidate the cache and fall
/// through to discovery; network errors rethrow so the UI can show the
/// cached dashboard as stale instead of wiping it.
class InternshipRepositoryImpl implements InternshipRepository {
  InternshipRepositoryImpl({
    required this.remote,
    required this.tokens,
    required this.idStore,
  });

  final InternshipRemoteDataSource remote;
  final TokenStorage tokens;
  final InternshipIdStore idStore;

  Future<String?> _bearer() => tokens.readAccessToken();

  @override
  Future<String?> resolveMyInternshipId() async {
    final bearer = await _bearer();
    final cached = await idStore.read();
    if (cached != null && cached.isNotEmpty) {
      try {
        await remote.getInternship(cached, bearer);
        return cached;
      } on ApiException catch (e) {
        if (e.kind == ApiErrorKind.network) rethrow;
        await idStore.clear(); // stale/forbidden -> rediscover
      }
    }
    try {
      final conversations = await remote.listConversations(bearer);
      for (final c in conversations) {
        final id = c.internshipId;
        if (c.type.toUpperCase() == 'PRIVATE' &&
            id != null &&
            id.isNotEmpty) {
          await remote.getInternship(id, bearer); // verify ownership
          await idStore.write(id);
          return id;
        }
      }
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.network) rethrow;
      // Authorization errors -> genuinely no accessible internship.
      if (e.kind == ApiErrorKind.forbidden ||
          e.kind == ApiErrorKind.unauthorized) {
        return null;
      }
      rethrow;
    }
    return null;
  }

  @override
  Future<Internship> getInternship(String id) async =>
      remote.getInternship(id, await _bearer());

  @override
  Future<List<InternshipAssignment>> getAssignments(String id) async =>
      remote.getAssignments(id, await _bearer());

  @override
  Future<Paged<InternTask>> listTasks(String internshipId,
          {int page = 0, int size = 50, TaskStatus? status}) async =>
      remote.listTasks(internshipId, await _bearer(),
          page: page, size: size, status: status);

  @override
  Future<InternTask> updateTaskStatus(
          String taskId, TaskStatus status) async =>
      remote.updateTaskStatus(taskId, status, await _bearer());

  @override
  Future<InternTask> createTask(String internshipId,
          {required String title,
          String? description,
          DateTime? dueDate}) async =>
      remote.createTask(internshipId, await _bearer(),
          title: title, description: description, dueDate: dueDate);

  @override
  Future<InternTask> updateTask(String taskId,
          {required String title,
          String? description,
          DateTime? dueDate,
          TaskStatus? status}) async =>
      remote.updateTask(taskId, await _bearer(),
          title: title,
          description: description,
          dueDate: dueDate,
          status: status);

  @override
  Future<Paged<JournalEntry>> listJournal(String internshipId,
          {int page = 0,
          int size = 20,
          JournalStatus? status,
          DateTime? day}) async =>
      remote.listJournal(internshipId, await tokens.readAccessToken(),
          page: page, size: size, status: status, day: day);

  @override
  Future<JournalEntry> createJournal(String internshipId,
          {required String title,
          required String description,
          required DateTime entryDate}) async =>
      remote.createJournal(internshipId, await tokens.readAccessToken(),
          title: title, description: description, entryDate: entryDate);

  @override
  Future<JournalEntry> submitJournal(String entryId) async =>
      remote.submitJournal(entryId, await tokens.readAccessToken());

  @override
  Future<List<JournalComment>> journalComments(String entryId) async =>
      remote.journalComments(entryId, await tokens.readAccessToken());

  @override
  Future<JournalEntry> validateJournal(
          String entryId, String? comment) async =>
      remote.validateJournal(
          entryId, await tokens.readAccessToken(), comment);

  @override
  Future<JournalEntry> rejectJournal(String entryId, String? comment) async =>
      remote.rejectJournal(entryId, await tokens.readAccessToken(), comment);

  @override
  Future<List<String>> supervisedInternshipIds() async {
    final conversations =
        await remote.listConversations(await tokens.readAccessToken());
    final ids = <String>{};
    for (final c in conversations) {
      final id = c.internshipId;
      if (c.type.toUpperCase() == 'PRIVATE' &&
          id != null &&
          id.isNotEmpty) {
        ids.add(id);
      }
    }
    return ids.toList();
  }

  @override
  Future<Paged<DeliverableSummary>> listDeliverables(String internshipId,
          {int page = 0, int size = 20}) async =>
      remote.listDeliverables(internshipId, await _bearer(),
          page: page, size: size);

  @override
  Future<Paged<EvaluationSummary>> listEvaluations(String internshipId,
          {int page = 0, int size = 20}) async =>
      remote.listEvaluations(internshipId, await _bearer(),
          page: page, size: size);

  @override
  Future<Paged<AppNotification>> listNotifications(
          {int page = 0, int size = 20}) async =>
      remote.listNotifications(await _bearer(), page: page, size: size);

  @override
  Future<int> unreadNotificationCount() async {
    final page =
        await remote.listNotifications(await _bearer(), unreadOnly: true);
    return page.totalElements;
  }

  @override
  Future<void> markAllNotificationsRead() async =>
      remote.markAllNotificationsRead(await _bearer());

  @override
  Future<DeliverableDetail> createDeliverable(String internshipId,
          {required String title,
          String? description,
          required String fileName,
          required Uint8List fileBytes,
          void Function(int sent, int total)? onProgress}) async =>
      remote.createDeliverable(internshipId, await _bearer(),
          title: title,
          description: description,
          fileName: fileName,
          fileBytes: fileBytes,
          onProgress: onProgress);

  @override
  Future<DeliverableDetail> uploadNewVersion(String deliverableId,
          {required String fileName,
          required Uint8List fileBytes,
          String? changeSummary,
          void Function(int sent, int total)? onProgress}) async =>
      remote.uploadNewVersion(deliverableId, await _bearer(),
          fileName: fileName,
          fileBytes: fileBytes,
          changeSummary: changeSummary,
          onProgress: onProgress);

  @override
  Future<DeliverableDetail> getDeliverable(String deliverableId) async {
    final detail = await remote.getDeliverable(
        deliverableId, await _bearer());
    final versions =
        await remote.deliverableVersions(deliverableId, await _bearer());
    final sorted = [...versions]
      ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return DeliverableDetail(
      id: detail.id,
      title: detail.title,
      description: detail.description,
      status: detail.status,
      currentVersion: detail.currentVersion,
      submittedAt: detail.submittedAt,
      validatedAt: detail.validatedAt,
      validatedByName: detail.validatedByName,
      versions: sorted,
    );
  }

  @override
  Future<List<DeliverableVersionInfo>> deliverableVersions(
          String deliverableId) async =>
      remote.deliverableVersions(deliverableId, await _bearer());

  @override
  Future<DeliverableDetail> submitDeliverable(
          String deliverableId) async =>
      remote.submitDeliverable(deliverableId, await _bearer());

  @override
  Future<DeliverableDetail> validateDeliverable(
          String deliverableId, String? comment) async =>
      remote.validateDeliverable(
          deliverableId, await _bearer(), comment);

  @override
  Future<DeliverableDetail> rejectDeliverable(
          String deliverableId, String? comment) async =>
      remote.rejectDeliverable(deliverableId, await _bearer(), comment);

  @override
  Future<Uint8List> downloadDeliverable(String deliverableId,
          {int? version}) async =>
      remote.downloadDeliverable(deliverableId, await _bearer(),
          version: version);

  @override
  Future<List<JournalComment>> deliverableComments(
          String deliverableId) async =>
      remote.deliverableComments(deliverableId, await _bearer());

  @override
  Future<List<PendingDeliverableReview>> pendingDeliverableReviews() async {
    final ids = await supervisedInternshipIds();
    final out = <PendingDeliverableReview>[];
    Object? firstError;
    final results = await Future.wait(ids.map((id) async {
      try {
        final page = await listDeliverables(id, size: 50);
        String reference = id;
        try {
          reference = (await getInternship(id)).reference;
        } on Exception {
          // Reference is decoration; the queue matters.
        }
        return MapEntry(
            reference,
            page.items
                .where((d) => d.awaitsSupervisor)
                .map((d) => PendingDeliverableReview(
                    internshipId: id,
                    internshipReference: reference,
                    deliverable: d)));
      } on Exception catch (e) {
        firstError ??= e;
        return const MapEntry('', <PendingDeliverableReview>[]);
      }
    }));
    for (final r in results) {
      out.addAll(r.value);
    }
    if (out.isEmpty && firstError != null) throw firstError!;
    return out;
  }

  @override
  Future<int> unreadMessageCount() async =>
      remote.unreadMessageTotal(await _bearer());

  @override
  Future<List<EvaluationTemplate>> listTemplates(
          {bool activeOnly = true}) async =>
      remote.listTemplates(await _bearer(), activeOnly: activeOnly);

  @override
  Future<List<EvaluationCriterion>> templateCriteria(
          String templateId) async =>
      remote.templateCriteria(templateId, await _bearer());

  @override
  Future<EvaluationSummary> createEvaluation(String internshipId,
          {String? templateId,
          required EvaluationKind kind,
          required DateTime date,
          String? feedback}) async =>
      remote.createEvaluation(internshipId, await _bearer(),
          templateId: templateId,
          kind: kind,
          date: date,
          feedback: feedback);

  @override
  Future<void> submitScores(String evaluationId,
          List<Map<String, dynamic>> scores) async =>
      remote.submitScores(evaluationId, await _bearer(), scores);

  @override
  Future<void> addTaskReview(
          String evaluationId, Map<String, dynamic> review) async =>
      remote.addTaskReview(evaluationId, await _bearer(), review);

  @override
  Future<EvaluationSummary> evaluationDetail(String evaluationId) async =>
      remote.evaluationDetail(evaluationId, await _bearer());

  @override
  Future<List<EvaluationScore>> evaluationScores(
          String evaluationId) async =>
      remote.evaluationScores(evaluationId, await _bearer());

  @override
  Future<List<EvaluationTaskReview>> evaluationTaskReviews(
          String evaluationId) async =>
      remote.evaluationTaskReviews(evaluationId, await _bearer());

  @override
  Future<List<JournalComment>> evaluationComments(
          String evaluationId) async =>
      remote.evaluationComments(evaluationId, await _bearer());

  @override
  Future<List<SupervisedIntern>> supervisedInterns() async {
    final ids = await supervisedInternshipIds();
    final out = <SupervisedIntern>[];
    final results = await Future.wait(ids.map((id) async {
      try {
        final internship = await getInternship(id);
        final bearer = await _bearer();
        final assignments =
            await remote.getAssignments(id, bearer);
        final tasks = await remote.listTasks(id, bearer, size: 1);
        final done = await remote.listTasks(id, bearer,
            size: 1, status: TaskStatus.completed);
        final drafts = await remote.listJournal(id, bearer,
            size: 1, status: JournalStatus.draft);
        final rejected = await remote.listJournal(id, bearer,
            size: 1, status: JournalStatus.rejected);
        final submitted = await remote.listJournal(id, bearer,
            size: 1, status: JournalStatus.submitted);
        final deliverables =
            await remote.listDeliverables(id, bearer, size: 50);
        final evaluations =
            await remote.listEvaluations(id, bearer, size: 1);
        InternshipAssignment? active;
        for (final a in assignments) {
          if (a.isActive) {
            active = a;
            break;
          }
        }
        return SupervisedIntern(
          internshipId: id,
          reference: internship.reference,
          internName: internship.candidateFullName ?? '—',
          status: internship.status,
          type: internship.type,
          startDate: internship.startDate,
          endDate: internship.endDate,
          departmentName: active?.departmentName ?? '—',
          tasksCompleted: done.totalElements,
          tasksTotal: tasks.totalElements,
          pendingJournal: drafts.totalElements +
              rejected.totalElements +
              submitted.totalElements,
          pendingDeliverables: deliverables.items
              .where((d) => d.awaitsSupervisor)
              .length,
          evaluationsCount: evaluations.totalElements,
        );
      } on Exception {
        return null; // fail-soft: one intern never hides the others
      }
    }));
    for (final s in results) {
      if (s != null) out.add(s);
    }
    return out;
  }

  @override
  Future<LogbookDraft> generateLogbookDraft(
          String internshipId) async =>
      remote.generateLogbookDraft(
          internshipId, await _bearer());

  @override
  Future<void> submitLogbook(
          String internshipId, String finalText) async =>
      remote.submitLogbook(
          internshipId, finalText, await _bearer());

  @override
  Future<LogbookState?> getLogbook(String internshipId) async {
    try {
      return await remote.getLogbook(internshipId, await _bearer());
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }

  @override
  Future<LogbookState> validateLogbook(
          String internshipId, String logbookId) async =>
      remote.validateLogbook(
          internshipId, logbookId, await _bearer());

  @override
  Future<LogbookState> rejectLogbook(
          String internshipId, String logbookId, String reason) async =>
      remote.rejectLogbook(
          internshipId, logbookId, await _bearer(), reason: reason);

  @override
  Future<LogbookState> promoteLogbookOfficial(
          String internshipId, String logbookId) async =>
      remote.promoteLogbookOfficial(
          internshipId, logbookId, await _bearer());

  @override
  Future<List<PendingLogbookReview>> pendingLogbookReviews() async {
    final ids = await supervisedInternshipIds();
    final out = <PendingLogbookReview>[];
    final results = await Future.wait(ids.map((id) async {
      try {
        final logbook = await getLogbook(id);
        if (logbook == null || !logbook.isPendingReview) {
          return const <PendingLogbookReview>[];
        }
        String reference = id;
        try {
          reference = (await getInternship(id)).reference;
        } on Exception {
          // Reference is decoration; the queue matters.
        }
        return [
          PendingLogbookReview(
              internshipId: id,
              internshipReference: reference,
              logbook: logbook),
        ];
      } on Exception {
        return const <PendingLogbookReview>[];
      }
    }));
    for (final r in results) {
      out.addAll(r);
    }
    return out;
  }

  @override
  Future<String> askAssistant(String question) async =>
      remote.askAssistant(question, await _bearer());
}
