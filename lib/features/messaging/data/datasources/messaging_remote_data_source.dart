import 'dart:typed_data';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/paged.dart';import '../../domain/entities/conversation.dart';
import '../models/messaging_dtos.dart';

/// Thin HTTP wrapper for messaging + notifications.
/// Real-time frames go through [StompChatService]; every read/write here
/// is the authoritative fallback and the resync path.
class MessagingRemoteDataSource {
  MessagingRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<Conversation>> listConversations(String? bearer) =>
      _client.get(Endpoints.conversations,
          bearer: bearer,
          // Reconnect storms hit this first; bounded retry smooths them.
          retry: const ReadRetryPolicy(),
          decode: (j) => [
                if (j is List)
                  for (final e in j)
                    if (e is Map<String, dynamic>)
                      conversationFromJson(e),
              ]);

  Future<Conversation> getConversation(String id, String? bearer) =>
      _client.get(Endpoints.conversation(id),
          bearer: bearer,
          decode: (j) =>
              conversationFromJson(_map(j)));

  /// Cursor history, newest-first page from the backend; callers merge by
  /// sequenceNumber. `cursor` = exclusive upper bound (older than).
  Future<Paged<ChatMessage>> messageHistory(
    String conversationId,
    String? bearer, {
    int? cursor,
    int size = 30,
    String? selfUserId,
  }) {
    final q = pageQuery(page: 0, size: size);
    if (cursor != null) q['cursor'] = '$cursor';
    return _client.get(
        Endpoints.conversationMessages(conversationId),
        bearer: bearer,
        query: q,
        retry: const ReadRetryPolicy(),
        decode: (j) => Paged.fromJson(
            j, (m) => messageFromJson(m, selfUserId: selfUserId)));
  }

  Future<ChatMessage> sendMessageRest(
    String conversationId,
    String? bearer,
    String content, {
    String? selfUserId,
  }) =>
      _client.post(Endpoints.conversationMessages(conversationId),
          bearer: bearer,
          body: {'content': content},
          decode: (j) =>
              messageFromJson(_map(j), selfUserId: selfUserId));

  /// Attachment send: `content` is a REQUIRED query param per contract,
  /// the file is the multipart part (PDF/JPEG/PNG, 10 MB, Tika-checked).
  Future<ChatMessage> sendMessageWithAttachment(
    String conversationId,
    String? bearer, {
    required String content,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
    String? selfUserId,
  }) =>
      _client.uploadMultipart(
          '${Endpoints.conversationMessagesWithAttachment(conversationId)}'
          '?content=${Uri.encodeQueryComponent(content)}',
          bearer: bearer,
          fileField: 'file',
          fileName: fileName,
          contentType: contentType,
          bytes: bytes,
          onProgress: onProgress,
          decode: (j) =>
              messageFromJson(_map(j), selfUserId: selfUserId));

  Future<void> markRead(
          String conversationId, String? bearer, int upToSequence) =>
      _client.post(Endpoints.conversationRead(conversationId),
          bearer: bearer,
          body: {'upToSequenceNumber': upToSequence},
          decode: (_) {});

  Future<void> markDelivered(
          String conversationId, String? bearer, int upToSequence) =>
      _client.post(Endpoints.conversationDelivered(conversationId),
          bearer: bearer,
          body: {'upToSequenceNumber': upToSequence},
          decode: (_) {});

  Future<Map<String, int>> unreadCounts(String? bearer) =>
      _client.get(Endpoints.unreadCounts,
          bearer: bearer,
          decode: (j) {
            final out = <String, int>{};
            if (j is List) {
              for (final e in j) {
                if (e is Map<String, dynamic>) {
                  final id = (e['conversationId'] ?? '').toString();
                  if (id.isNotEmpty) {
                    out[id] =
                        (e['unreadCount'] as num?)?.toInt() ?? 0;
                  }
                }
              }
            }
            return out;
          });

  Future<Uint8List> downloadAttachment(
          String attachmentId, String? bearer) =>
      _client.downloadBytes(Endpoints.attachmentDownload(attachmentId),
          bearer: bearer);

  static Map<String, dynamic> _map(dynamic j) =>
      j is Map<String, dynamic> ? j : <String, dynamic>{};
}
