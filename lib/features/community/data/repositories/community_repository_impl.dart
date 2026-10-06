import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/network/paged.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/community.dart';
import '../../domain/repositories/community_repository.dart';
import '../datasources/community_remote_data_source.dart';
import '../models/community_dtos.dart';

/// Coordinates REST (authoritative) community reads/writes.
///
/// Realtime frames are invalidation triggers only (handled in the
/// providers): every mutation here returns the persisted server row, and
/// every list is refetched after a frame. No socket writes exist for the
/// community — sends are REST-only.
class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl({
    required this.remote,
    required this.tokens,
  });

  final CommunityRemoteDataSource remote;
  final TokenStorage tokens;

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
  Future<CommunityFeedPage> feed(
      {DateTime? cursorTs, String? cursorId, int size = 20}) async {
    final bearer = await _bearer();
    final self = await _selfId();
    final json = await remote.feedPage(bearer,
        cursorTs: cursorTs, cursorId: cursorId, size: size);
    return communityFeedFromJson(json, selfUserId: self);
  }

  @override
  Future<CommunityPost> post(String postId) async {
    final json = await remote.getPost(postId, await _bearer());
    return communityPostFromJson(json, selfUserId: await _selfId());
  }

  @override
  Future<CommunityPost> createPost(String body,
      {String? idempotencyKey}) async {
    final json = await remote.createPost(await _bearer(), body,
        idempotencyKey: idempotencyKey);
    return communityPostFromJson(json, selfUserId: await _selfId());
  }

  @override
  Future<CommunityPost> createPostWithAttachment({
    required String body,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
    String? idempotencyKey,
  }) async {
    final json = await remote.createPostWithAttachment(await _bearer(),
        body: body,
        fileName: fileName,
        contentType: contentType,
        bytes: bytes,
        onProgress: onProgress,
        idempotencyKey: idempotencyKey);
    return communityPostFromJson(json, selfUserId: await _selfId());
  }

  @override
  Future<CommunityPost> deletePost(String postId, {String? reason}) async {
    final json =
        await remote.deletePost(postId, await _bearer(), reason: reason);
    return communityPostFromJson(json, selfUserId: await _selfId());
  }

  @override
  Future<Paged<CommunityComment>> comments(String postId,
      {int page = 0, int size = 20}) async {
    final bearer = await _bearer();
    final self = await _selfId();
    final raw =
        await remote.comments(postId, bearer, page: page, size: size);
    return Paged<CommunityComment>(
      items: [
        for (final m in raw.items)
          communityCommentFromJson(m, selfUserId: self),
      ],
      page: raw.page,
      totalElements: raw.totalElements,
      totalPages: raw.totalPages,
      isLast: raw.isLast,
    );
  }

  @override
  Future<CommunityComment> comment(String postId, String body,
      {String? idempotencyKey}) async {
    final json = await remote.createComment(postId, await _bearer(), body,
        idempotencyKey: idempotencyKey);
    return communityCommentFromJson(json, selfUserId: await _selfId());
  }

  @override
  Future<void> deleteComment(String commentId, {String? reason}) async {
    await remote.deleteComment(commentId, await _bearer(),
        reason: reason);
  }

  @override
  Future<void> reportPost(String postId, String reason) async {
    await remote.reportPost(postId, await _bearer(), reason);
  }

  @override
  Future<void> reportComment(String commentId, String reason) async {
    await remote.reportComment(commentId, await _bearer(), reason);
  }

  @override
  Future<Uint8List> downloadAttachment(
          String attachmentId, String fileName) async =>
      remote.downloadAttachment(attachmentId, await _bearer());

  @override
  Future<Paged<CommunityReport>> reports({bool openOnly = true}) async {
    final raw =
        await remote.moderationReports(await _bearer(), openOnly: openOnly);
    return Paged<CommunityReport>(
      items: [for (final m in raw.items) communityReportFromJson(m)],
      page: raw.page,
      totalElements: raw.totalElements,
      totalPages: raw.totalPages,
      isLast: raw.isLast,
    );
  }

  @override
  Future<void> resolveReport(String reportId, {String? resolution}) async {
    await remote.resolveReport(reportId, await _bearer(),
        resolution: resolution);
  }

  @override
  Future<void> muteStudent(
      {required String userId,
      required int minutes,
      required String reason}) async {
    await remote.muteStudent(await _bearer(),
        userId: userId, minutes: minutes, reason: reason);
  }

  @override
  Future<void> unmuteStudent(String userId) async {
    await remote.unmuteStudent(userId, await _bearer());
  }
}
