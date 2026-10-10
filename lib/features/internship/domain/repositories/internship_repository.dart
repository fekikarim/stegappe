import 'dart:typed_data';

import '../../../../core/network/paged.dart';
import '../dashboard.dart';
import '../entities/evaluation.dart';
import '../entities/internship.dart';
import '../entities/logbook.dart';
import '../entities/supervisor_tasks.dart';
import '../entities/task_classification.dart';
import '../entities/task_drafts.dart';
import '../entities/work_items.dart';

/// Read + limited-write contract for the intern daily workspace.
/// All values originate from the backend; the app never invents
/// business state (type, requirement, scores, eligibility).
abstract class InternshipRepository {
  /// Resolve the current user's internship id:
  /// cached id -> verify, else discover via PRIVATE conversation,
  /// else null (no linked internship yet).
  Future<String?> resolveMyInternshipId();

  Future<Internship> getInternship(String id);
  Future<List<InternshipAssignment>> getAssignments(String id);

  /// T13/B13: one-call student home snapshot (same sections as the lists).
  Future<InternshipSummary> internshipSummary(String internshipId);

  Future<Paged<InternTask>> listTasks(String internshipId,
      {int page = 0, int size = 50, TaskStatus? status});
  Future<InternTask> updateTaskStatus(String taskId, TaskStatus status,
      {String? idempotencyKey});
  Future<InternTask> createTask(String internshipId,
      {required String title,
      String? description,
      DateTime? dueDate,
      DateTime? visibleFrom});
  Future<InternTask> updateTask(String taskId,
      {required String title,
      String? description,
      DateTime? dueDate,
      TaskStatus? status,
      DateTime? visibleFrom});

  /// [day] narrows to one calendar day. [from]/[to] request an inclusive
  /// range (used by the journal month calendar to mark the days that already
  /// carry an entry without paging day by day). Both are date-only bounds —
  /// no timezone conversion, matching the backend `LocalDate` contract.
  Future<Paged<JournalEntry>> listJournal(String internshipId,
      {int page = 0,
      int size = 20,
      JournalStatus? status,
      DateTime? day,
      DateTime? from,
      DateTime? to});
  Future<JournalEntry> createJournal(String internshipId,
      {required String title,
      required String description,
      required DateTime entryDate});
  Future<JournalEntry> submitJournal(String entryId);
  Future<List<JournalComment>> journalComments(String entryId);

  /// Supervisor-only transitions (backend enforces `isSupervisorOf`).
  /// Always server-confirmed — never optimistic, never offline-implied.
  Future<JournalEntry> validateJournal(String entryId, String? comment);
  Future<JournalEntry> rejectJournal(String entryId, String? comment);

  /// Supervised internship ids from the own-scope endpoint
  /// (`GET /api/internships/supervised`, D1b/BR-03) — never derived from
  /// conversations (T12 deleted that workaround).
  Future<List<String>> supervisedInternshipIds();

  // --- T09 journal document: server window (B5) + AI generation (B6) ---

  /// Server-computed eligibility window + task-completion facts (BR-20/21/24).
  Future<JournalEligibility> journalEligibility(String internshipId);

  /// Generates the journal PDF from the student's tasks (server-assembled).
  Future<JournalGenerationResult> generateJournalFromTasks(String internshipId);

  /// Generates the journal PDF from the student's own (bounded) description.
  Future<JournalGenerationResult> generateJournalFromText(
      String internshipId, String text);

  // --- D3 deliverables (versioned, reviewed) ---

  Future<DeliverableDetail> createDeliverable(String internshipId,
      {required String title,
      String? description,
      String? documentKind,
      required String fileName,
      required Uint8List fileBytes,
      void Function(int sent, int total)? onProgress});
  Future<DeliverableDetail> uploadNewVersion(String deliverableId,
      {required String fileName,
      required Uint8List fileBytes,
      String? changeSummary,
      void Function(int sent, int total)? onProgress});
  Future<DeliverableDetail> getDeliverable(String deliverableId);
  Future<List<DeliverableVersionInfo>> deliverableVersions(
      String deliverableId);
  Future<DeliverableDetail> submitDeliverable(String deliverableId);

  /// T10/B7 — server-computed final-week submission window (BR-22). The app
  /// only reflects it; the device clock never decides.
  Future<SubmissionWindow> submissionWindow(String internshipId);

  /// T10/B8 + SU-VAL-01 — register a deliverable as `JOURNAL`/`REPORT` for
  /// the internship's validation (supervisor long-press path).
  Future<DeliverableDetail> registerDocumentKind(
      String deliverableId, String documentKind);
  Future<DeliverableDetail> validateDeliverable(
      String deliverableId, String? comment);
  Future<DeliverableDetail> rejectDeliverable(
      String deliverableId, String? comment);
  Future<Uint8List> downloadDeliverable(String deliverableId,
      {int? version});
  Future<List<JournalComment>> deliverableComments(String deliverableId);
  Future<List<PendingDeliverableReview>> pendingDeliverableReviews();

