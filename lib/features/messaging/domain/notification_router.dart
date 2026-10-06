import '../../../features/auth/domain/entities/app_user.dart';
import 'entities/notification_item.dart';

/// Where a notification can send the user, expressed in the shell's tab
/// vocabulary (0-indexed; both shells share Home/Tasks-or-Interns/Journal-or-
/// Validations/Messages/More so the same integers work for every role).
///
/// The router is a **pure function** (T01: centralized typed routing, never
/// scattered string navigation). It returns null for every notification it
/// cannot resolve safely — an unknown type, a malformed target, or an entity
/// the role has no tab for — and the screen then simply keeps the row open in
/// the center. Fail-safe by construction: no crash, no wrong destination.
class NotificationRoute {
  const NotificationRoute({required this.tab, this.hint});

  /// Shell tab index to activate (see [roleLabel] shells: 0 home, 1
  /// tasks/interns, 2 journal/validations, 3 messages).
  final int tab;

  /// Present when the destination exists but the exact entity may be gone
  /// (e.g. a deleted task): the screen opens the list, not a detail sheet,
  /// and the list renders an honest empty state if nothing is there.
  final bool? hint;

  @override
  bool operator ==(Object other) =>
      other is NotificationRoute && other.tab == tab && other.hint == hint;

  @override
  int get hashCode => Object.hash(tab, hint);
}

/// Type-first, entity-fallback deep-link resolution.
///
/// 1. A **typed** notification (V54 catalogue) routes by its type — stable
///    across refactors and immune to `relatedEntityType` gaps.
/// 2. A **legacy** row (type == unknown) falls back to the backend entity
///    vocabulary (`relatedEntityType`), exactly as the pre-T01 screen did, so
///    old rows keep their behaviour.
/// 3. Anything else → null (stay in the center).
NotificationRoute? resolveNotificationRoute(
  NotificationItem n,
  UserRole role,
) {
  switch (n.type) {
    case NotificationType.taskAssigned:
    case NotificationType.taskUpdated:
    case NotificationType.taskDeleted:
    case NotificationType.taskStatusChanged:
      return switch (role) {
        // The student lands on his task board; the supervisor on his interns
        // (the per-intern task list is reachable from there).
        UserRole.intern => const NotificationRoute(tab: 1),
        UserRole.supervisor || UserRole.adminSupervisor =>
          const NotificationRoute(tab: 1),
        UserRole.unsupported => null,
      };
    case NotificationType.documentRejected:
    case NotificationType.documentVerified:
    case NotificationType.journalEntryValidated:
      return switch (role) {
        UserRole.intern => const NotificationRoute(tab: 2),
        UserRole.supervisor || UserRole.adminSupervisor =>
          const NotificationRoute(tab: 2),
        UserRole.unsupported => null,
      };
    case NotificationType.messageReceived:
      return switch (role) {
        UserRole.intern ||
        UserRole.supervisor ||
        UserRole.adminSupervisor =>
          const NotificationRoute(tab: 3),
        UserRole.unsupported => null,
      };
    case NotificationType.internshipAssigned:
    case NotificationType.internshipStatusChanged:
    case NotificationType.internshipReportSubmitted:
    case NotificationType.welcome:
      return switch (role) {
        UserRole.intern ||
        UserRole.supervisor ||
        UserRole.adminSupervisor =>
          const NotificationRoute(tab: 0),
        UserRole.unsupported => null,
      };
    // Application/candidate/payment/certificate events are workflow facts the
    // mobile shells have no dedicated tab for: they stay in the center.
    case NotificationType.applicationSubmitted:
    case NotificationType.applicationResubmitted:
    case NotificationType.applicationAccepted:
    case NotificationType.applicationRejected:
    case NotificationType.applicationModificationRequested:
    case NotificationType.candidateValidated:
    case NotificationType.finalEvaluationRequired:
    case NotificationType.paymentApproved:
    case NotificationType.certificateAvailable:
      return null;
    case NotificationType.unknown:
      // Legacy row: resolve from the entity vocabulary, if any.
      return _routeByEntity(n.relatedEntityType, role);
  }
}

/// Pre-T01 fallback for rows without a stable type (BR-44: legacy values keep
/// working, rendered generically and routed only where the entity is unambiguous).
NotificationRoute? _routeByEntity(String? entity, UserRole role) {
  final t = (entity ?? '').toUpperCase();
  return switch (role) {
    UserRole.intern => switch (t) {
        'TASK' => const NotificationRoute(tab: 1),
        'JOURNALENTRY' || 'DELIVERABLE' => const NotificationRoute(tab: 2),
        'CONVERSATION' || 'MESSAGE' => const NotificationRoute(tab: 3),
        _ => null,
      },
    UserRole.supervisor || UserRole.adminSupervisor => switch (t) {
        'TASK' || 'JOURNALENTRY' || 'DELIVERABLE' =>
          const NotificationRoute(tab: 1),
        'CONVERSATION' || 'MESSAGE' => const NotificationRoute(tab: 3),
        'INTERNSHIP' => const NotificationRoute(tab: 0),
        _ => null,
      },
    UserRole.unsupported => null,
  };
}
