import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/messaging_remote_data_source.dart';
import '../models/messaging_dtos.dart';
import '../services/stomp_chat_service.dart';

/// Coordinates REST (authoritative) + STOMP (real-time) messaging.
///
/// Send policy: STOMP when the socket is live (server echo via
/// broadcast confirms), REST fallback when only HTTP works, throw
/// otherwise. Ack policy: STOMP when live, REST fallback, swallow
/// ack failures (fetching history advances delivery server-side
/// anyway — acks must never alarm the user).
class MessagingRepositoryImpl implements MessagingRepository {
  MessagingRepositoryImpl({
    required this.remote,
    required this.tokens,
    required this.stomp,
  });

  final MessagingRemoteDataSource remote;
  final TokenStorage tokens;
  final StompChatService stomp;

  Future<String?> _bearer() => tokens.readAccessToken();

  /// Current user id from JWT `sub` (routing/display only).
  Future<String?> _selfId() async {
    final token = await _bearer();
    if (token == null) return null;
    try {
      final payload = token.split('.')[1];
      final normalized = base64.normalize(payload);
      final map = jsonDecode(
          utf8.decode(base64Url.decode(normalized)));
      if (map is Map<String, dynamic>) {
        return (map['sub'] ?? '').toString();
      }
    } on Exception {
      // Let the backend decide; display degrades gracefully.
    }
    return null;
  }

  @override
  Future<List<Conversation>> conversations() async {
    final bearer = await _bearer();
    final list = await remote.listConversations(bearer);
    final counts = await unreadCounts().catchError((_) => <String, int>{});
    return [
      for (final c in list)
        Conversation(
          id: c.id,
          type: c.type,
          title: c.title,
          internshipId: c.internshipId,
          members: c.members,
          lastSequenceNumber: c.lastSequenceNumber,
          unreadCount: counts[c.id] ?? c.unreadCount,
        ),
    ];
  }

  @override
  Future<Map<String, int>> unreadCounts() async =>
      remote.unreadCounts(await _bearer());

  @override
  Future<Paged<ChatMessage>> history(String conversationId,
      {int? cursor, int size = 30}) async {
    final bearer = await _bearer();
    final self = await _selfId();
    return remote.messageHistory(conversationId, bearer,
        cursor: cursor, size: size, selfUserId: self);
  }

  @override
  Future<ChatMessage?> latestMessage(String conversationId) async {
    try {
      final page =
          await history(conversationId, size: 1);
      return page.items.isEmpty ? null : page.items.first;
    } on ApiException {
      return null; // preview is decoration; the list matters
    }
  }

  @override
  Future<SentMessage?> send(String conversationId, String content) async {
    final bearer = await _bearer();
    final self = await _selfId();
    if (stomp.currentState == ChatConnectionState.connected) {
      try {
        await stomp.sendMessage(conversationId, content);
        return null; // echo arrives via broadcast
      } on Exception {
        // Fall through to REST below.
      }
    }
    final msg = await remote.sendMessageRest(
        conversationId, bearer, content,
        selfUserId: self);
    return SentMessage(message: msg, channel: SendChannel.rest);
  }

  @override
  Future<ChatMessage> sendWithAttachment(
    String conversationId, {
    required String content,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    final bearer = await _bearer();
    final self = await _selfId();
    return remote.sendMessageWithAttachment(conversationId, bearer,
        content: content,
        fileName: fileName,
        contentType: contentType,
        bytes: bytes,
        onProgress: onProgress,
        selfUserId: self);
  }

  @override
  Future<void> markRead(
      String conversationId, int upToSequence) async {
    if (stomp.currentState == ChatConnectionState.connected) {
      try {
        await stomp.ackRead(conversationId, upToSequence);
        return;
      } on Exception {
        // Fall through to REST.
      }
    }
    try {
      await remote.markRead(
          conversationId, await _bearer(), upToSequence);
    } on Exception {
      // Acks are best-effort; history fetch advances watermarks anyway.
    }
  }

  @override
  Future<void> markDelivered(
      String conversationId, int upToSequence) async {
    if (stomp.currentState == ChatConnectionState.connected) {
      try {
        await stomp.ackDelivered(conversationId, upToSequence);
        return;
      } on Exception {
        // Fall through to REST.
      }
    }
    try {
      await remote.markDelivered(
          conversationId, await _bearer(), upToSequence);
    } on Exception {
      // Best-effort, see markRead.
    }
  }

  @override
  Future<Uint8List> downloadAttachment(
          String attachmentId, String fileName) async =>
      remote.downloadAttachment(attachmentId, await _bearer());

  @override
  Future<ChatMessage?> parseFrame(String body) async {
    try {
      final map = jsonDecode(body);
      if (map is! Map<String, dynamic>) return null;
      if (map['id'] == null) return null; // error frame
      return messageFromJson(map, selfUserId: await _selfId());
    } on Exception {
      return null;
    }
  }
}

/// REST-backed notification center.
class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required this.client,
    required this.tokens,
  });

  final ApiClient client;
  final TokenStorage tokens;

  Future<String?> _bearer() => tokens.readAccessToken();

  @override
  Future<Paged<NotificationItem>> list(
      {int page = 0, int size = 20, bool unreadOnly = false}) async {
    final q = pageQuery(page: page, size: size);
    if (unreadOnly) q['unreadOnly'] = 'true';
    return client.get(Endpoints.notifications,
        bearer: await _bearer(),
        query: q,
        decode: (j) =>
            Paged.fromJson(j, notificationItemFromJson));
  }

  @override
  Future<int> unreadCount() async {
    final n = await client.get(
        Endpoints.notificationsUnreadCount,
        bearer: await _bearer(),
        decode: (j) {
          if (j is Map<String, dynamic>) {
            final v = j['unreadCount'] ?? j['count'] ?? j['total'];
            if (v is num) return v.toInt();
          }
          if (j is num) return j.toInt();
          return 0;
        });
    return n;
  }

  @override
  Future<void> markRead(String id) async => client.post(
      Endpoints.notificationRead(id),
      bearer: await _bearer(),
      decode: (_) {});

  @override
  Future<void> markAllRead() async => client.post(
      Endpoints.notificationsReadAll,
      bearer: await _bearer(),
      decode: (_) {});
}
