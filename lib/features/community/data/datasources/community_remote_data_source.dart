import 'dart:typed_data';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/paged.dart';

Map<String, dynamic> _map(dynamic j) =>
    (j as Map?)?.cast<String, dynamic>() ?? {};

/// Thin HTTP wrapper for the student community (T08).
/// The socket only carries invalidation envelopes; every read/write here
/// is authoritative (and the resync path).
class CommunityRemoteDataSource {
  CommunityRemoteDataSource(this._client);

  final ApiClient _client;

  Future<dynamic> feedPage(
    String? bearer, {
    DateTime? cursorTs,
    String? cursorId,
    int size = 20,
  }) {
    final q = <String, String>{'size': '$size'};
    if (cursorTs != null) {
      q['cursorTs'] = cursorTs.toUtc().toIso8601String();
    }
    if (cursorId != null) q['cursorId'] = cursorId;
    return _client.get(Endpoints.communityPosts,
        bearer: bearer,
        query: q,
        retry: const ReadRetryPolicy(),
        decode: (j) => j);
  }

  Future<Map<String, dynamic>> getPost(String id, String? bearer) =>
      _client.get(Endpoints.communityPost(id),
          bearer: bearer,
          retry: const ReadRetryPolicy(),
          decode: (j) => _map(j));

  Future<Map<String, dynamic>> createPost(
    String? bearer,
    String body, {
    String? idempotencyKey,
  }) =>
      _client.post(Endpoints.communityPosts,
          bearer: bearer,
          body: {'body': body},
          headers: idempotencyKey == null
              ? null
              : {'X-Idempotency-Key': idempotencyKey},
          decode: (j) => _map(j));

  /// Attachment create: `body` is a REQUIRED form field per contract, the
  /// file is the multipart part (images/PDF, 10 MB, Tika-checked).
  Future<Map<String, dynamic>> createPostWithAttachment(
    String? bearer, {
    required String body,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
    String? idempotencyKey,
  }) =>
      _client.uploadMultipart(Endpoints.communityPostsWithAttachment,
          bearer: bearer,
          fields: {'body': body},
          fileField: 'file',
          fileName: fileName,
          contentType: contentType,
          bytes: bytes,
          headers: idempotencyKey == null
              ? null
              : {'X-Idempotency-Key': idempotencyKey},
          onProgress: onProgress,
          decode: (j) => _map(j));

  Future<Map<String, dynamic>> deletePost(
    String id,
    String? bearer, {
    String? reason,
  }) =>
      _client.delete(Endpoints.communityPost(id),
          bearer: bearer,
          query: reason == null || reason.trim().isEmpty
              ? null
              : {'reason': reason.trim()},
          decode: (j) => _map(j));

  Future<Paged<Map<String, dynamic>>> comments(
    String postId,
    String? bearer, {
    int page = 0,
    int size = 20,
  }) =>
      _client.get(Endpoints.communityPostComments(postId),
          bearer: bearer,
          query: pageQuery(page: page, size: size),
          retry: const ReadRetryPolicy(),
          decode: (j) => Paged.fromJson(j, (m) => _map(m)));

  Future<Map<String, dynamic>> createComment(
    String postId,
    String? bearer,
    String body, {
    String? idempotencyKey,
  }) =>
      _client.post(Endpoints.communityPostComments(postId),
          bearer: bearer,
          body: {'body': body},
          headers: idempotencyKey == null
              ? null
              : {'X-Idempotency-Key': idempotencyKey},
          decode: (j) => _map(j));

  Future<void> deleteComment(
    String id,
    String? bearer, {
    String? reason,
  }) =>
      _client.delete(Endpoints.communityComment(id),
          bearer: bearer,
          query: reason == null || reason.trim().isEmpty
              ? null
              : {'reason': reason.trim()},
          decode: (_) {});

  Future<void> reportPost(String postId, String? bearer, String reason) =>
      _client.post(Endpoints.communityReports,
          bearer: bearer,
          body: {
            'targetType': 'POST',
            'postId': postId,
            'reason': reason,
          },
          decode: (_) {});

  Future<void> reportComment(
          String commentId, String? bearer, String reason) =>
      _client.post(Endpoints.communityReports,
          bearer: bearer,
          body: {
            'targetType': 'COMMENT',
            'commentId': commentId,
            'reason': reason,
          },
          decode: (_) {});

  Future<Uint8List> downloadAttachment(
          String attachmentId, String? bearer) =>
      _client.downloadBytes(
          Endpoints.communityAttachmentDownload(attachmentId),
          bearer: bearer);

  Future<Paged<Map<String, dynamic>>> moderationReports(
    String? bearer, {
    bool openOnly = true,
  }) =>
      _client.get(Endpoints.communityModerationReports,
          bearer: bearer,
          query: openOnly ? {'status': 'OPEN'} : null,
          decode: (j) => Paged.fromJson(j, (m) => _map(m)));

  Future<void> resolveReport(
    String reportId,
    String? bearer, {
    String? resolution,
  }) =>
      _client.post(
          Endpoints.communityModerationReportResolve(reportId),
          bearer: bearer,
          body: {
            if (resolution != null && resolution.trim().isNotEmpty)
              'resolution': resolution.trim(),
          },
          decode: (_) {});

  Future<void> muteStudent(
    String? bearer, {
    required String userId,
    required int minutes,
    required String reason,
  }) =>
      _client.post(Endpoints.communityModerationMutes,
          bearer: bearer,
          body: {
            'userId': userId,
            'minutes': minutes,
            'reason': reason,
          },
          decode: (_) {});

  Future<void> unmuteStudent(String userId, String? bearer) =>
      _client.delete(Endpoints.communityModerationMute(userId),
          bearer: bearer, decode: (_) {});
}
