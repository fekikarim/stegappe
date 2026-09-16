import 'package:equatable/equatable.dart';

/// Workflow-event notification (in-app center). Push delivery is a
/// backend no-op stub + no mobile provider credentials, so the app
/// refreshes foreground state (socket payloads, resume, pull) instead —
/// see `docs/DECISIONS.md` §13 and the explicit TODO there.
class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final String priority;
  final DateTime createdAt;
  final bool isRead;

  @override
  List<Object?> get props =>
      [id, title, message, priority, createdAt, isRead];
}

NotificationItem notificationItemFromJson(Map<String, dynamic> json) {
  DateTime when;
  final raw = json['createdAt'];
  if (raw is String && raw.isNotEmpty) {
    when = DateTime.tryParse(raw) ?? DateTime.now();
  } else {
    when = DateTime.now();
  }
  return NotificationItem(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    message: (json['message'] ?? '').toString(),
    priority: (json['priority'] ?? 'NORMAL').toString(),
    createdAt: when,
    isRead: json['read'] == true,
  );
}
