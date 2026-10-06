import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/community.dart';
import '../providers/community_providers.dart';
import 'community_moderation_sheets.dart';
import '../widgets/community_cards.dart';

/// One post with its thread (T08): chronological comments, optimistic
/// comment composer, report/delete/remove/mute menus, and an honest
/// "no longer available" view when the post was removed while reading.
///
/// Opened from the feed or pushed from a community notification deep link
/// (`onOpenCommunityPost`); a 404 renders `communityRemovedGone`, never a
/// crash — deleted content fails safely by construction.
class CommunityPostDetailScreen extends ConsumerStatefulWidget {
  const CommunityPostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState
    extends ConsumerState<CommunityPostDetailScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _composer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(communityPostDetailProvider(widget.postId).notifier)
          .resync();
    }
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _composer.clear();
    try {
      await ref
          .read(communityPostDetailProvider(widget.postId).notifier)
          .addComment(text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state =
        ref.watch(communityPostDetailProvider(widget.postId));
    final isOnline = ref.watch(isOnlineProvider);
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;
    final canWrite = communityCanWrite(role);
    final canModerate = communityCanModerate(role);

    ref.listen<CommunityPostDetailState>(
        communityPostDetailProvider(widget.postId), (previous, next) {
      if (next.actionError != null &&
          next.actionError != previous?.actionError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(context.userError(next.actionError!).message)));
        ref
            .read(communityPostDetailProvider(widget.postId).notifier)
            .clearActionError();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityComments)),
      body: Column(
        children: [
          if (!isOnline)
            _DetailOfflineStrip(label: l10n.offline)
          else if (state.offlineCache)
            _DetailOfflineStrip(
                label: l10n.notifOfflineCached),
          Expanded(
            child: !state.initialized
                ? const Center(child: StegLoading())
                : state.initError != null && state.post == null
                    ? _RemovedView(
                        error: state.initError!,
                        onRetry: () => ref
                            .read(communityPostDetailProvider(
                                    widget.postId)
                                .notifier)
                            .retryInitial(),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(communityPostDetailProvider(
                                    widget.postId)
                                .notifier)
                            .resync(),
                        child: _ThreadBody(
                          state: state,
                          canModerate: canModerate,
                          postId: widget.postId,
                        ),
                      ),
          ),
          if (state.post != null && canWrite)
            _CommentComposer(
              controller: _composer,
              sending: _sending,
              enabled: isOnline,
              offlineLabel:
                  isOnline ? null : l10n.communityNeedsConnection,
              onSend: _send,
            ),
        ],
      ),
    );
  }
}

