import 'dart:typed_data';

import '../../../../core/network/paged.dart';
import '../entities/conversation.dart';

/// How a message left the device (honest send-state UX).
enum SendChannel { stomp, rest }

class SentMessage {
  const SentMessage({required this.message, required this.channel});

  final ChatMessage message;
  final SendChannel channel;
}

/// Messaging contract. Server-side membership stays authoritative:
/// every call may 403/404, which the UI surfaces instead of guessing.
/// Client-side state (merge, watermarks) is convenience + offline
/// honesty only.
abstract class MessagingRepository {
  Future<List<Conversation>> conversations();
  Future<Map<String, int>> unreadCounts();

  /// Newest-first page; `cursor` = inclusive upper sequence bound
  /// (verified live). Callers merge ascending by sequenceNumber.
  Future<Paged<ChatMessage>> history(String conversationId,
      {int? cursor, int size = 30});

  /// Latest single message for list previews.
  Future<ChatMessage?> latestMessage(String conversationId);

  /// Send: STOMP when the socket is live (echo arrives via broadcast),
  /// REST fallback when only HTTP is available. Throws when neither
  /// works — the UI shows failed + retry, never fake success.
  /// Returns null when sent over STOMP (echo pending via subscription).
  ///
  /// T07/BR-56: [idempotencyKey] identifies one logical message. The REST
  /// fallback forwards it as `X-Idempotency-Key` so a retry after a
  /// successful server write replays instead of duplicating. Callers reuse
  /// the same key for the offline-queue row of that message.
  Future<SentMessage?> send(String conversationId, String content,
      {String? idempotencyKey});

  /// REST-only send with an idempotency key (T06 offline-queue flush:
  /// retries of the same logical message replay instead of duplicating).
  Future<ChatMessage> sendRest(String conversationId, String content,
      {String? idempotencyKey});

  Future<ChatMessage> sendWithAttachment(
    String conversationId, {
    required String content,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  });

  Future<void> markRead(String conversationId, int upToSequence);
  Future<void> markDelivered(String conversationId, int upToSequence);

  Future<Uint8List> downloadAttachment(
      String attachmentId, String fileName);

  /// Parse a STOMP broadcast frame into a message (null when the frame
  /// is an error payload or malformed — never throws).
  Future<ChatMessage?> parseFrame(String body);
}
