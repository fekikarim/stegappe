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
/// Deliberately narrow: only `journalEntryValidated` maps today — the one
/// journal event the backend emits (`CompanionService.validateJournalEntry`
/// → `JournalEntryValidatedEvent`). There is no submit/reject notification
/// and no journal topic; the queues stay correct over REST + resume +
/// pull-to-refresh.
RealtimeCategory? documentSyncCategoryFor(NotificationItem item) {
  switch (item.type) {
    case NotificationType.journalEntryValidated:
      return RealtimeCategory.documents;
    default:
      return null;
  }
}