class _DetailOfflineStrip extends StatelessWidget {
  const _DetailOfflineStrip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        color:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md,
            vertical: StegSpacing.xs),
        child: Row(
          children: [
            const Icon(Icons.sync_outlined, size: 14),
            const SizedBox(width: StegSpacing.xs),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// 404 (removed/deleted/unknown) renders the honest gone-note with retry
/// — deleted content fails safely, never as an error screen.
class _RemovedView extends StatelessWidget {
  const _RemovedView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userError = context.userError(error);
    final gone = error is ApiException &&
        (error as ApiException).kind == ApiErrorKind.notFound;
    return Center(
      child: Padding(
        padding: StegSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                gone
                    ? Icons.forum_outlined
                    : Icons.error_outline,
                size: 44,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant),
            const SizedBox(height: StegSpacing.sm),
            Text(
                gone
                    ? l10n.communityRemovedGone
                    : userError.message,
                textAlign: TextAlign.center),
            const SizedBox(height: StegSpacing.sm),
            StegButton(
                label: l10n.retry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _ThreadBody extends ConsumerWidget {
  const _ThreadBody({
    required this.state,
    required this.canModerate,
    required this.postId,
  });

  final CommunityPostDetailState state;
  final bool canModerate;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final post = state.post!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          StegSpacing.sm,
          StegSpacing.sm,
          StegSpacing.sm,
          StegSpacing.lg),
      children: [
        CommunityPostCard(
          post: post,
          menuItems: _postMenu(context, ref, post, canModerate),
        ),
        const SizedBox(height: StegSpacing.sm),
        Text(l10n.communityComments,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: StegSpacing.xs),
        if (state.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: StegSpacing.md),
            child: Text(l10n.communityNoComments,
                style: Theme.of(context).textTheme.bodySmall),
          )
        else
          for (final c in state.comments)
            CommunityCommentTile(
              comment: c,
              menuItems: _commentMenu(
                  context, ref, post, c, canModerate),
            ),
      ],
    );
  }

  List<CommunityMenuAction> _postMenu(
    BuildContext context,
    WidgetRef ref,
    CommunityPost post,
    bool canModerate,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller =
        ref.read(communityPostDetailProvider(postId).notifier);
    final repo = ref.watch(communityRepositoryProvider);
    final items = <CommunityMenuAction>[];
    if (post.mine) {
      items.add(CommunityMenuAction(
        label: l10n.communityDelete,
        icon: Icons.delete_outline,
        destructive: true,
        onSelected: () async {
          final confirmed = await showStegConfirmDialog(context,
              title: l10n.communityDelete,
              message: l10n.communityDeleteConfirm,
              confirmLabel: l10n.communityDelete,
              destructive: true);
          if (confirmed && context.mounted) {
            try {
              await controller.deletePost(post.id);
            } on Exception {
              // Surfaced through actionError (snackbar); stay put.
              return;
            }
            if (context.mounted) Navigator.of(context).pop();
          }
        },
      ));
    } else {
      items.add(CommunityMenuAction(
        label: l10n.communityReport,
        icon: Icons.flag_outlined,
        onSelected: () => showCommunityReportSheet(context,
            targetLabel: post.authorDisplayName,
            onSubmit: (reason) =>
                repo.reportPost(post.id, reason)),
      ));
    }
    if (canModerate && !post.mine) {
      items.add(CommunityMenuAction(
        label: l10n.communityRemove,
        icon: Icons.delete_outline,
        destructive: true,
        onSelected: () => showCommunityRemoveSheet(context,
            onSubmit: (reason) async {
              try {
                await controller.deletePost(post.id,
                    reason: reason);
              } on Exception {
                return;
              }
              if (context.mounted) Navigator.of(context).pop();
            }),
      ));
      items.add(CommunityMenuAction(
        label: l10n.communityMute,
        icon: Icons.volume_off_outlined,
        destructive: true,
        onSelected: () => showCommunityMuteSheet(context,
            userLabel: post.authorDisplayName,
            onSubmit: (minutes, reason) => repo.muteStudent(
                userId: post.authorId,
                minutes: minutes,
                reason: reason)),
      ));
    }
    return items;
  }

  List<CommunityMenuAction> _commentMenu(
    BuildContext context,
    WidgetRef ref,
    CommunityPost post,
    CommunityComment comment,
    bool canModerate,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller =
        ref.read(communityPostDetailProvider(postId).notifier);
    final repo = ref.watch(communityRepositoryProvider);
    if (comment.pending) return const [];
    final items = <CommunityMenuAction>[];
    if (comment.mine) {
      items.add(CommunityMenuAction(
        label: l10n.communityDelete,
        icon: Icons.delete_outline,
        destructive: true,
        onSelected: () async {
          final confirmed = await showStegConfirmDialog(context,
              title: l10n.communityDelete,
              message: l10n.communityDeleteConfirm,
              confirmLabel: l10n.communityDelete,
              destructive: true);
          if (confirmed) {
            await controller.deleteComment(comment.id);
          }
        },
      ));
    } else {
      items.add(CommunityMenuAction(
        label: l10n.communityReport,
        icon: Icons.flag_outlined,
        onSelected: () => showCommunityReportSheet(context,
            targetLabel: comment.authorDisplayName,
            onSubmit: (reason) =>
                repo.reportComment(comment.id, reason)),
      ));
    }
    if (canModerate && !comment.mine) {
      items.add(CommunityMenuAction(
        label: l10n.communityRemove,
        icon: Icons.delete_outline,
        destructive: true,
        onSelected: () => showCommunityRemoveSheet(context,
            onSubmit: (reason) => controller.deleteComment(
                comment.id,
                reason: reason)),
      ));
      items.add(CommunityMenuAction(
        label: l10n.communityMute,
        icon: Icons.volume_off_outlined,
        destructive: true,
        onSelected: () => showCommunityMuteSheet(context,
            userLabel: comment.authorDisplayName,
            onSubmit: (minutes, reason) => repo.muteStudent(
                userId: comment.authorId,
                minutes: minutes,
                reason: reason)),
      ));
    }
    return items;
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
    this.offlineLabel,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;
  final String? offlineLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offlineLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: StegSpacing.md),
              child: Text(offlineLabel!,
                  style: TextStyle(
                      color:
                          Theme.of(context).colorScheme.error)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(StegSpacing.sm,
                StegSpacing.xs, StegSpacing.sm, StegSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: l10n.communityAddComment,
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      enabled: enabled && !sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: l10n.communityAddComment,
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
                  label: l10n.communityPublish,
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
                            tooltip: l10n.communityPublish,
                            icon: const Icon(
                                Icons.send_outlined),
                            onPressed:
                                enabled ? onSend : null,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
