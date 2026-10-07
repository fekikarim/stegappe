import 'realtime_sync.dart';
import '../../../features/messaging/domain/entities/notification_item.dart';

/// T09 journal-sync trigger mapping (same posture as `task_sync.dart` and
/// `community_sync.dart`).
///
/// A notification frame is a *sync trigger*, never state: journal-class
/// frames invalidate the document providers (`journalListProvider`,
/// `pendingValidationsProvider`, `dashboardProvider` via
/// `RealtimeCategory.documents`) so Riverpod refetches the authoritative
/// REST lists. Unknown/malformed frames map to null (badge-only refresh,
/// exactly as before). Nothing here applies payloads, so duplicates,
/// reorderings and stale frames are harmless by construction.
///
/// Deliberately narrow: `journalEntryValidated` (the one journal event the
/// backend emits) and `documentRejected` (Admin validation rejections since
/// T01, supervisor first-level rejections since T10) map today. There is no
/// submit notification and no document topic; the queues stay correct over
/// REST + resume + pull-to-refresh.
RealtimeCategory? documentSyncCategoryFor(NotificationItem item) {
  switch (item.type) {
    case NotificationType.journalEntryValidated:
    case NotificationType.documentRejected:
      return RealtimeCategory.documents;
    default:
      return null;
  }
}
