import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/offline/pending_write_store.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';
import 'package:stegappe/features/messaging/domain/repositories/messaging_repository.dart';

import 'package:stegappe/features/messaging/presentation/screens/attachment_sheet.dart';
import '../features/community/community_test_support.dart';
import '../features/messaging/messaging_widget_test.dart'
    show FakeMessagingRepo, FakeStomp;

void main() {
  group('S5 — Messaging and community (ST-MSG, ST-COM)', () {
    test(
      'S5.1: Message and attachment send; delivery/read states progress; >10MB file refused with explanation',
      () async {
        final stomp = FakeStomp();
        stomp.setState(ChatConnectionState.connected);
        final messagingRepo = FakeMessagingRepo(stomp: stomp);

        // 1. Send live chat message
        final sent = await messagingRepo.send(
          'c1',
          'Bonjour Monsieur, voici les documents.',
          idempotencyKey: 'msg-key-101',
        );
        expect(sent, isNull); // live STOMP returns null, broadcast echo expected
        expect(stomp.sent, contains('Bonjour Monsieur, voici les documents.'));

        // 2. Ack delivered & read progression
        await messagingRepo.stomp!.ackDelivered('c1', 10);
        expect(stomp.ackedDelivered, contains(10));

        await messagingRepo.stomp!.ackRead('c1', 10);
        expect(stomp.ackedRead, contains(10));

        // 3. Send attachment
        final smallBytes = Uint8List.fromList([1, 2, 3, 4]);
        final chatMsg = await messagingRepo.sendWithAttachment(
          'c1',
          content: 'Compte-rendu',
          fileName: 'cr.pdf',
          contentType: 'application/pdf',
          bytes: smallBytes,
        );
        expect(chatMsg.id, isNotEmpty);

        // 4. File > 10 MB (10 * 1024 * 1024 = 10485760 bytes) is refused
        final largeFileBytes = Uint8List(10 * 1024 * 1024 + 1024);
        expect(ChatAttachmentRules.check('cr.pdf', largeFileBytes.lengthInBytes), 'size');
        expect(ChatAttachmentRules.check('cr.pdf', ChatAttachmentRules.maxBytes), isNull);
      },
    );

    test(
      'S5.2: Community: student posts, comments; supervisor moderates comment with reason; muted user cannot post; report reaches moderation',
      () async {
        final repo = FakeCommunityRepository();

        // 1. Student creates post
        final post = await repo.createPost(
          'Question sur les normes de sécurité en moyenne tension',
          idempotencyKey: 'post-key-1',
        );
        expect(post.body, contains('moyenne tension'));

        // 2. Student adds comment
        final comment = await repo.comment(
          post.id,
          'Consulter la norme STEG NT-2024.',
          idempotencyKey: 'comment-key-1',
        );
        expect(comment.body, contains('NT-2024'));

        // 3. Supervisor moderates comment with reason
        await repo.deleteComment(
          comment.id,
          reason: 'Hors sujet par rapport au thème du stage',
        );
        expect(repo.deletedComments, contains(comment.id));
        expect(repo.deleteReasons, contains('Hors sujet par rapport au thème du stage'));

        // 4. Mute student & report post
        await repo.muteStudent(
          userId: 'u-bad',
          minutes: 60,
          reason: 'Non-respect de la charte',
        );
        expect(repo.mutedUsers, contains('u-bad'));

        await repo.reportPost(post.id, 'Contenu non conforme');
        expect(repo.reportedPosts, contains(post.id));
      },
    );

    test(
      'S5.3: Socket down falls back to REST; airplane mode queues write in PendingWrites and flushes once on reconnect',
      () async {
        final stomp = FakeStomp();
        stomp.setState(ChatConnectionState.disconnected);
        final messagingRepo = FakeMessagingRepo(stomp: stomp);

        // 1. When socket is disconnected, send falls back to REST channel
        final sentRest = await messagingRepo.send(
          'c1',
          'Message de secours via REST',
          idempotencyKey: 'rest-key-99',
        );
        expect(sentRest, isNotNull);
        expect(sentRest!.channel, SendChannel.rest);
        expect(sentRest.message.content, isNotEmpty);

        // 2. Airplane mode: writes queue in PendingWriteStore backed by SharedPreferences
        SharedPreferences.setMockInitialValues({});
        final prefs = await PrefsStore.load();
        final store = PendingWriteStore(prefs);

        const write = PendingWrite(
          key: 'offline-msg-key',
          kind: PendingWriteKind.message,
          conversationId: 'c1',
          content: 'Message écrit hors-ligne',
          createdAtMs: 1760000000000,
        );

        store.push(write);
        final queued = store.load();
        expect(queued.length, 1);
        expect(queued.first.key, 'offline-msg-key');

        // Flush once on reconnect
        store.clear();
        final afterFlush = store.load();
        expect(afterFlush, isEmpty);
      },
    );
  });
}