  Future<Paged<DeliverableSummary>> listDeliverables(String internshipId,
      {int page = 0, int size = 20});
  Future<Paged<EvaluationSummary>> listEvaluations(String internshipId,
      {int page = 0, int size = 20});

  Future<Paged<AppNotification>> listNotifications(
      {int page = 0, int size = 20});
  Future<int> unreadNotificationCount();
  Future<void> markAllNotificationsRead();
  Future<int> unreadMessageCount();

  /// T14/D14: ask own students to prepare validation documents. Returns
  /// the server-accepted recipient count. Server-validates scope (404),
  /// rate limit and idempotency — the app never decides.
  Future<int> notifyDocumentsPreparation(List<String> internshipIds,
      {String? idempotencyKey});

  /// T14: best-effort server sync of the UI locale (never blocks).
  Future<void> syncLocale(String code);

  // --- D4 evaluations (supervisor-authored, template-driven) ---

  Future<List<EvaluationTemplate>> listTemplates({bool activeOnly = true});
  Future<List<EvaluationCriterion>> templateCriteria(String templateId);
  Future<EvaluationSummary> createEvaluation(String internshipId,
      {String? templateId,
      required EvaluationKind kind,
      required DateTime date,
      String? feedback});
  Future<void> submitScores(String evaluationId,
      List<Map<String, dynamic>> scores);
  Future<void> addTaskReview(
      String evaluationId, Map<String, dynamic> review);
  Future<EvaluationSummary> evaluationDetail(String evaluationId);
  Future<List<EvaluationScore>> evaluationScores(String evaluationId);
  Future<List<EvaluationTaskReview>> evaluationTaskReviews(
      String evaluationId);
  Future<List<JournalComment>> evaluationComments(String evaluationId);

  /// Supervised interns with backend-sourced progress.
  Future<List<SupervisedIntern>> supervisedInterns();

  // --- D6 advisory AI (logbook draft only; never authoritative) ---

  /// Generate a review-only logbook draft from recorded data.
  /// Throws on AI outage/rate-limit — callers degrade gracefully and
  /// never block core flows on this.
  Future<LogbookDraft> generateLogbookDraft(String internshipId);

  /// Submit the reviewed logbook text for supervisor validation.
  /// The draft remains advisory; this is the explicit human-reviewed send.
  Future<void> submitLogbook(String internshipId, String finalText);

  /// Read the server-authoritative logbook; null when none exists yet.
  Future<LogbookState?> getLogbook(String internshipId);

  /// Supervisor/HR: approve a SUBMITTED logbook. Backend-enforced.
  Future<LogbookState> validateLogbook(
      String internshipId, String logbookId);
  /// Supervisor/HR: reject a SUBMITTED logbook with a required reason.
  /// Backend-enforced (empty reasons are rejected by the backend).
  Future<LogbookState> rejectLogbook(
      String internshipId, String logbookId, String reason);
  /// HR/ADMIN: finalize a VALIDATED logbook as OFFICIAL. Backend-enforced.
  Future<LogbookState> promoteLogbookOfficial(
      String internshipId, String logbookId);

  /// SUBMITTED logbooks across the supervisor's internships (fetch + filter
  /// client-side from the read endpoint; the backend stays authoritative).
  Future<List<PendingLogbookReview>> pendingLogbookReviews();

  /// Ask the role-scoped intern assistant (RAG over the controlled STEG base).
  /// Returns advisory text; throws on AI outage/rate-limit (degraded UI, no block).
  Future<String> askAssistant(String question);

  // --- T03 student task classification (server-authoritative, intern only) ---
  //
  // Categories are student-defined and private; classification never changes
  // task status. The backend is authoritative for ownership, validation,
  // compare-and-set and AI context; the app only renders and sends intents.

  /// Load my categories + the task→category map for one internship.
  Future<ClassificationBoard> classificationBoard(String internshipId);

  /// Create one of my categories (name unique per student, max 20).
  Future<TaskCategory> createCategory(String internshipId,
      {required String name, String? color});

  /// Rename / recolor one of my categories (owner only, 404 otherwise).
  Future<TaskCategory> renameCategory(String categoryId,
      {String? name, String? color});

  /// Reorder my categories (must contain exactly the current ones).
  Future<List<TaskCategory>> reorderCategories(List<String> orderedIds);

  /// Delete one of my categories (its tasks become unclassified).
  Future<void> deleteCategory(String categoryId);

