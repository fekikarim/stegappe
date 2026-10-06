import 'package:equatable/equatable.dart';

/// Student community content (T08 / ST-COM-01/02, D7).
///
/// Privacy (D7 / BR-39): authors surface as an opaque [authorId] plus a
/// server-derived [authorDisplayName] (first name + last initial) — never
/// email, CIN, university or supervisor data. The app never invents these;
/// every field mirrors the backend contract.
enum CommunityContentStatus { visible, deleted, removed }

CommunityContentStatus communityStatusFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'DELETED' => CommunityContentStatus.deleted,
      'REMOVED' => CommunityContentStatus.removed,
      _ => CommunityContentStatus.visible,
    };

/// Server content limits (UX pre-checks only — the server decides).
abstract final class CommunityContentRules {
  static const int maxPostLength = 2000;
  static const int maxCommentLength = 1000;
  static const int maxReasonLength = 500;

  static bool isPostable(String raw) => raw.trim().isNotEmpty;
}

/// Attachment metadata on a post (images/PDF, server-checked, ≤ 10 MB).
class CommunityAttachment extends Equatable {
  const CommunityAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.size,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int size;

  bool get isImage => mimeType.startsWith('image/');

  @override
  List<Object?> get props => [id, fileName, mimeType, size];
}

/// One community post. Ordering is backend-authoritative
/// (`createdAt DESC, id DESC` keyset) — never by device clock.
class CommunityPost extends Equatable {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorDisplayName,
    required this.body,
    required this.status,
    required this.commentCount,
    required this.createdAt,
    this.attachment,
    this.mine = false,
    this.pending = false,
  });

  final String id;
  final String authorId;
  final String authorDisplayName;
  final String body;
  final CommunityContentStatus status;
  final int commentCount;
  final DateTime createdAt;
  final CommunityAttachment? attachment;

  /// True when the backend JWT `sub` matches the author (routing only).
  final bool mine;

  /// True for an optimistic post awaiting the server answer.
  final bool pending;

  bool get isGone => status != CommunityContentStatus.visible;

  CommunityPost copyWith({
    int? commentCount,
    CommunityContentStatus? status,
    bool? pending,
  }) =>
      CommunityPost(
        id: id,
        authorId: authorId,
        authorDisplayName: authorDisplayName,
        body: body,
        status: status ?? this.status,
        commentCount: commentCount ?? this.commentCount,
        createdAt: createdAt,
        attachment: attachment,
        mine: mine,
        pending: pending ?? this.pending,
      );

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorDisplayName,
        body,
        status,
        commentCount,
        createdAt,
        attachment,
        mine,
        pending,
      ];
}

/// One comment on a post (flat thread, chronological).
class CommunityComment extends Equatable {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorDisplayName,
    required this.body,
    required this.createdAt,
    this.mine = false,
    this.pending = false,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorDisplayName;
  final String body;
  final DateTime createdAt;
  final bool mine;
  final bool pending;

  CommunityComment copyWith({bool? pending}) => CommunityComment(
        id: id,
        postId: postId,
        authorId: authorId,
        authorDisplayName: authorDisplayName,
        body: body,
        createdAt: createdAt,
        mine: mine,
        pending: pending ?? this.pending,
      );

  @override
  List<Object?> get props =>
      [id, postId, authorId, authorDisplayName, body, createdAt, mine, pending];
}

/// Keyset feed window: items plus the cursor for the next page
/// (null cursor = feed exhausted).
class CommunityFeedPage extends Equatable {
  const CommunityFeedPage({
    required this.items,
    required this.hasMore,
    this.nextCursorTs,
    this.nextCursorId,
  });

  final List<CommunityPost> items;
  final bool hasMore;
  final DateTime? nextCursorTs;
  final String? nextCursorId;

  @override
  List<Object?> get props => [items, hasMore, nextCursorTs, nextCursorId];
}

/// Report status (staff queue).
enum CommunityReportStatus { open, resolved }

CommunityReportStatus communityReportStatusFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'RESOLVED' => CommunityReportStatus.resolved,
      _ => CommunityReportStatus.open,
    };

class CommunityReport extends Equatable {
  const CommunityReport({
    required this.id,
    required this.targetType,
    this.targetPostId,
    this.targetCommentId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;

  /// `POST` or `COMMENT` (backend vocabulary, kept verbatim).
  final String targetType;
  final String? targetPostId;
  final String? targetCommentId;

  /// Reporter text (staff-visible only; never shown to authors).
  final String reason;
  final CommunityReportStatus status;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        targetType,
        targetPostId,
        targetCommentId,
        reason,
        status,
        createdAt
      ];
}

/// Merge feed pages: dedupe by id, newest-first by
/// (`createdAt DESC, id DESC`), cap the in-memory window.
List<CommunityPost> mergeCommunityPosts(
  List<CommunityPost> current,
  List<CommunityPost> incoming, {
  int cap = 200,
}) {
  final byId = <String, CommunityPost>{for (final p in current) p.id: p};
  for (final p in incoming) {
    byId[p.id] = p;
  }
  final merged = byId.values.toList()
    ..sort((a, b) {
      final time = b.createdAt.compareTo(a.createdAt);
      return time != 0 ? time : b.id.compareTo(a.id);
    });
  if (merged.length <= cap) return merged;
  return merged.sublist(0, cap);
}
