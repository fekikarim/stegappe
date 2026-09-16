import '../../domain/entities/conversation.dart';

DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

DateTime _dateOrNow(dynamic v) => _date(v) ?? DateTime.now();

String _str(dynamic v, [String fallback = '']) =>
    v is String ? v : fallback;

Conversation conversationFromJson(
  Map<String, dynamic> json, {
  int unreadCount = 0,
  ChatMessage? lastMessage,
}) =>
    Conversation(
      id: _str(json['id']),
      type: conversationTypeFrom(json['type'] as String?),
      title: _str(json['title']),
      internshipId: json['internshipId'] as String?,
      members: [
        if (json['members'] is List)
          for (final e in json['members'] as List)
            if (e is Map<String, dynamic>)
              ConversationMember(
                userId: _str(e['userId']),
                role: _str(e['role']),
                lastReadSequenceNumber:
                    (e['lastReadSequenceNumber'] as num?)?.toInt(),
              ),
      ],
      lastSequenceNumber:
          (json['lastSequenceNumber'] as num?)?.toInt(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? unreadCount,
      lastMessage: lastMessage,
    );

MessageAttachment attachmentFromJson(Map<String, dynamic> json) =>
    MessageAttachment(
      id: _str(json['id']),
      fileName: _str(json['fileName']),
      mimeType: _str(json['mimeType']),
      size: (json['size'] as num?)?.toInt() ?? 0,
    );

ChatMessage messageFromJson(Map<String, dynamic> json,
        {String? selfUserId}) =>
    ChatMessage(
      id: _str(json['id']),
      conversationId: _str(json['conversationId']),
      senderId: _str(json['senderId']),
      content: (json['content'] ?? '').toString(),
      status: messageStatusFrom(json['status'] as String?),
      sequenceNumber:
          (json['sequenceNumber'] as num?)?.toInt() ?? 0,
      sentAt: _dateOrNow(json['sentAt']),
      attachments: [
        if (json['attachments'] is List)
          for (final e in json['attachments'] as List)
            if (e is Map<String, dynamic>) attachmentFromJson(e),
      ],
      mine: selfUserId != null &&
          selfUserId.isNotEmpty &&
          _str(json['senderId']) == selfUserId,
    );