  /// Assign or clear (null) my task's category with compare-and-set:
  /// applies only when the task still carries [expectedCategoryId]
  /// (null = still unclassified), unless [force] after an explicit confirm.
  /// Never changes the task status.
  Future<void> assignTaskCategory(String taskId,
      {String? categoryId, String? expectedCategoryId, bool force = false});

  /// AI proposals for my unclassified tasks. Advisory only — persists
  /// nothing. Throws on AI outage/rate-limit (degraded UI, no block).
  Future<ClassificationSuggestion> suggestCategories(String internshipId);

  /// Accept classifications: per-item compare-and-set with per-item results
  /// (never all-or-nothing, never overwrites a task classified meanwhile).
  /// [idempotencyKey] makes a double submit replay without duplicating.
  Future<ApplyCategoriesResult> applyCategories(String internshipId,
      {required List<Map<String, dynamic>> items,
      required String idempotencyKey});

  /// Undo an accepted batch: restores only tasks unchanged since the batch.
  Future<List<ApplyCategoryResult>> undoApplyBatch(String batchId);

  // --- T04 supervisor lifecycle (staff, scoped + validated server-side) ---
  //
  // The backend owns scope (out-of-scope → 404), transitions and validation;
  // the app only renders state and sends intents. Bulk is atomic with a
  // client idempotency key; review decides COMPLETED tasks only.

  /// Delete one task (supervisor/Admin). Confirm in UI; the intern is
  /// notified by the backend (TASK_DELETED).
  Future<void> deleteTask(String taskId);

  /// Review a COMPLETED task: approve (→ APPROVED, counts as done) or deny
  /// with a required reason (→ DENIED, back to the student with the reason).
  /// Throws on anything else (TASK_NOT_COMPLETED / REVIEW_REASON_REQUIRED).
  Future<InternTask> reviewTask(String taskId,
      {required bool approve, String? comment});

  /// Atomic bulk mutations in request order with per-item results.
  /// [idempotencyKey] makes a double submit replay without duplicating;
  /// regenerate it when the payload is corrected after a failure.
  Future<SupervisorBulkResult> bulkTasks(
      {required List<Map<String, dynamic>> mutations,
      required String idempotencyKey});

  // --- T05 supervisor AI task drafts (proposals, never real tasks) ---
  //
  // The backend owns scope (out-of-scope → 404), the strict schema, rate
  // limits and validation; the app renders drafts and sends intents. Only
  // bulk-add creates real tasks (atomic, idempotent, per-pair validated).

  /// Generate drafts from a specifications PDF for one reference student.
  /// Throws on AI outage/rate-limit (degraded UI, manual path stays open).
  Future<List<TaskDraft>> generateDraftsFromPdf(String internshipId,
      {required String fileName,
      required Uint8List bytes,
      void Function(int sent, int total)? onProgress});

  /// Generate drafts from pasted specification text (same pipeline).
  Future<List<TaskDraft>> generateDraftsFromText(String internshipId,
      {required String specText});

  /// My drafts, optionally for one reference internship.
  Future<List<TaskDraft>> listDrafts({String? internshipId});

  /// Manual draft (works even when AI is unavailable).
  Future<TaskDraft> addDraftManual(String internshipId,
      {required String title, String? description, DateTime? dueDate});

  /// Manual draft edit (lengths and period re-validated server-side).
  Future<TaskDraft> updateDraft(String draftId,
      {String? title, String? description, DateTime? dueDate});

  /// AI revision of one draft from a free-text instruction.
  Future<TaskDraft> reviseDraft(String draftId, {required String instruction});

  /// Delete one draft (owner only, 404 otherwise).
  Future<void> deleteDraft(String draftId);

  /// Atomically bulk-add approved drafts to one or more students.
  /// [idempotencyKey] makes a double submit replay without duplicating.
  /// Optional batch schedule ([visibleFrom], T04 D8 rule per target).
  Future<DraftBulkResult> bulkAddDrafts(
      {required List<String> draftIds,
      required List<String> internshipIds,
      required String idempotencyKey,
      DateTime? visibleFrom});
}

/// One SUBMITTED deliverable awaiting supervisor review.
class PendingDeliverableReview {
  const PendingDeliverableReview({
    required this.internshipId,
    required this.internshipReference,
    required this.deliverable,
  });

  final String internshipId;
  final String internshipReference;
  final DeliverableSummary deliverable;
}

/// One SUBMITTED logbook awaiting supervisor/HR review.
class PendingLogbookReview {
  const PendingLogbookReview({
    required this.internshipId,
    required this.internshipReference,
    required this.logbook,
  });

  final String internshipId;
  final String internshipReference;
  final LogbookState logbook;
}
