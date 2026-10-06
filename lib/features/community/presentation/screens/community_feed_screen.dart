import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/community.dart';
import '../providers/community_providers.dart';
import 'community_composer_sheet.dart';
import 'community_moderation_sheets.dart';
import 'community_post_detail_screen.dart';
import 'community_reports_screen.dart';
import '../widgets/community_cards.dart';

/// Student community feed (T08 / ST-COM-01/02): newest-first server feed
/// with keyset pagination, pull-to-refresh, optimistic posts, report and
/// moderation menus, and honest offline/empty/error states.
///
/// Entry points: student home quick action + More-tab card (both roles);
/// supervisors additionally reach the reports queue from here and More.
class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() =>
      _CommunityFeedScreenState();
}

class _CommunityFeedScreenState
    extends ConsumerState<CommunityFeedScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(communityFeedProvider.notifier).resync();
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 300) {
      ref
          .read(communityFeedProvider.notifier)
          .loadMore()
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final feed = ref.watch(communityFeedProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;
    final canWrite = communityCanWrite(role);
    final canModerate = communityCanModerate(role);

    ref.listen<CommunityFeedState>(communityFeedProvider,
        (previous, next) {
      if (next.actionError != null &&
          next.actionError != previous?.actionError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(context.userError(next.actionError!).message)));
        ref.read(communityFeedProvider.notifier).clearActionError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.communityTitle),
        actions: [
          if (canModerate)
            Semantics(
              button: true,
              label: l10n.communityReports,
              child: IconButton(
                tooltip: l10n.communityReports,
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const CommunityReportsScreen()),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: canWrite
          ? Semantics(
              button: true,
              label: l10n.communityPublish,
              child: FloatingActionButton(
                tooltip: l10n.communityPublish,
                onPressed: isOnline
                    ? () => showCommunityComposer(context)
                    : null,
                child: const Icon(Icons.add_outlined),
              ),
            )
          : null,
      body: Column(
        children: [
          if (!isOnline)
            _OfflineStrip(label: l10n.offline)
          else if (feed.offlineCache)
            _OfflineStrip(label: l10n.notifOfflineCached),
          Expanded(
            child: !feed.initialized
                ? const Center(child: StegLoading())
                : feed.initError != null && feed.posts.isEmpty
                    ? _FeedError(
                        message: context
                            .userError(feed.initError!)
                            .message,
                        onRetry: () => ref
                            .read(communityFeedProvider.notifier)
                            .retryInitial(),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(communityFeedProvider.notifier)
                            .resync(),
                        child: _FeedList(
                          feed: feed,
                          scroll: _scroll,
                          canWrite: canWrite,
                          canModerate: canModerate,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip({required this.label});

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

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

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

class _FeedList extends ConsumerWidget {
  const _FeedList({
    required this.feed,
    required this.scroll,
    required this.canWrite,
    required this.canModerate,
  });

  final CommunityFeedState feed;
  final ScrollController scroll;
  final bool canWrite;
  final bool canModerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(communityFeedProvider.notifier);

    if (feed.posts.isEmpty && feed.failed.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: StegSpacing.screenPadding,
        children: [
          const SizedBox(height: 80),
          StegEmptyView(
            title: l10n.communityEmpty,
            hint: l10n.communityEmptyHint,
            icon: Icons.forum_outlined,
            actionLabel:
                canWrite ? l10n.communityPublish : null,
            onAction: canWrite
                ? () => showCommunityComposer(context)
                : null,
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          StegSpacing.sm,
          StegSpacing.sm,
          StegSpacing.sm,
          StegSpacing.lg),
      itemCount: feed.failed.length +
          feed.posts.length +
          (feed.hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < feed.failed.length) {
          final failed = feed.failed[i];
          return CommunityPostCard(
            post: CommunityPost(
              id: failed.localId,
              authorId: '',
              authorDisplayName: '',
              body: failed.body,
              status: CommunityContentStatus.visible,
              commentCount: 0,
              createdAt: failed.at,
              mine: true,
            ),
            failed: true,
            onRetry: () {
              controller.discardFailed(failed);
              showCommunityComposer(context,
                  initialText: failed.body,
                  initialBytes: failed.bytes,
                  initialFileName: failed.fileName,
                  initialContentType: failed.contentType,
                  idempotencyKey: failed.localId);
            },
          );
        }
        final pi = i - feed.failed.length;
        if (pi >= feed.posts.length) {
          if (!feed.loadingMore) return const SizedBox.shrink();
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2))),
          );
        }
        final post = feed.posts[pi];
        return Padding(
          padding: const EdgeInsets.only(bottom: StegSpacing.xs),
          child: CommunityPostCard(
            post: post,
            onOpen: post.pending
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => CommunityPostDetailScreen(
                              postId: post.id)),
                    ),
            menuItems:
                _menuItems(context, ref, post, canModerate),
          ),
        );
      },
    );
  }

  List<CommunityMenuAction> _menuItems(
    BuildContext context,
    WidgetRef ref,
    CommunityPost post,
    bool canModerate,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(communityFeedProvider.notifier);
    final repo = ref.watch(communityRepositoryProvider);
    if (post.pending) return const [];
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
          if (confirmed) {
            await controller.deletePost(post.id);
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
            onSubmit: (reason) =>
                controller.deletePost(post.id, reason: reason)),
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
}
