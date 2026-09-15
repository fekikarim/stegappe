import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/internship.dart';
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
  Future<Paged<JournalEntry>> listJournal(String internshipId,
          {int page = 0, int size = 20, JournalStatus? status}) async =>
      remote.listJournal(internshipId, await _bearer(),
          page: page, size: size, status: status);

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
  Future<int> unreadMessageCount() async =>
      remote.unreadMessageTotal(await _bearer());
}
