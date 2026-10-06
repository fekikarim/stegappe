import '../../domain/entities/community.dart';

DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

DateTime _dateOrNow(dynamic v) => _date(v) ?? DateTime.now();

String _str(dynamic v, [String fallback = '']) =>
    v is String ? v : fallback;

CommunityAttachment communityAttachmentFromJson(
        Map<String, dynamic> json) =>
    CommunityAttachment(
      id: _str(json['id']),
      fileName: _str(json['fileName']),
      mimeType: _str(json['mimeType']),
      size: (json['size'] as num?)?.toInt() ?? 0,
    );

CommunityPost communityPostFromJson(Map<String, dynamic> json,
        {String? selfUserId}) {
  final authorId = _str(json['authorUserId']);
  return CommunityPost(
    id: _str(json['id']),
    authorId: authorId,
    authorDisplayName: _str(json['authorDisplayName'], '—'),
    body: (json['body'] ?? '').toString(),
    status: communityStatusFrom(json['status'] as String?),
    commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
    createdAt: _dateOrNow(json['createdAt']),
    attachment: json['attachment'] is Map<String, dynamic>
        ? communityAttachmentFromJson(
            (json['attachment'] as Map).cast<String, dynamic>())
        : null,
    mine: selfUserId != null &&
        selfUserId.isNotEmpty &&
        authorId.isNotEmpty &&
        authorId == selfUserId,
  );
}

CommunityFeedPage communityFeedFromJson(dynamic json,
    {String? selfUserId}) {
  final map = (json as Map?)?.cast<String, dynamic>() ?? {};
  final rawItems = map['items'];
  return CommunityFeedPage(
    items: [
      if (rawItems is List)
        for (final e in rawItems)
          if (e is Map<String, dynamic>)
            communityPostFromJson(e, selfUserId: selfUserId),
    ],
    hasMore: map['hasMore'] is bool ? map['hasMore'] as bool : false,
    nextCursorTs: _date(map['nextCursorTs']),
    nextCursorId: map['nextCursorId'] as String?,
  );
}

CommunityComment communityCommentFromJson(Map<String, dynamic> json,
    {String? selfUserId}) {
  final authorId = _str(json['authorUserId']);
  return CommunityComment(
    id: _str(json['id']),
    postId: _str(json['postId']),
    authorId: authorId,
    authorDisplayName: _str(json['authorDisplayName'], '—'),
    body: (json['body'] ?? '').toString(),
    createdAt: _dateOrNow(json['createdAt']),
    mine: selfUserId != null &&
        selfUserId.isNotEmpty &&
        authorId.isNotEmpty &&
        authorId == selfUserId,
  );
}

CommunityReport communityReportFromJson(Map<String, dynamic> json) =>
    CommunityReport(
      id: _str(json['id']),
      targetType: _str(json['targetType'], 'POST'),
      targetPostId: json['targetPostId'] as String?,
      targetCommentId: json['targetCommentId'] as String?,
      reason: (json['reason'] ?? '').toString(),
      status: communityReportStatusFrom(json['status'] as String?),
      createdAt: _dateOrNow(json['createdAt']),
    );
