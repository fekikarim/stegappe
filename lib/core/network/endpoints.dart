// Endpoint path constants mirroring the backend OpenAPI contract
// (`steg-backend/docs/openapi.json`). Single place to update when the
// frozen contract evolves. No feature code should hard-code paths.
abstract final class Endpoints {
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String logoutAll = '/api/auth/logout-all';
  static const String changePassword = '/api/auth/change-password';

  static const String candidateMe = '/api/candidates/me';
  static const String internships = '/api/internships';
  static String internship(String id) => '/api/internships/$id';
  // T14/D14: supervisor asks his own students to prepare documents.
  static const String notifyDocumentPreparation =
      '/api/supervision/document-preparation';
  // T14: server-persisted locale preference (best-effort sync).
  static const String userLocale = '/api/users/me/locale';
  // T13/B13: one-call student home snapshot (same sections as the lists).
  static String internshipSummary(String id) =>
      '/api/internships/$id/summary';
  static const String internshipMine = '/api/internships/mine';
  // T12/B2: own-scope supervised list with server counts (D1b: own students
  // even for an ADMIN caller — never the global list).
  static const String supervisedInternships = '/api/internships/supervised';
  static String internshipTasks(String id) => '/api/internships/$id/tasks';
  static String journalEntries(String id) =>
      '/api/internships/$id/journal/entries';
  // --- T09/B5+B6 journal document (server window + AI PDF generation) ---
  static String journalEligibility(String id) =>
      '/api/internships/$id/journal-eligibility';
  static String journalGenerate(String id) =>
      '/api/internships/$id/journal/generate';
  static String journalGenerateFromText(String id) =>
      '/api/internships/$id/journal/generate-from-text';
  static String deliverables(String id) => '/api/internships/$id/deliverables';
  static String evaluations(String id) => '/api/internships/$id/evaluations';
  // --- T03 student task classification (student-defined categories) ---
  // Note: the old `classification(id)` helper (GET .../classification, the
  // internship-type explanation) was dead — no call site — and is deleted.
  // The paths below serve the student's private categories (intern only).
  static String taskCategories(String internshipId) =>
      '/api/internships/$internshipId/task-categories';
  static String taskCategory(String categoryId) =>
      '/api/internships/task-categories/$categoryId';
  static const String taskCategoriesOrder =
      '/api/internships/task-categories/order';
  static String taskCategoryAssign(String taskId) =>
      '/api/internships/tasks/$taskId/category';
  static String taskCategoriesSuggest(String internshipId) =>
      '/api/internships/$internshipId/task-categories/suggest';
  static String taskCategoriesApply(String internshipId) =>
      '/api/internships/$internshipId/task-categories/apply';
  static String taskCategoryUndo(String batchId) =>
      '/api/internships/task-categories/apply-batches/$batchId/undo';
  static String assignments(String id) => '/api/internships/$id/assignments';
  static String task(String taskId) => '/api/internships/tasks/$taskId';
  static String taskStatus(String taskId) =>
      '/api/internships/tasks/$taskId/status';
  // --- T04 supervisor review + bulk (staff, scoped server-side) ---
  static String taskReview(String taskId) =>
      '/api/internships/tasks/$taskId/review';
  static const String tasksBulk = '/api/internships/tasks/bulk';
  // --- T05 supervisor AI task drafts (staff, scoped server-side) ---
  static const String taskDraftsGenerate = '/api/internships/tasks/drafts/generate';
  static const String taskDraftsGenerateFromText =
      '/api/internships/tasks/drafts/generate-from-text';
  static const String taskDrafts = '/api/internships/tasks/drafts';
  static String taskDraft(String id) =>
      '/api/internships/tasks/drafts/$id';
  static String taskDraftRevise(String id) =>
      '/api/internships/tasks/drafts/$id/revise';
  static const String taskDraftsBulkAdd =
      '/api/internships/tasks/drafts/bulk-add';
  static String journalSubmit(String entryId) =>
      '/api/internships/journal/entries/$entryId/submit';
  static String journalValidate(String entryId) =>
      '/api/internships/journal/entries/$entryId/validate';
  static String journalReject(String entryId) =>
      '/api/internships/journal/entries/$entryId/reject';
  static String journalComments(String entryId) =>
      '/api/journal/entries/$entryId/comments';
  static String deliverable(String id) => '/api/internships/deliverables/$id';
  static String deliverableVersions(String id) =>
      '/api/internships/deliverables/$id/versions';
  static String deliverableSubmit(String id) =>
      '/api/internships/deliverables/$id/submit';
  // --- T10 B7/B8: final-week submission window + explicit document kind ---
  static String submissionWindow(String id) =>
      '/api/internships/$id/submission-window';
  static String deliverableDocumentKind(String id) =>
      '/api/internships/deliverables/$id/document-kind';
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
  static String conversationRead(String id) => '/api/conversations/$id/read';
  static String conversationDelivered(String id) =>
      '/api/conversations/$id/delivered';
  static String attachmentDownload(String attachmentId) =>
      '/api/conversations/attachments/$attachmentId/download';
  static const String notifications = '/api/notifications';
  static const String notificationsReadAll = '/api/notifications/read-all';
  static const String notificationsUnreadCount =
      '/api/notifications/unread-count';
  static String notificationRead(String id) => '/api/notifications/$id/read';
  // --- T08 student community (ST-COM-01/02, D7) ---
  static const String communityPosts = '/api/community/posts';
  static const String communityPostsWithAttachment =
      '/api/community/posts/with-attachment';
  static String communityPost(String id) => '/api/community/posts/$id';
  static String communityPostComments(String id) =>
      '/api/community/posts/$id/comments';
  static String communityComment(String id) =>
      '/api/community/comments/$id';
  static const String communityReports = '/api/community/reports';
  static const String communityModerationReports =
      '/api/community/moderation/reports';
  static String communityModerationReportResolve(String id) =>
      '/api/community/moderation/reports/$id/resolve';
  static const String communityModerationMutes =
      '/api/community/moderation/mutes';
  static String communityModerationMute(String userId) =>
      '/api/community/moderation/mutes/$userId';
  static String communityAttachmentDownload(String attachmentId) =>
      '/api/community/posts/attachments/$attachmentId/download';
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
