import 'package:equatable/equatable.dart';

/// Stable notification catalogue keys (D11/BR-44) — the mobile mirror of the
/// backend `notifications.type` column (V54) exposed through
/// `NotificationResponse.type` and `NotificationPayload.type`.
///
/// Parsing is tolerant by contract: an unknown value from a newer backend, an
/// empty string or a legacy (absent) type maps to [unknown] and renders
/// generically — never throws, never guesses a wrong icon.
enum NotificationType {
  taskAssigned,
  taskUpdated,
  taskDeleted,
  taskStatusChanged,
  // T04/D8: a scheduled task became visible to the student.
  scheduledTaskVisible,
  documentRejected,
  documentVerified,
  applicationSubmitted,
  applicationResubmitted,
  applicationAccepted,
  applicationRejected,
  applicationModificationRequested,
  candidateValidated,
  internshipAssigned,
  internshipStatusChanged,
  internshipReportSubmitted,
  journalEntryValidated,
  finalEvaluationRequired,
  paymentApproved,
  certificateAvailable,
  messageReceived,
  welcome,
  // T08/D7: community comment on your post / moderator removals.
  communityComment,
  communityPostRemoved,
  communityCommentRemoved,
  // T14/D14: a supervisor asks his student to prepare validation documents.
  documentsPreparationRequested,
  unknown;

  /// Tolerant parse of the backend wire value: null/empty/unknown → [unknown].
  ///
  /// The backend serializes the enum name (`TASK_ASSIGNED`, ...) while Dart
  /// convention is camelCase, so the comparison normalizes both sides
  /// (separators removed, lower-cased). A newer backend value that this app
  /// does not know yet degrades to [unknown] — never throws, never guesses.
  static NotificationType fromWire(String? raw) {
    final key = _normalize(raw);
    if (key.isEmpty) return unknown;
    for (final v in NotificationType.values) {
      if (v != unknown && _normalize(v.name) == key) return v;
    }
    return unknown;
  }

  /// `TASK_STATUS_CHANGED` / `task-status-changed` / `taskStatusChanged` all
  /// collapse to `taskstatuschanged`.
  static String _normalize(String? raw) =>
      (raw ?? '').replaceAll('_', '').replaceAll('-', '').toLowerCase();
}

/// Workflow-event notification (in-app center). Push delivery is a
/// backend no-op stub + no mobile provider credentials, so the app
/// refreshes foreground state (socket payloads, resume, pull) instead —
/// see `docs/DECISIONS.md` §13.
///
/// Wire shape (backend `NotificationResponse` / `NotificationPayload`):
/// `{id, type?, title, message, priority, relatedEntityType?,
///   relatedEntityId?, createdAt, read?, readAt?}`. Every optional field is
/// parsed tolerantly so a malformed/legacy row degrades instead of crashing.
class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.createdAt,
    required this.isRead,
    this.type = NotificationType.unknown,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  final String id;
  final String title;
  final String message;
  final String priority;
  final DateTime createdAt;
  final bool isRead;

  /// Stable catalogue key (D11); [NotificationType.unknown] for legacy rows.
  final NotificationType type;

  /// Backend entity vocabulary (NotificationEventListener): Internship,
  /// InternshipApplication, ApplicationDocument, Task, JournalEntry,
  /// FinanceCase, Certificate, Conversation...
  final String? relatedEntityType;
  final String? relatedEntityId;

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        title: title,
        message: message,
        priority: priority,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        type: type,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
      );

  @override
  List<Object?> get props => [
        id,
        title,
        message,
        priority,
        createdAt,
        isRead,
        type,
        relatedEntityType,
        relatedEntityId,
      ];
}

/// Tolerant REST decode: never throws on a missing/absent field. A row whose
/// `id` is missing is still parseable — the caller decides whether to render
/// it (the repository filters id-less rows because they cannot be marked read
/// or deduped safely).
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
    type: NotificationType.fromWire((json['type'] ?? '').toString()),
    title: (json['title'] ?? '').toString(),
    message: (json['message'] ?? '').toString(),
    priority: (json['priority'] ?? 'NORMAL').toString(),
    createdAt: when,
    isRead: json['read'] == true,
    relatedEntityType: json['relatedEntityType'] as String?,
    relatedEntityId: json['relatedEntityId']?.toString(),
  );
}

/// Tolerant live-frame decode (`NotificationPayload` over
/// `/user/queue/notifications`). Returns null for frames that cannot be
/// identified (no id) — the caller keeps its REST state, never a phantom row.
NotificationItem? notificationItemFromPayloadJson(Map<String, dynamic> json) {
  final id = json['notificationId'] ?? json['id'];
  if (id == null || id.toString().isEmpty) return null;
  DateTime when;
  final raw = json['createdAt'];
  if (raw is String && raw.isNotEmpty) {
    when = DateTime.tryParse(raw) ?? DateTime.now();
  } else {
    when = DateTime.now();
  }
  return NotificationItem(
    id: id.toString(),
    type: NotificationType.fromWire((json['type'] ?? '').toString()),
    title: (json['title'] ?? '').toString(),
    message: (json['message'] ?? '').toString(),
    priority: (json['priority'] ?? 'NORMAL').toString(),
    createdAt: when,
    // A live frame says nothing about read state — the REST read model is
    // authoritative; new rows are unread until proven otherwise.
    isRead: false,
    relatedEntityType: json['relatedEntityType'] as String?,
    relatedEntityId: json['relatedEntityId']?.toString(),
  );
}

/// Live-frame reducer (BR-42 + realtime.md): dedupe by id, keep the newest
/// first by `createdAt` then id (a stable total order prevents flip-flopping
/// when two frames carry identical timestamps), and never let a frame mark a
/// REST-known read row unread again.
List<NotificationItem> mergeNotificationFrame(
  List<NotificationItem> existing,
  NotificationItem frame,
) {
  if (existing.any((n) => n.id == frame.id)) return existing;
  final merged = [...existing, frame];
  merged.sort((a, b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
  return merged;
}
