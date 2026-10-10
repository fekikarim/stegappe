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
import '../../../internship/presentation/providers/workspace_providers.dart';
import '../../data/services/stomp_chat_service.dart';
import '../../domain/entities/conversation.dart'
    show ChatMessage, ChatMessageRules;
import '../providers/messaging_providers.dart';
import '../widgets/conversation_title.dart';
import '../widgets/message_bubble.dart';
import 'attachment_sheet.dart';

/// One conversation: REST history (newest-first pages merged ascending),
/// live STOMP frames, upward infinite loading, composer with pending /
/// failed states, Messenger-style read receipts and 1-to-1 message
/// actions (edit / delete), all over a silent real-time layer.
///
/// Ordering is ALWAYS by backend `sequenceNumber`, never wall-clock.
/// Membership stays server-authoritative: a rejected subscribe or send
/// surfaces the backend message instead of guessing.
///
/// The socket state never renders as a banner: a small presence dot on the
/// avatar reflects the connection, and traffic silently falls back to REST
/// (pending/queued states stay visible on the bubbles themselves).
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

  /// Reused by every edit dialog. State-owned (NOT dialog-owned): disposing
  /// a dialog-owned controller synchronously on pop races the route's exit
  /// animation — the popping TextField rebuilds with the dead controller
  /// ("used after being disposed" → InheritedElement red screen). This one
  /// lives as long as the screen, so no race is possible.
  final _editController = TextEditingController();

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
    _editController.dispose();
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
      ref.invalidate(
          conversationDetailProvider(widget.conversationId));
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

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.userError(e).message)),
    );
  }

  /// 1-to-1 edit flow: prefilled dialog → optimistic controller update.
  /// The dialog borrows the state-owned [_editController] (see its doc):
  /// it is never disposed here, so the popping route can rebuild safely.
  Future<void> _editMessage(ChatMessage m) async {
    final l10n = AppLocalizations.of(context);
    _editController.text = m.content;
    _editController.selection = TextSelection.collapsed(
        offset: _editController.text.length);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.msgEditTitle),
        content: TextField(
          controller: _editController,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: ChatMessageRules.maxLength,
          decoration: InputDecoration(hintText: l10n.msgHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_editController.text.trim()),
            child: Text(l10n.msgSave),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (next == null || next.isEmpty || next == m.content) return;
    try {
      await ref
          .read(chatControllerProvider(widget.conversationId)
              .notifier)
          .editMessage(m.id, next);
    } on Exception catch (e) {
      _showError(e);
    }
  }

  /// 1-to-1 delete flow: confirm → optimistic redaction.
  Future<void> _deleteMessage(ChatMessage m) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.msgDeleteTitle),
        content: Text(l10n.msgDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.msgDiscard),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(chatControllerProvider(widget.conversationId)
              .notifier)
          .deleteMessage(m.id);
    } on Exception catch (e) {
      _showError(e);
    }
  }

  Future<void> _markAsRead() async {
    try {
      await ref
          .read(chatControllerProvider(widget.conversationId)
              .notifier)
          .markAsReadNow();
    } on Exception {
      // Best-effort; the watermark advances on next resync anyway.
    }
    ref
      ..invalidate(conversationDetailProvider(widget.conversationId))
      ..invalidate(conversationsProvider)
      ..invalidate(totalUnreadMessagesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chat =
        ref.watch(chatControllerProvider(widget.conversationId));
    final socket = ref.watch(_socketStateProvider).valueOrNull ??
        ChatConnectionState.disconnected;
    final isOnline = ref.watch(isOnlineProvider);
    final connected =
        socket == ChatConnectionState.connected && isOnline;

    // Newest-first for the reversed ListView (bottom = latest).
    final newestFirst = chat.messages.reversed.toList();

    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;
    final selfId =
        auth is AuthAuthenticated ? auth.user.id : null;

    // Authoritative detail: internship link + read watermarks for Seen.
    final detailAsync =
        ref.watch(conversationDetailProvider(widget.conversationId));
    final detail = detailAsync.valueOrNull;

    final canRegisterDocuments = role == UserRole.supervisor ||
        role == UserRole.adminSupervisor;

    // Peer read watermark (everyone except me): Messenger Seen source.
    int? peerRead;
    if (detail != null) {
      for (final member in detail.members) {
        if (selfId != null && member.userId == selfId) continue;
        final w = member.lastReadSequenceNumber;
        if (w != null && (peerRead == null || w > peerRead)) {
          peerRead = w;
        }
      }
    }
    // Newest own visible message gets the Seen receipt when covered.
    String? seenMessageId;
    for (final m in newestFirst) {
      if (m.mine && !m.isDeleted) {
        if (peerRead != null &&
            peerRead >= m.sequenceNumber) {
          seenMessageId = m.id;
        }
        break;
      }
    }

    // 1-to-1 actions default to allowed while the detail loads (private
    // threads are the norm); group threads disable them once known.
    final isPrivate = detail?.isPrivate ?? true;
    final allowActions = isPrivate;

    // Flat rows: failed + pending bubbles first (newest-first), then history
    // with a day separator each time the calendar day changes (T07 §14).
    final rows = <Object>[
      for (var i = chat.failed.length - 1; i >= 0; i--)
        chat.failed[i],
      for (var i = chat.pending.length - 1; i >= 0; i--)
        chat.pending[i],
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
        titleSpacing: 0,
        title: _ChatTitle(
          conversationId: widget.conversationId,
          fallback: widget.title,
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.msgMarkRead,
            child: IconButton(
              tooltip: l10n.msgMarkRead,
              icon: const Icon(Icons.done_all_rounded),
              onPressed: _markAsRead,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !chat.initialized
                ? const Center(child: CircularProgressIndicator())
                : chat.initError != null && chat.messages.isEmpty
                    ? _ChatError(
                        message: context
                            .userError(chat.initError!)
                            .message,
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
                                  Icon(Icons.chat_bubble_outline,
                                      size: 44,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(
                                      height: StegSpacing.sm),
                                  Center(
                                      child:
                                          Text(l10n.msgNoHistory)),
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
                                  final msg = row as ChatMessage;
                                  return MessageBubble(
                                    message: msg,
                                    seen: msg.id == seenMessageId,
                                    canRegisterDocuments:
                                        canRegisterDocuments,
                                    onEdit: allowActions &&
                                            msg.mine &&
                                            !msg.isDeleted
                                        ? () => _editMessage(msg)
                                        : null,
                                    onDelete: allowActions &&
                                            msg.mine &&
                                            !msg.isDeleted
                                        ? () =>
                                            _deleteMessage(msg)
                                        : null,
                                    onDocumentRegistered: () {
                                      // Re-read the thread so the kind
                                      // label on the chip stays honest.
                                      ref
                                          .read(chatControllerProvider(
                                                  widget
                                                      .conversationId)
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
            connected: connected,
            onSend: _send,
            // Resolve the conversation's internship authoritatively: the
            // detail fetch first (never a stale list), the list snapshot
            // only as fallback. Without an internship the device pick
            // still works; the document picker hides honestly.
            onAttach: () async {
              String? internshipId = detail?.internshipId;
              internshipId ??= ref
                  .read(conversationsProvider)
                  .valueOrNull
                  ?.where((c) => c.id == widget.conversationId)
                  .map((c) => c.internshipId)
                  .firstOrNull;
              final sent = await showAttachmentSheet(
                context,
                conversationId: widget.conversationId,
                internshipId: internshipId,
              );
              if (sent != null && mounted) {
                ref
                  ..invalidate(conversationsProvider)
                  ..invalidate(
                      totalUnreadMessagesProvider);
                _jumpToBottom();
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Chat title: the OTHER participant's name for 1-to-1 threads (never the
/// raw backend thread title or the viewer's own internship reference),
/// with a connection presence dot on the avatar. Silent by design — no
/// real-time banner; offline simply shows a caption under the name.
class _ChatTitle extends ConsumerWidget {
  const _ChatTitle(
      {required this.conversationId, required this.fallback});

  final String conversationId;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;
    final detailAsync =
        ref.watch(conversationDetailProvider(conversationId));
    final detail = detailAsync.valueOrNull;
    final socket = ref.watch(_socketStateProvider).valueOrNull ??
        ChatConnectionState.disconnected;
    final isOnline = ref.watch(isOnlineProvider);
    final connected =
        socket == ChatConnectionState.connected && isOnline;

    String name = fallback;
    if (detail != null) {
      final dashboard =
          ref.watch(dashboardProvider).valueOrNull;
      final supervised =
          ref.watch(supervisedInternsProvider).valueOrNull;
      name = resolveConversationName(
        conversation: detail,
        role: role,
        l10n: l10n,
        dashboard: dashboard,
        supervised: supervised,
      );
    } else {
      // Detail still loading/offline: best-effort from the list snapshot.
      final fromList = ref
          .watch(conversationsProvider)
          .valueOrNull
          ?.where((c) => c.id == conversationId)
          .firstOrNull;
      if (fromList != null) {
        final dashboard =
            ref.watch(dashboardProvider).valueOrNull;
        final supervised =
            ref.watch(supervisedInternsProvider).valueOrNull;
        name = resolveConversationName(
          conversation: fromList,
          role: role,
          l10n: l10n,
          dashboard: dashboard,
          supervised: supervised,
        );
      }
    }

    final initial =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer,
              foregroundColor: Theme.of(context)
                  .colorScheme
                  .onPrimaryContainer,
              child: Text(initial,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800)),
            ),
            PositionedDirectional(
              end: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFF23A55A)
                      : const Color(0xFF80848E),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color:
                          Theme.of(context).colorScheme.surface,
                      width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              if (!connected)
                Text(l10n.msgOfflineShort,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(
                            alpha: 0.7))),
            ],
          ),
        ),
      ],
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
            : MaterialLocalizations.of(context)
                .formatFullDate(local);
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: StegSpacing.xs),
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
                onPressed: onRetry, child: Text(l10n.retry)),
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
            color: Theme.of(context).colorScheme.primaryContainer,
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
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius:
              BorderRadius.circular(StegSpacing.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(failed.content),
                  Text(l10n.msgFailed,
                      style:
                          Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.msgRetry,
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () {
                final controller = ref.read(
                    chatControllerProvider(conversationId)
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
                  .read(chatControllerProvider(conversationId)
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
    required this.connected,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final bool connected;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            StegSpacing.sm,
            StegSpacing.xs,
            StegSpacing.sm,
            StegSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: l10n.msgAttach,
              child: Container(
                width: StegSpacing.minTouchTarget,
                height: StegSpacing.minTouchTarget,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                      StegSpacing.radiusFull),
                ),
                child: IconButton(
                  tooltip: l10n.msgAttach,
                  icon:
                      const Icon(Icons.add_rounded, size: 24),
                  onPressed: onAttach,
                ),
              ),
            ),
            const SizedBox(width: StegSpacing.xs),
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
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: StegSpacing.md,
                            vertical: StegSpacing.sm),
                  ),
                ),
              ),
            ),
            const SizedBox(width: StegSpacing.xs),
            Semantics(
              button: true,
              label: l10n.msgSend,
              child: Container(
                width: StegSpacing.minTouchTarget,
                height: StegSpacing.minTouchTarget,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0B61A0),
                      Color(0xFF3E9BDC)
                    ],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                  borderRadius: BorderRadius.circular(
                      StegSpacing.radiusFull),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x400B61A0),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white),
                      )
                    : IconButton(
                        tooltip: l10n.msgSend,
                        icon: const Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: Colors.white),
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
