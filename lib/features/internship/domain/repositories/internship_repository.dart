import 'dart:typed_data';

import '../../../../core/network/paged.dart';
import '../entities/evaluation.dart';
import '../entities/internship.dart';
import '../entities/logbook.dart';
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

  Future<Paged<InternTask>> listTasks(String internshipId,
      {int page = 0, int size = 50, TaskStatus? status});
  Future<InternTask> updateTaskStatus(String taskId, TaskStatus status);
  Future<InternTask> createTask(String internshipId,
      {required String title, String? description, DateTime? dueDate});
  Future<InternTask> updateTask(String taskId,
      {required String title,
      String? description,
      DateTime? dueDate,
      TaskStatus? status});

  Future<Paged<JournalEntry>> listJournal(String internshipId,
      {int page = 0,
      int size = 20,
      JournalStatus? status,
      DateTime? day});
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

  /// Internship ids visible through the supervisor's PRIVATE
  /// conversations (backend auto-creates the thread on assignment).
  Future<List<String>> supervisedInternshipIds();

  // --- D3 deliverables (versioned, reviewed) ---

  Future<DeliverableDetail> createDeliverable(String internshipId,
      {required String title,
      String? description,
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
