// Endpoint path constants mirroring the backend OpenAPI contract
// (`steg-backend/docs/openapi.json`). Single place to update when the
// frozen contract evolves. No feature code should hard-code paths.
abstract final class Endpoints {
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String logoutAll = '/api/auth/logout-all';

  static const String candidateMe = '/api/candidates/me';
  static const String internships = '/api/internships';
  static String internship(String id) => '/api/internships/$id';
  static String internshipTasks(String id) => '/api/internships/$id/tasks';
  static String journalEntries(String id) =>
      '/api/internships/$id/journal/entries';
  static String deliverables(String id) =>
      '/api/internships/$id/deliverables';
  static String evaluations(String id) =>
      '/api/internships/$id/evaluations';
  static String classification(String id) =>
      '/api/internships/$id/classification';
  static String assignments(String id) =>
      '/api/internships/$id/assignments';
  static String task(String taskId) => '/api/internships/tasks/$taskId';
  static String taskStatus(String taskId) =>
      '/api/internships/tasks/$taskId/status';
  static String journalSubmit(String entryId) =>
      '/api/internships/journal/entries/$entryId/submit';
  static String journalValidate(String entryId) =>
      '/api/internships/journal/entries/$entryId/validate';
  static String journalReject(String entryId) =>
      '/api/internships/journal/entries/$entryId/reject';
  static String journalComments(String entryId) =>
      '/api/journal/entries/$entryId/comments';
  static const String conversations = '/api/conversations';
  static const String unreadCounts = '/api/conversations/unread/counts';
  static const String notifications = '/api/notifications';
  static const String notificationsReadAll = '/api/notifications/read-all';
}
