import 'dart:typed_data';

import '../../../../core/network/paged.dart';
import '../entities/community.dart';

/// Community contract. Server-side standing stays authoritative: every
/// call may 403/404, which the UI surfaces instead of guessing.
/// Writers = active-internship students; readers = + staff (moderation).
abstract class CommunityRepository {
  /// Newest-first keyset window; both cursors null = first page.
  Future<CommunityFeedPage> feed(
      {DateTime? cursorTs, String? cursorId, int size = 20});

  Future<CommunityPost> post(String postId);

  /// JSON create (no attachment). [idempotencyKey] identifies one logical
  /// post — retries replay instead of duplicating.
  Future<CommunityPost> createPost(String body, {String? idempotencyKey});

  Future<CommunityPost> createPostWithAttachment({
    required String body,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
    String? idempotencyKey,
  });

  /// Author withdraws (no reason) or staff removes ([reason] mandatory,
  /// server-enforced). Returns the tombstone response.
  Future<CommunityPost> deletePost(String postId, {String? reason});

  Future<Paged<CommunityComment>> comments(String postId,
      {int page = 0, int size = 20});

  Future<CommunityComment> comment(String postId, String body,
      {String? idempotencyKey});

  Future<void> deleteComment(String commentId, {String? reason});

  Future<void> reportPost(String postId, String reason);
  Future<void> reportComment(String commentId, String reason);

  Future<Uint8List> downloadAttachment(String attachmentId, String fileName);

  // --- Staff moderation ---
  Future<Paged<CommunityReport>> reports({bool openOnly = true});

  Future<void> resolveReport(String reportId, {String? resolution});

  Future<void> muteStudent(
      {required String userId,
      required int minutes,
      required String reason});

  Future<void> unmuteStudent(String userId);
}
