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

  Future<Paged<JournalEntry>> listJournal(String internshipId,
      {int page = 0, int size = 20, JournalStatus? status});
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
