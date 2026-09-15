import '../../../../core/network/paged.dart';
import '../entities/internship.dart';
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
  Future<Paged<DeliverableSummary>> listDeliverables(String internshipId,
      {int page = 0, int size = 20});
  Future<Paged<EvaluationSummary>> listEvaluations(String internshipId,
      {int page = 0, int size = 20});

  Future<Paged<AppNotification>> listNotifications(
      {int page = 0, int size = 20});
  Future<int> unreadNotificationCount();
  Future<void> markAllNotificationsRead();
  Future<int> unreadMessageCount();
}
