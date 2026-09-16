import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../domain/entities/conversation.dart';
import '../providers/messaging_providers.dart';
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
                    message:
                        e is ApiException ? e.message : e.toString(),
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = conversation.lastMessage;
    final kindLabel = conversation.isPrivate
        ? l10n.convPrivate
        : l10n.convGroup;
    final title = conversation.title.isEmpty
        ? kindLabel
        : conversation.title;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(conversation.isPrivate
              ? Icons.person_outline
              : Icons.group_outlined),
        ),
        title: Text(title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          preview == null
              ? kindLabel
              : preview.isDeleted
                  ? l10n.msgDeleted
                  : preview.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (preview != null)
              Text(
                _timeOfDay(preview.sentAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (conversation.unreadCount > 0)
              Semantics(
                label: '${conversation.unreadCount}',
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${conversation.unreadCount}',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversation.id,
              title: title,
            ),
          ),
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
