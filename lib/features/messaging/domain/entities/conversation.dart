import 'package:equatable/equatable.dart';

/// Conversation types (backend-owned): private intern↔supervisor thread
/// (linked to an internship) or current-interns group.
enum ConversationType { private, group }

ConversationType conversationTypeFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'PRIVATE' => ConversationType.private,
      _ => ConversationType.group,
    };

class ConversationMember extends Equatable {
  const ConversationMember({
    required this.userId,
    required this.role,
    this.lastReadSequenceNumber,
  });

  final String userId;
  final String role;
  final int? lastReadSequenceNumber;

  @override
  List<Object?> get props => [userId, role, lastReadSequenceNumber];
}

class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    this.internshipId,
    this.members = const [],
    this.lastSequenceNumber,
    this.unreadCount = 0,
    this.lastMessage,
  });

  final String id;
  final ConversationType type;
  final String title;
  final String? internshipId;
  final List<ConversationMember> members;
  final int? lastSequenceNumber;
  final int unreadCount;
  final ChatMessage? lastMessage;

  bool get isPrivate => type == ConversationType.private;

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        internshipId,
        members,
        lastSequenceNumber,
        unreadCount,
        lastMessage,
      ];
}

enum MessageStatus { sent, delivered, read, edited, deleted }

MessageStatus messageStatusFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'DELIVERED' => MessageStatus.delivered,
      'READ' => MessageStatus.read,
      'EDITED' => MessageStatus.edited,
      'DELETED' => MessageStatus.deleted,
      _ => MessageStatus.sent,
    };

class MessageAttachment extends Equatable {
  const MessageAttachment({
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

/// A chat message. Ordering is by [sequenceNumber] (monotonic per
/// conversation, backend-assigned) — never by wall-clock time.
/// Deleted messages keep their slot with redacted content (backend
/// soft-deletes; history is preserved).
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.status,
    required this.sequenceNumber,
    required this.sentAt,
    this.attachments = const [],
    this.mine = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageStatus status;
  final int sequenceNumber;
  final DateTime sentAt;
  final List<MessageAttachment> attachments;
  final bool mine;

  bool get isDeleted => status == MessageStatus.deleted;

  /// Redacted display text for soft-deleted messages.
  String displayContent(String redactedLabel) =>
      isDeleted ? redactedLabel : content;

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        content,
        status,
        sequenceNumber,
        sentAt,
        attachments,
        mine,
      ];
}

/// Merge REST history with live frames: dedupe by id, order by
/// sequenceNumber ascending, cap the in-memory window.
List<ChatMessage> mergeMessages(
  List<ChatMessage> current,
  List<ChatMessage> incoming, {
  int cap = 500,
}) {
  final byId = <String, ChatMessage>{for (final m in current) m.id: m};
  for (final m in incoming) {
    byId[m.id] = m;
  }
  final merged = byId.values.toList()
    ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
  if (merged.length <= cap) return merged;
  return merged.sublist(merged.length - cap);
}
