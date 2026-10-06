import 'realtime_sync.dart';
import '../../../features/messaging/domain/entities/notification_item.dart';

/// T06 task-sync trigger mapping (W10 option (a), §5 REST-authoritative).
///
/// A notification frame is a *sync trigger*, never state: task-class frames
/// invalidate the task providers so Riverpod refetches the authoritative
/// REST lists. Unknown/malformed frames map to null (badge-only refresh,
/// exactly as before). Nothing here applies payloads, so duplicates,
/// reorderings and stale frames are harmless by construction — the only
/// effect is a refetch.
///
/// Deliberately narrow: message frames keep today's behavior (badge +
/// center); conversation lists refresh through the chat layer (T07).
RealtimeCategory? taskSyncCategoryFor(NotificationItem item) {
  switch (item.type) {
    case NotificationType.taskAssigned:
    case NotificationType.taskUpdated:
    case NotificationType.taskDeleted:
    case NotificationType.taskStatusChanged:
    case NotificationType.scheduledTaskVisible:
      return RealtimeCategory.tasks;
    default:
      return null;
  }
}
