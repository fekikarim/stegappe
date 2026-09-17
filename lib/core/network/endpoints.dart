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
  static String deliverable(String id) =>
      '/api/internships/deliverables/$id';
  static String deliverableVersions(String id) =>
      '/api/internships/deliverables/$id/versions';
  static String deliverableSubmit(String id) =>
      '/api/internships/deliverables/$id/submit';
  static String deliverableValidate(String id) =>
      '/api/internships/deliverables/$id/validate';
  static String deliverableReject(String id) =>
      '/api/internships/deliverables/$id/reject';
  static String deliverableDownload(String id) =>
      '/api/internships/deliverables/$id/download';
  static String deliverableComments(String id) =>
      '/api/deliverables/$id/comments';
  static const String evaluationTemplates = '/api/evaluation-templates';
  static String templateCriteria(String templateId) =>
      '/api/evaluation-templates/$templateId/criteria';
  static String internshipEvaluations(String internshipId) =>
      '/api/internships/$internshipId/evaluations';
  static String evaluation(String evaluationId) =>
      '/api/evaluations/$evaluationId';
  static String evaluationScores(String evaluationId) =>
      '/api/evaluations/$evaluationId/scores';
  static String evaluationTaskReviews(String evaluationId) =>
      '/api/evaluations/$evaluationId/task-reviews';
  static String evaluationComments(String evaluationId) =>
      '/api/evaluations/$evaluationId/comments';
  // --- D5 messaging & notifications ---
  static const String conversations = '/api/conversations';
  static const String unreadCounts = '/api/conversations/unread/counts';
  static String conversation(String id) => '/api/conversations/$id';
  static String conversationMessages(String id) =>
      '/api/conversations/$id/messages';
  static String conversationMessagesWithAttachment(String id) =>
      '/api/conversations/$id/messages/with-attachment';
  static String conversationRead(String id) =>
      '/api/conversations/$id/read';
  static String conversationDelivered(String id) =>
      '/api/conversations/$id/delivered';
  static String attachmentDownload(String attachmentId) =>
      '/api/conversations/attachments/$attachmentId/download';
  static const String notifications = '/api/notifications';
  static const String notificationsReadAll = '/api/notifications/read-all';
  static const String notificationsUnreadCount =
      '/api/notifications/unread-count';
  static String notificationRead(String id) =>
      '/api/notifications/$id/read';
  // --- D6 AI (advisory only; logbook is the participant endpoint) ---
  static String aiLogbook(String internshipId) =>
      '/api/ai/internships/$internshipId/logbook/generate';
  static String logbookSubmit(String internshipId) =>
      '/api/internships/$internshipId/logbook/submit';
  static String logbook(String internshipId) =>
      '/api/internships/$internshipId/logbook';
  static String logbookValidate(String internshipId, String logbookId) =>
      '/api/internships/$internshipId/logbook/$logbookId/validate';
  static String logbookReject(String internshipId, String logbookId) =>
      '/api/internships/$internshipId/logbook/$logbookId/reject';
  static String logbookOfficial(String internshipId, String logbookId) =>
      '/api/internships/$internshipId/logbook/$logbookId/official';
  // --- Intern assistant (role-scoped RAG via backend; Gemini key never on-device) ---
  static const String aiAssistant = '/api/ai/assistant/query';
}
