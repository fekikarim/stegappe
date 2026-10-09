import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/messaging/presentation/providers/messaging_providers.dart';
import 'realtime_sync.dart';

/// Mixes into a [ConsumerStatefulWidget]'s [State] (which also mixes in
/// [WidgetsBindingObserver]) to handle app lifecycle transitions.
///
/// On every [AppLifecycleState.resumed] event:
/// 1. The STOMP connection is re-established (idempotent if already up).
/// 2. **All** Riverpod provider categories are invalidated so every screen
///    refetches from REST — exactly the same guarantee as a socket reconnect.
mixin LifecycleResyncer<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resync();
    }
  }

  void _resync() {
    if (!mounted) return;
    // 1. Reconnect the socket (idempotent if already connected).
    ref.read(stompChatServiceProvider).ensureConnected().catchError((_) {});
    // 2. Invalidate all REST-backed providers so every visible screen
    //    refetches on next frame — mirrors the reconnect resync path.
    ref.read(realtimeSyncProvider).invalidateAll();
  }
}
