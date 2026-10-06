import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'realtime_sync.dart';
import '../../../features/messaging/domain/entities/notification_item.dart';

/// T08 community sync triggers (same posture as `task_sync.dart`).
///
/// A notification frame is a *sync trigger*, never state: community-class
/// frames invalidate the community providers so Riverpod refetches the
/// authoritative REST feed. Nothing here applies payloads, so duplicates
/// and reorderings are harmless by construction.
RealtimeCategory? communitySyncCategoryFor(NotificationItem item) {
  switch (item.type) {
    case NotificationType.communityComment:
    case NotificationType.communityPostRemoved:
    case NotificationType.communityCommentRemoved:
      return RealtimeCategory.community;
    default:
      return null;
  }
}

/// Fan-out sink for raw `/topic/community` envelopes
/// (`{kind, postId, at}` — trigger only, never content).
///
/// Exactly one session-wide owner holds the socket slot (the community
/// feed controller, mirroring P15's single-owner rule for notifications);
/// any number of in-app listeners consume the sink without touching the
/// socket — closing a screen can never leave a stale socket handler behind.
class CommunityFrames {
  final _controller = StreamController<String>.broadcast();

  Stream<String> get stream => _controller.stream;

  void add(String body) {
    if (!_controller.isClosed) _controller.add(body);
  }

  Future<void> dispose() => _controller.close();
}

/// Session-wide sink for `/topic/community` envelopes (owned by
/// `foregroundSyncProvider`, mirroring P15's notification-frames rule:
/// exactly one socket slot, any number of in-app listeners).
final communityFramesProvider = Provider<CommunityFrames>((ref) {
  final frames = CommunityFrames();
  ref.onDispose(frames.dispose);
  return frames;
});
