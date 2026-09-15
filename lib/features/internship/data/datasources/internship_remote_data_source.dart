import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/paged.dart';
import '../../domain/entities/internship.dart';
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

  Future<Paged<JournalEntry>> listJournal(
    String internshipId,
    String? bearer, {
    int page = 0,
    int size = 20,
    JournalStatus? status,
  }) {
    final q = pageQuery(page: page, size: size);
    if (status != null) q['status'] = journalStatusToApi(status);
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

  static Map<String, dynamic> _map(dynamic j) =>
      j is Map<String, dynamic> ? j : <String, dynamic>{};
}
