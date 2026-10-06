import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/domain/notification_router.dart';

/// A row shaped like the backend wire payload.
NotificationItem row(
  NotificationType type, {
  String? entity,
  String? entityId,
}) =>
    NotificationItem(
      id: 'n-${type.name}',
      title: 'titre',
      message: 'message',
      priority: 'NORMAL',
      createdAt: DateTime(2026, 9, 15, 10),
      isRead: false,
      type: type,
      relatedEntityType: entity,
      relatedEntityId: entityId,
    );

const intern = UserRole.intern;
const supervisor = UserRole.supervisor;
const adminSupervisor = UserRole.adminSupervisor;
const unsupported = UserRole.unsupported;

void main() {
  group('typed destinations (D11)', () {
    test('the five required student types all resolve (ST-NOT-01)', () {
      // New task · task edited · task deleted · approved documents · welcome.
      const required = [
        NotificationType.taskAssigned,
        NotificationType.taskUpdated,
        NotificationType.taskDeleted,
        NotificationType.documentVerified,
        NotificationType.welcome,
      ];
      for (final type in required) {
        expect(resolveNotificationRoute(row(type), intern), isNotNull,
            reason: '$type must deep-link for the student');
      }
    });

    test('the task family lands on the task board', () {
      const tasks = [
        NotificationType.taskAssigned,
        NotificationType.taskUpdated,
        NotificationType.taskDeleted,
        NotificationType.taskStatusChanged,
      ];
      for (final type in tasks) {
        expect(
          resolveNotificationRoute(row(type), intern),
          const NotificationRoute(tab: 1),
        );
        expect(
          resolveNotificationRoute(row(type), supervisor),
          const NotificationRoute(tab: 1),
        );
      }
    });

    test('documents and journal reach the follow-up tab', () {
      for (final type in [
        NotificationType.documentRejected,
        NotificationType.documentVerified,
        NotificationType.journalEntryValidated,
      ]) {
        expect(
          resolveNotificationRoute(row(type), intern),
          const NotificationRoute(tab: 2),
        );
      }
    });

    test('messages open the conversation list', () {
      expect(
        resolveNotificationRoute(
            row(NotificationType.messageReceived), supervisor),
        const NotificationRoute(tab: 3),
      );
    });

    test('internship lifecycle and the welcome message go home', () {
      for (final type in [
        NotificationType.internshipAssigned,
        NotificationType.internshipStatusChanged,
        NotificationType.internshipReportSubmitted,
        NotificationType.welcome,
      ]) {
        expect(
          resolveNotificationRoute(row(type), intern),
          const NotificationRoute(tab: 0),
        );
      }
    });

    test('workflow facts without a mobile tab stay in the center', () {
      // No shell tab exists for them: the honest destination is "no route".
      for (final type in [
        NotificationType.applicationSubmitted,
        NotificationType.applicationResubmitted,
        NotificationType.applicationAccepted,
        NotificationType.applicationRejected,
        NotificationType.applicationModificationRequested,
        NotificationType.candidateValidated,
        NotificationType.finalEvaluationRequired,
        NotificationType.paymentApproved,
        NotificationType.certificateAvailable,
        // T08 community rows have no tab either: the center pushes the
        // post detail through onOpenCommunityPost instead (see
        // NotificationsScreen), so the tab router stays silent.
        NotificationType.communityComment,
        NotificationType.communityPostRemoved,
        NotificationType.communityCommentRemoved,
      ]) {
        expect(resolveNotificationRoute(row(type), intern), isNull,
            reason: '$type must not fake a destination');
      }
    });

    test('the type wins over a misleading related entity', () {
      // A typed welcome row that carries a Task entity still goes home: the
      // catalogue key is the contract, the entity string is only a fallback.
      expect(
        resolveNotificationRoute(
            row(NotificationType.welcome, entity: 'Task'), intern),
        const NotificationRoute(tab: 0),
      );
    });

    test('a role without a shell never routes', () {
      for (final type in NotificationType.values) {
        expect(resolveNotificationRoute(row(type, entity: 'TASK'), unsupported),
            isNull);
      }
    });

    test('supervisors and admin-supervisors share one destination map', () {
      for (final type in NotificationType.values) {
        expect(
          resolveNotificationRoute(row(type, entity: 'TASK'), adminSupervisor),
          resolveNotificationRoute(row(type, entity: 'TASK'), supervisor),
        );
      }
    });
  });

  group('legacy rows and malformed data', () {
    test('an unknown type falls back to the backend entity vocabulary', () {
      expect(
        resolveNotificationRoute(
            row(NotificationType.unknown, entity: 'TASK'), intern),
        const NotificationRoute(tab: 1),
      );
      expect(
        resolveNotificationRoute(
            row(NotificationType.unknown, entity: 'journalentry'), intern),
        const NotificationRoute(tab: 2),
      );
      expect(
        resolveNotificationRoute(
            row(NotificationType.unknown, entity: 'Conversation'), intern),
        const NotificationRoute(tab: 3),
      );
    });

    test('an unknown type with an unknown entity stays in the center', () {
      expect(resolveNotificationRoute(row(NotificationType.unknown), intern),
          isNull);
      expect(
        resolveNotificationRoute(
            row(NotificationType.unknown, entity: 'SOMETHING_NEW'), intern),
        isNull,
      );
      expect(
        resolveNotificationRoute(
            row(NotificationType.unknown, entity: ''), intern),
        isNull,
      );
    });

    test('an internship entity only routes for staff roles', () {
      expect(
        resolveNotificationRoute(
            row(NotificationType.unknown, entity: 'INTERNSHIP'), supervisor),
        const NotificationRoute(tab: 0),
      );
      expect(
        resolveNotificationRoute(
            row(NotificationType.unknown, entity: 'INTERNSHIP'), intern),
        isNull,
      );
    });

    test('equality is by value so a route can be compared in tests and keys',
        () {
      expect(const NotificationRoute(tab: 1),
          const NotificationRoute(tab: 1));
      expect(const NotificationRoute(tab: 1).hashCode,
          const NotificationRoute(tab: 1).hashCode);
      expect(const NotificationRoute(tab: 1),
          isNot(const NotificationRoute(tab: 2)));
      expect(const NotificationRoute(tab: 1, hint: true),
          isNot(const NotificationRoute(tab: 1)));
    });
  });
}
