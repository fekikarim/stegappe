import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../data/services/stomp_chat_service.dart';
import '../providers/messaging_providers.dart';
import '../widgets/message_bubble.dart';
import 'attachment_sheet.dart';

/// One conversation: REST history (newest-first pages merged ascending),
/// live STOMP frames, upward infinite loading, composer with pending /
/// failed states, read markers, and an honest socket-status strip.
///
/// Ordering is ALWAYS by backend `sequenceNumber`, never wall-clock.
/// Membership stays server-authoritative: a rejected subscribe or send
/// surfaces the backend message instead of guessing.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _composer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Sockets die in background; resync the cursor window on resume
  /// (plus the socket's own reconnect → resyncRequested path).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .resync();
    }
  }

  void _onScroll() {
    // Reversed list: maxScrollExtent edge loads older history.
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .loadMore()
          .catchError((_) {});
    }
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _composer.clear();
    try {
      await ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .send(text);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _jumpToBottom();
      }
    }
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.of(context).disableAnimations) {
      _scroll.jumpTo(_scroll.position.minScrollExtent);
      return;
    }
    _scroll.animateTo(
      _scroll.position.minScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chat = ref.watch(chatControllerProvider(widget.conversationId));
    final socket = ref.watch(_socketStateProvider).valueOrNull ??
        ChatConnectionState.disconnected;
    final isOnline = ref.watch(isOnlineProvider);

    // Newest-first for the reversed ListView (bottom = latest).
    final newestFirst = chat.messages.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          _SocketStrip(state: socket, isOnline: isOnline),
          Expanded(
            child: !chat.initialized
                ? const Center(
                    child: CircularProgressIndicator())
                : chat.initError != null && chat.messages.isEmpty
                    ? _ChatError(
                        message: chat.initError!,
                        onRetry: () => ref
                            .read(chatControllerProvider(
                                    widget.conversationId)
                                .notifier)
                            .retryInitial(),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(chatControllerProvider(
                                    widget.conversationId)
                                .notifier)
                            .resync(),
                        child: chat.messages.isEmpty &&
                                chat.pending.isEmpty &&
                                chat.failed.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 120),
                                  Icon(
                                      Icons
                                          .chat_bubble_outline,
                                      size: 44,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(
                                      height:
                                          StegSpacing.sm),
                                  Center(
                                      child: Text(
                                          l10n.msgNoHistory)),
                                ],
                              )
                            : ListView.builder(
                                controller: _scroll,
                                reverse: true,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                itemCount:
                                    newestFirst.length +
                                        chat.pending.length +
                                        chat.failed.length +
                                        (chat.hasMore ? 1 : 0),
                                itemBuilder: (ctx, i) {
                                  if (i <
                                      chat.failed.length) {
                                    final f = chat
                                        .failed[chat
                                                .failed.length -
                                            1 -
                                            i];
                                    return _FailedBubble(
                                        failed: f,
                                        conversationId: widget
                                            .conversationId);
                                  }
                                  final pi = i -
                                      chat.failed.length;
                                  if (pi <
                                      chat.pending.length) {
                                    final p = chat.pending[
                                        chat.pending.length -
                                            1 -
                                            pi];
                                    return _PendingBubble(
                                        pending: p);
                                  }
                                  final mi = pi -
                                      chat.pending.length;
                                  if (mi >=
                                      newestFirst.length) {
                                    // Older history exists but is
                                    // fetched only on scroll: no
                                    // perpetual motion (settle +
                                    // reduced-motion friendly).
                                    if (!chat.loadingMore) {
                                      return const SizedBox
                                          .shrink();
                                    }
                                    return const Padding(
                                      padding:
                                          EdgeInsets.all(12),
                                      child: Center(
                                          child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth:
                                                          2))),
                                    );
                                  }
                                  return MessageBubble(
                                      message:
                                          newestFirst[mi]);
                                },
                              ),
                      ),
          ),
          _Composer(
            controller: _composer,
            sending: _sending,
            onSend: _send,
            onAttach: () => showAttachmentSheet(context,
                conversationId: widget.conversationId),
          ),
        ],
      ),
    );
  }
}

/// Socket status strip: live / connecting / fallback. Never claims
/// real-time when the socket is down (task 10 + task 4 honesty).
class _SocketStrip extends ConsumerWidget {
  const _SocketStrip({required this.state, required this.isOnline});

  final ChatConnectionState state;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (state == ChatConnectionState.connected && isOnline) {
      return const SizedBox.shrink();
    }
    final text = !isOnline
        ? l10n.offline
        : state == ChatConnectionState.connecting
            ? l10n.sockConnecting
            : l10n.sockOffline;
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md,
            vertical: StegSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: state ==
                      ChatConnectionState.connecting
                  ? const CircularProgressIndicator(
                      strokeWidth: 2)
                  : const Icon(Icons.sync_outlined,
                      size: 14),
            ),
            const SizedBox(width: StegSpacing.xs),
            Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

final _socketStateProvider =
    StreamProvider<ChatConnectionState>((ref) {
  final stomp = ref.watch(stompChatServiceProvider);
  return stomp.state;
});

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: StegSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: StegSpacing.sm),
            ElevatedButton(
                onPressed: onRetry,
                child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({required this.pending});

  final PendingMessage pending;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Opacity(
        opacity: 0.7,
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: StegSpacing.md,
              vertical: StegSpacing.xs),
          padding: const EdgeInsets.symmetric(
              horizontal: StegSpacing.sm,
              vertical: StegSpacing.xs),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primaryContainer,
            borderRadius:
                BorderRadius.circular(StegSpacing.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(pending.content)),
              const SizedBox(width: StegSpacing.xs),
              const SizedBox(
                width: 12,
                height: 12,
                child:
                    CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailedBubble extends ConsumerWidget {
  const _FailedBubble(
      {required this.failed, required this.conversationId});

  final FailedMessage failed;
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md,
            vertical: StegSpacing.xs),
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.sm,
            vertical: StegSpacing.xs),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .errorContainer,
          borderRadius:
              BorderRadius.circular(StegSpacing.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(failed.content),
                  Text(l10n.msgFailed,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.msgRetry,
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () {
                final controller = ref.read(
                    chatControllerProvider(
                            conversationId)
                        .notifier);
                controller.discardFailed(failed);
                controller.send(failed.content);
              },
            ),
            IconButton(
              tooltip: l10n.msgDiscard,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref
                  .read(chatControllerProvider(
                          conversationId)
                      .notifier)
                  .discardFailed(failed),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            StegSpacing.sm,
            StegSpacing.xs,
            StegSpacing.sm,
            StegSpacing.sm),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: l10n.msgAttach,
              child: IconButton(
                tooltip: l10n.msgAttach,
                icon: const Icon(Icons.attach_file_outlined),
                onPressed: onAttach,
              ),
            ),
            Expanded(
              child: Semantics(
                textField: true,
                label: l10n.msgHint,
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: l10n.msgHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          StegSpacing.radiusFull),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: StegSpacing.md,
                            vertical: StegSpacing.xs),
                  ),
                ),
              ),
            ),
            const SizedBox(width: StegSpacing.xs),
            Semantics(
              button: true,
              label: l10n.msgSend,
              child: SizedBox(
                width: StegSpacing.minTouchTarget,
                height: StegSpacing.minTouchTarget,
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      )
                    : IconButton.filled(
                        tooltip: l10n.msgSend,
                        icon: const Icon(Icons.send_outlined),
                        onPressed: onSend,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
