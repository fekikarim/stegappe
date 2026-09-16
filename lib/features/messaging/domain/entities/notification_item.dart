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
    this.relatedEntityType,
    this.relatedEntityId,
  });

  final String id;
  final String title;
  final String message;
  final String priority;
  final DateTime createdAt;
  final bool isRead;

  /// Backend event vocabulary (NotificationEventListener): Internship,
  /// InternshipApplication, ApplicationDocument, Task, JournalEntry,
  /// FinanceCase, Certificate, Conversation, Message...
  final String? relatedEntityType;
  final String? relatedEntityId;

  @override
  List<Object?> get props => [
        id,
        title,
        message,
        priority,
        createdAt,
        isRead,
        relatedEntityType,
        relatedEntityId,
      ];
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
    relatedEntityType: json['relatedEntityType'] as String?,
    relatedEntityId: json['relatedEntityId'] as String?,
  );
}
