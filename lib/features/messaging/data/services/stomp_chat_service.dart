import 'dart:async';

/// Transport state. Never assumed permanent: every send path checks
/// [ChatConnectionState.connected] and falls back to REST otherwise.
enum ChatConnectionState { disconnected, connecting, connected }

/// Frame callbacks use raw JSON strings (parsed by the repository).
typedef ChatFrameCallback = void Function(String body);

/// STOMP-over-WebSocket contract (backend Phase A9):
/// - handshake `/ws` (JWT: `Authorization` header preferred,
///   `?token=` fallback where headers are unavailable);
/// - send `/app/conversations/{id}/send` (`{"content"}`),
///   acks `/app/.../delivered` + `/app/.../read`
///   (`{"upToSequenceNumber"}`);
/// - broadcasts `/topic/conversations/{id}` (new + status updates);
/// - personal notifications `/user/queue/notifications`;
/// - sender errors `/user/queue/errors` (never leaks other conversations).
///
/// Implementations must reconnect with backoff, resubscribe tracked
/// topics on every reconnect, and surface state for honest UI.
abstract class StompChatService {
  Stream<ChatConnectionState> get state;
  ChatConnectionState get currentState;

  /// Connect (or no-op when already connected/connecting).
  Future<void> ensureConnected();

  /// Disconnect and drop tracked subscriptions.
  Future<void> disconnect();

  /// Subscribe to a conversation topic. Re-subscribed automatically
  /// after reconnects until [cancel] is called.
  /// Returns a cancel callback.
  Future<void Function()> subscribeConversation(
      String conversationId, ChatFrameCallback onFrame);

  Future<void> subscribeNotifications(ChatFrameCallback onPayload);
  Future<void> subscribeErrors(void Function(String code, String message) onError);

  Future<void> sendMessage(String conversationId, String content);
  Future<void> ackDelivered(String conversationId, int upToSequence);
  Future<void> ackRead(String conversationId, int upToSequence);

  /// Fired after every (re)connect so listeners resync via REST cursor.
  Stream<void> get resyncRequested;
}
