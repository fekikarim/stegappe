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
  static String internshipTasks(String id) => '/api/internships/$id/tasks';
  static String journalEntries(String id) =>
      '/api/internships/$id/journal/entries';
  static String deliverables(String id) =>
      '/api/internships/$id/deliverables';
  static String evaluations(String id) =>
      '/api/internships/$id/evaluations';
  static const String conversations = '/api/conversations';
  static const String notifications = '/api/notifications';
}
