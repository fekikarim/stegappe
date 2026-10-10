import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../internship/presentation/providers/workspace_providers.dart';
import '../../domain/entities/conversation.dart';
import '../providers/messaging_providers.dart';
import '../widgets/conversation_title.dart';
import 'chat_screen.dart';

/// Conversation list: unread badges, last-message preview, socket +
/// connectivity status. Tapping opens the chat (membership is
/// re-checked server-side on every read).
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(conversationsProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(conversationsProvider)
          ..invalidate(totalUnreadMessagesProvider);
        try {
          await ref.read(conversationsProvider.future);
        } on Exception {
          // Error UI renders via the AsyncValue.
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: StegSpacing.screenPadding,
            sliver: async.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: StegLoading(),
              ),
              error: (e, _) {
                if (!isOnline) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: StegErrorView(
                      message: l10n.offline,
                      onRetry: () =>
                          ref.invalidate(conversationsProvider),
                    ),
                  );
                }
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: StegErrorView(
                    message: context.userError(e).message,
                    onRetry: () =>
                        ref.invalidate(conversationsProvider),
                  ),
                );
              },
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: StegEmptyView(
                      title: l10n.convEmpty,
                      hint: l10n.convEmptyHint,
                      icon: Icons.chat_bubble_outline,
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ConversationTile(
                        conversation: items[i]),
                    childCount: items.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preview = conversation.lastMessage;
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;
    // Friendly 1-to-1 name: the OTHER participant (supervisor for interns,
    // intern for supervisors) — never the raw thread title or a reference.
    final title = resolveConversationName(
      conversation: conversation,
      role: role,
      l10n: l10n,
      dashboard: ref.watch(dashboardProvider).valueOrNull,
      supervised: ref.watch(supervisedInternsProvider).valueOrNull,
    );
    final kindLabel = conversation.isPrivate
        ? l10n.convPrivate
        : l10n.convGroup;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF10293F)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF26465F)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.3
                    : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: conversation.unreadCount > 0
                  ? const [Color(0xFF0B61A0), Color(0xFF3E9BDC)]
                  : [Colors.grey.shade400, Colors.grey.shade300],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
              conversation.isPrivate
                  ? Icons.person_outline_rounded
                  : Icons.group_outlined,
              color: Colors.white),
        ),
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(
                    fontWeight: conversation.unreadCount > 0
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 15)),
        subtitle: Text(
          preview == null
              ? kindLabel
              : preview.isDeleted
                  ? l10n.msgDeleted
                  : preview.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: conversation.unreadCount > 0
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
        // T15: a stacked time-over-badge trailing was taller than the tile
        // and overflowed it by 25 px at 2.0× (measured). One line keeps both
        // values and always fits.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (preview != null)
              Text(
                _timeOfDay(preview.sentAt),
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (conversation.unreadCount > 0)
              Semantics(
                label: '${conversation.unreadCount}',
                child: Container(
                  margin: EdgeInsetsDirectional.only(
                      start: preview == null ? 0 : 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0B61A0),
                        Color(0xFF3E9BDC)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x400B61A0),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    '${conversation.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        onTap: () => Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: conversation.id,
                  title: title,
                ),
              ),
            )
            .then((_) {
          // Viewing marks the thread read server-side: reconcile the
          // list badges + previews on return (Messenger behavior).
          ref
            ..invalidate(conversationsProvider)
            ..invalidate(totalUnreadMessagesProvider);
        }),
        ),
      ),
    );
  }

  /// 24h clock, locale-neutral and unambiguous across fr/en/ar.
  String _timeOfDay(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
