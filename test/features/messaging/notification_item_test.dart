import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';

/// The exact values `NotificationType` (backend) stores in
/// `notifications.type` and serializes in `NotificationResponse.type` /
/// `NotificationPayload.type`. Pinning the literal strings here is the mobile
/// half of the catalogue contract (D11): a rename on either side fails this
/// test instead of silently degrading every row to the generic rendering.
const List<String> kBackendWireValues = [
  'TASK_ASSIGNED',
  'TASK_UPDATED',
  'TASK_DELETED',
  'TASK_STATUS_CHANGED',
  // T04/D8: the scheduled-visibility producer exists server-side
  // (TaskVisibilityScheduler → SCHEDULED_TASK_VISIBLE), so the key is
  // catalogue, not invented.
  'SCHEDULED_TASK_VISIBLE',
  'DOCUMENT_REJECTED',
  'DOCUMENT_VERIFIED',
  'APPLICATION_SUBMITTED',
  'APPLICATION_RESUBMITTED',
  'APPLICATION_ACCEPTED',
  'APPLICATION_REJECTED',
  'APPLICATION_MODIFICATION_REQUESTED',
  'CANDIDATE_VALIDATED',
  'INTERNSHIP_ASSIGNED',
  'INTERNSHIP_STATUS_CHANGED',
  'INTERNSHIP_REPORT_SUBMITTED',
  'JOURNAL_ENTRY_VALIDATED',
  'FINAL_EVALUATION_REQUIRED',
  'PAYMENT_APPROVED',
  'CERTIFICATE_AVAILABLE',
  'MESSAGE_RECEIVED',
  'WELCOME',
];

String wireValueOf(NotificationType type) =>
    type.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();

void main() {
  group('catalogue contract (D11)', () {
    test('every backend wire value maps to a distinct catalogue key', () {
      final seen = <NotificationType>{};
      for (final wire in kBackendWireValues) {
        final type = NotificationType.fromWire(wire);
        expect(type, isNot(NotificationType.unknown),
            reason: '$wire must be a known catalogue key');
        seen.add(type);
      }
      expect(seen, hasLength(kBackendWireValues.length),
          reason: 'two wire values collapsed onto the same key');
    });

    test('every catalogue key serializes back to its backend wire value', () {
      final known =
          NotificationType.values.where((v) => v != NotificationType.unknown);
      expect(known, hasLength(kBackendWireValues.length));
      for (final type in known) {
        expect(NotificationType.fromWire(wireValueOf(type)), type);
        expect(kBackendWireValues, contains(wireValueOf(type)));
      }
    });

    test('legacy, empty and future wire values degrade to unknown', () {
      expect(NotificationType.fromWire(null), NotificationType.unknown);
      expect(NotificationType.fromWire(''), NotificationType.unknown);
      expect(NotificationType.fromWire('   '), NotificationType.unknown);
      expect(NotificationType.fromWire('SOMETHING_FROM_THE_FUTURE'),
          NotificationType.unknown);
    });

    test('parsing tolerates separator and case variations', () {
      expect(NotificationType.fromWire('task_assigned'),
          NotificationType.taskAssigned);
      expect(NotificationType.fromWire('taskStatusChanged'),
          NotificationType.taskStatusChanged);
      expect(NotificationType.fromWire('TASK-STATUS-CHANGED'),
          NotificationType.taskStatusChanged);
    });
  });

  group('tolerant wire parsing', () {
    test('a REST row with missing fields still parses', () {
      final item = notificationItemFromJson({'id': 'n1', 'title': 'Titre'});
      expect(item.id, 'n1');
      expect(item.title, 'Titre');
      expect(item.message, '');
      expect(item.priority, 'NORMAL');
      expect(item.isRead, isFalse);
      expect(item.type, NotificationType.unknown);
      expect(item.relatedEntityType, isNull);
      expect(item.relatedEntityId, isNull);
    });

    test('a REST row maps the typed catalogue and the read flag', () {
      final item = notificationItemFromJson({
        'id': 'n2',
        'type': 'DOCUMENT_REJECTED',
        'title': 'Document refusé',
        'message': 'Motif : semaine manquante',
        'priority': 'HIGH',
        'relatedEntityType': 'ApplicationDocument',
        'relatedEntityId': 'doc-1',
        'createdAt': '2026-09-15T09:00:00Z',
        'read': true,
      });
      expect(item.type, NotificationType.documentRejected);
      expect(item.priority, 'HIGH');
      expect(item.isRead, isTrue);
      expect(item.relatedEntityType, 'ApplicationDocument');
      expect(item.relatedEntityId, 'doc-1');
      expect(item.createdAt.toUtc(), DateTime.utc(2026, 9, 15, 9));
    });

    test('a live payload is unread, needs an id and prefers notificationId',
        () {
      expect(notificationItemFromPayloadJson({'title': 'no id'}), isNull);
      expect(notificationItemFromPayloadJson({'id': ''}), isNull);
      final item = notificationItemFromPayloadJson({
        'notificationId': 'n3',
        'id': 'ignored',
        'type': 'TASK_ASSIGNED',
        'title': 'Nouvelle tâche',
        'message': 'Vous avez été assigné',
      });
      expect(item?.id, 'n3');
      expect(item?.type, NotificationType.taskAssigned);
      expect(item?.isRead, isFalse);
    });
  });

  group('merge reducer (BR-42)', () {
    NotificationItem row(String id, {required DateTime at, bool isRead = false}) =>
        NotificationItem(
          id: id,
          title: 't',
          message: 'm',
          priority: 'NORMAL',
          createdAt: at,
          isRead: isRead,
        );

    test('a duplicate id is dropped and the REST read state is preserved', () {
      final existing = [row('n1', at: DateTime(2026, 9, 15, 9), isRead: true)];
      final merged =
          mergeNotificationFrame(existing, row('n1', at: DateTime(2026, 9, 15, 9)));
      expect(merged, hasLength(1));
      expect(merged.single.isRead, isTrue,
          reason: 'a live frame must never un-read a REST-known read row');
    });

    test('new rows are ordered newest-first with a stable id tie-break', () {
      final same = DateTime(2026, 9, 15, 9);
      var items = <NotificationItem>[];
      items = mergeNotificationFrame(items, row('a', at: same));
      items = mergeNotificationFrame(items, row('b', at: same));
      items = mergeNotificationFrame(items, row('c', at: same.add(const Duration(minutes: 1))));
      expect(items.map((n) => n.id), ['c', 'b', 'a']);
    });

    test('the reducer never mutates the list it is given', () {
      final existing = [row('n1', at: DateTime(2026, 9, 15, 9))];
      final merged =
          mergeNotificationFrame(existing, row('n2', at: DateTime(2026, 9, 15, 10)));
      expect(existing, hasLength(1));
      expect(merged, hasLength(2));
    });
  });
}
