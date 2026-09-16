import '../../../../core/network/paged.dart';
import '../entities/notification_item.dart';

/// In-app notification center contract (workflow events).
/// Push delivery is unavailable (backend sender is a no-op stub and no
/// provider credentials are configured): the app refreshes foreground
/// state via socket payloads, resume, and pull-to-refresh instead.
abstract class NotificationRepository {
  Future<Paged<NotificationItem>> list(
      {int page = 0, int size = 20, bool unreadOnly = false});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}
