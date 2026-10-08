import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/offline/pending_writes.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../auth/domain/entities/app_user.dart' show UserRole;
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/services/stomp_chat_service.dart';
import '../../domain/entities/conversation.dart'
    show ChatMessage, ChatMessageRules;
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

    // T10/SU-VAL-01: the viewer's staff role decides whether the attachment
    // "…" menu offers "set as journal"/"set as report" (the server enforces
    // the real scope either way).
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;
    final canRegisterDocuments = role == UserRole.supervisor ||
        role == UserRole.adminSupervisor;
    // Flat rows: failed + pending bubbles first (newest-first), then history
    // with a day separator each time the calendar day changes (T07 §14).
    final rows = <Object>[
      for (var i = chat.failed.length - 1; i >= 0; i--) chat.failed[i],
      for (var i = chat.pending.length - 1; i >= 0; i--) chat.pending[i],
    ];
    for (var i = 0; i < newestFirst.length; i++) {
      final m = newestFirst[i];
      if (i == 0 || !_sameDay(newestFirst[i - 1].sentAt, m.sentAt)) {
        rows.add(_DayHeader(date: m.sentAt));
      }
      rows.add(m);
    }

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
                        message: context.userError(chat.initError!).message,
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
                                itemCount: rows.length +
                                    (chat.hasMore ? 1 : 0),
                                itemBuilder: (ctx, i) {
                                  if (i >= rows.length) {
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
                                  final row = rows[i];
                                  if (row is FailedMessage) {
                                    return _FailedBubble(
                                        failed: row,
                                        conversationId: widget
                                            .conversationId);
                                  }
                                  if (row is PendingMessage) {
                                    return _PendingBubble(
                                      pending: row,
                                      queued: ref.watch(
                                          pendingWritesProvider.select(
                                              (s) => s.items.any((w) =>
                                                  w.localId ==
                                                  row.localId))),
                                    );
                                  }
                                  if (row is _DayHeader) return row;
                                  return MessageBubble(
                                    message: row as ChatMessage,
                                    canRegisterDocuments:
                                        canRegisterDocuments,
                                    onDocumentRegistered: () {
                                      // Re-read the thread so the kind
                                      // label on the chip stays honest.
                                      ref
                                          .read(chatControllerProvider(
                                                  widget.conversationId)
                                              .notifier)
                                          .resync();
                                    },
                                  );
                                },
                              ),
                      ),
          ),
          _Composer(
            controller: _composer,
            sending: _sending,
            onSend: _send,
            // T07 (ST-MSG-02): resolve the conversation's internship for the
            // "send a document" picker. Null (offline/unknown) hides that
            // option; device pick still works. The list itself stays
            // server-filtered — never client-filtered (BR-38 §3).
            onAttach: () {
              final conversations =
                  ref.read(conversationsProvider).valueOrNull;
              String? internshipId;
              if (conversations != null) {
                for (final c in conversations) {
                  if (c.id == widget.conversationId) {
                    internshipId = c.internshipId;
                    break;
                  }
                }
              }
              showAttachmentSheet(context,
                  conversationId: widget.conversationId,
                  internshipId: internshipId);
            },
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

/// Calendar-day equality in local time (day separators, T07 §14).
bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Sticky-feel day separator: Today / Yesterday / locale full date.
/// Locale-aware through MaterialLocalizations (RTL-safe, no extra deps).
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final label = day == today
        ? l10n.msgToday
        : day == today.subtract(const Duration(days: 1))
            ? l10n.msgYesterday
            : MaterialLocalizations.of(context).formatFullDate(local);
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: StegSpacing.xs),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: StegSpacing.sm,
                vertical: StegSpacing.xs),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(StegSpacing.radiusFull),
            ),
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
    );
  }
}

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
  const _PendingBubble({required this.pending, this.queued = false});

  final PendingMessage pending;

  /// True while the message waits in the persisted offline queue (T06):
  /// visibly pending, never shown as sent.
  final bool queued;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              if (queued)
                Text(l10n.pendingLabel,
                    style:
                        Theme.of(context).textTheme.labelSmall)
              else
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
                // T07/BR-56: the retry reuses the failed attempt's key so a
                // replay after a successful server write cannot duplicate.
                final key = failed.key;
                controller.discardFailed(failed);
                controller.send(failed.content,
                    idempotencyKey: key);
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
                  // T07 §5: server contract `@Size(max=4000)` mirrored for UX
                  // (the server stays authoritative; over-long pastes fail
                  // fast with the precise sentence instead of a raw error).
                  maxLength: ChatMessageRules.maxLength,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.enforced,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      null,
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
