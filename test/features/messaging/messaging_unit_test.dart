import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/messaging/presentation/screens/attachment_sheet.dart'
    show ChatAttachmentRules;

ChatMessage msg(String id, int seq,
    {String status = 'SENT', String sender = 'u2'}) =>
    ChatMessage(
      id: id,
      conversationId: 'c1',
      senderId: sender,
      content: 'm$seq',
      status: messageStatusFrom(status),
      sequenceNumber: seq,
      sentAt: DateTime(2026, 9, 15, 10, seq),
    );

void main() {
  group('mergeMessages', () {
    test('orders by sequenceNumber ascending', () {
      final merged = mergeMessages([], [msg('b', 2), msg('a', 1)]);
      expect(merged.map((m) => m.sequenceNumber), [1, 2]);
    });

    test('dedupes by id, live frame wins (status updates)', () {
      final merged = mergeMessages(
        [msg('a', 1, status: 'SENT')],
        [msg('a', 1, status: 'READ')],
      );
      expect(merged, hasLength(1));
      expect(merged.single.status, MessageStatus.read);
    });

    test('cursor overlap never duplicates', () {
      final merged = mergeMessages(
        [msg('a', 1), msg('b', 2)],
        [msg('b', 2), msg('c', 3)],
      );
      expect(merged.map((m) => m.sequenceNumber), [1, 2, 3]);
    });

    test('caps the in-memory window keeping the newest', () {
      final current = [
        for (var i = 1; i <= 10; i++) msg('m$i', i),
      ];
      final merged =
          mergeMessages(current, [msg('m11', 11)], cap: 5);
      expect(merged.map((m) => m.sequenceNumber),
          [7, 8, 9, 10, 11]);
    });

    test('deleted messages keep their slot', () {
      final merged = mergeMessages([], [msg('a', 1, status: 'DELETED')]);
      expect(merged.single.isDeleted, isTrue);
    });
  });

  group('message enums', () {
    test('unknown statuses fall back to sent, never throw', () {
      expect(messageStatusFrom('SENT'), MessageStatus.sent);
      expect(messageStatusFrom('DELIVERED'), MessageStatus.delivered);
      expect(messageStatusFrom('READ'), MessageStatus.read);
      expect(messageStatusFrom('EDITED'), MessageStatus.edited);
      expect(messageStatusFrom('DELETED'), MessageStatus.deleted);
      expect(messageStatusFrom('FUTURE'), MessageStatus.sent);
      expect(messageStatusFrom(null), MessageStatus.sent);
    });

    test('unknown conversation types fall back to group', () {
      expect(conversationTypeFrom('PRIVATE'),
          ConversationType.private);
      expect(
          conversationTypeFrom('GROUP'), ConversationType.group);
      expect(conversationTypeFrom(null), ConversationType.group);
    });
  });

  group('ChatAttachmentRules (contract: PDF/JPEG/PNG, 10 MB)', () {
    test('accepts the three backend types within limit', () {
      expect(ChatAttachmentRules.check('a.pdf', 100), isNull);
      expect(ChatAttachmentRules.check('a.JPG', 100), isNull);
      expect(ChatAttachmentRules.check('a.jpeg', 100), isNull);
      expect(ChatAttachmentRules.check('a.png', 10 * 1024 * 1024),
          isNull);
    });

    test('rejects other types and oversize', () {
      expect(ChatAttachmentRules.check('a.mp4', 100), 'type');
      expect(ChatAttachmentRules.check('a.docx', 100), 'type');
      expect(ChatAttachmentRules.check('a.pdf', 10 * 1024 * 1024 + 1),
          'size');
      expect(ChatAttachmentRules.check('a.pdf', 0), 'empty');
    });
  });

  group('displayContent redaction', () {
    test('deleted messages show the redacted label', () {
      final m = msg('a', 1, status: 'DELETED');
      expect(m.displayContent('gone'), 'gone');
      expect(msg('b', 2).displayContent('gone'), 'm2');
    });
  });
}
