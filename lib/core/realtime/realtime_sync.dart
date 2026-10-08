import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/community/presentation/providers/community_providers.dart';
import '../../features/internship/presentation/providers/workspace_providers.dart';
import '../../features/messaging/presentation/providers/messaging_providers.dart';

/// The kinds of server-side state that can change underneath a screen.
///
/// A realtime frame (T06) or an offline resync names one category; the
/// [RealtimeSync] surface is the **single place** that decides which Riverpod
/// providers that makes stale. Screens stay correct with the socket down
/// because refreshing the provider is the only effect — there is no local
/// source of truth here (SKILL.md §5, realtime.md).
enum RealtimeCategory {
  tasks,
  documents,
  notifications,
  community,
  messages,
}

/// Invalidation surface used by the realtime layer and by offline resync.
///
/// Deliberately tiny: it invalidates providers, it never mutates data and it
/// never touches the socket. That keeps it safe to call with no connection
/// (offline foundation) and keeps the socket from becoming a source of truth.
abstract interface class RealtimeSync {
  /// Mark the providers backing [category] stale; Riverpod refetches the
  /// authoritative REST state on next read.
  void invalidate(RealtimeCategory category);

  /// Mark every category stale (used after a reconnect or on resume).
  void invalidateAll();
}

/// Category → providers that must be refetched when that category changes.
///
/// The mapping lives in one place so a feature never decides its own refresh
/// policy. T08 wires the community surface: feed + open detail + staff
/// reports queue all refetch over REST on any community trigger.
final Map<RealtimeCategory, List<ProviderOrFamily>> kRealtimeTargets = {
  RealtimeCategory.tasks: <ProviderOrFamily>[
    taskListProvider,
    internshipTasksProvider,
    supervisedInternsProvider,
    dashboardProvider,
  ],
  RealtimeCategory.documents: <ProviderOrFamily>[
    deliverablesListProvider,
    journalListProvider,
    pendingValidationsProvider,
    pendingDeliverableReviewsProvider,
    pendingLogbookReviewsProvider,
    // T12: the supervised list carries server counts (pending journal /
    // deliverables), so document frames converge it too.
    supervisedInternsProvider,
    dashboardProvider,
  ],
  RealtimeCategory.notifications: <ProviderOrFamily>[
    notificationsProvider,
    unreadNotificationsProvider,
    dashboardProvider,
  ],
  RealtimeCategory.community: <ProviderOrFamily>[
    communityFeedProvider,
    communityPostDetailProvider,
    communityReportsProvider,
  ],
  RealtimeCategory.messages: <ProviderOrFamily>[
    conversationsProvider,
    totalUnreadMessagesProvider,
  ],
};

/// Riverpod-backed [RealtimeSync]. [invalidate] is the Riverpod invalidation
/// callback (`ref.invalidate` or `ProviderContainer.invalidate`); [targets] is
/// injectable so the mapping can be unit-tested without a network or a socket.
class RiverpodRealtimeSync implements RealtimeSync {
  RiverpodRealtimeSync(
    this._invalidate, {
    Map<RealtimeCategory, List<ProviderOrFamily>>? targets,
  }) : _targets = targets ?? kRealtimeTargets;

  final void Function(ProviderOrFamily) _invalidate;
  final Map<RealtimeCategory, List<ProviderOrFamily>> _targets;

  /// Providers invalidated for [category] (empty when the category has no
  /// mobile surface).
  List<ProviderOrFamily> targetsFor(RealtimeCategory category) =>
      _targets[category] ?? const <ProviderOrFamily>[];

  @override
  void invalidate(RealtimeCategory category) {
    for (final provider in targetsFor(category)) {
      _invalidate(provider);
    }
  }

  @override
  void invalidateAll() {
    for (final category in RealtimeCategory.values) {
      invalidate(category);
    }
  }
}

/// Session-scoped [RealtimeSync]. Not tied to the socket lifecycle: T06 wires
/// socket frames to [RealtimeSync.invalidate] where the frames are received.
final realtimeSyncProvider =
    Provider<RealtimeSync>((ref) => RiverpodRealtimeSync(ref.invalidate));
