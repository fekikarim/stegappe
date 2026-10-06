import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_colors.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/notification_router.dart';
import '../providers/messaging_providers.dart';
import '../widgets/notification_type_visuals.dart';
import '../widgets/status_labels.dart' show formatDay, priorityLabel;

/// In-app notification center for workflow events (task/journal/
/// evaluation/messaging + internship/finance events).
///
/// T01: typed catalogue (D11) with a distinct icon + localized label per
/// notification type, grouped by day, unread emphasis that never relies on
/// colour alone, mark-one/mark-all with rollback, pull-to-refresh, an honest
/// offline banner over the last known state, and deep links resolved by the
/// pure [resolveNotificationRoute] router.
///
/// Tapping a row marks it read (when unread) and — when its type/entity
/// resolves to a shell tab for the current role — navigates there. A row with
/// no safe destination stays in the center: the tap simply opens its full
/// text, so a deleted related entity never becomes an error screen.
///
/// Push delivery is unavailable: the backend push sender is a no-op stub and
/// no provider credentials are configured (`TODO — push provider`). The center
/// refreshes via deduplicated socket payloads, app resume and pull-to-refresh
/// instead — always foreground-honest.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen(
      {super.key, this.onOpenTab, this.onOpenCommunityPost});

  /// Switch the underlying shell tab, then pop this screen.
  final ValueChanged<int>? onOpenTab;

  /// Push a community post detail, then pop this screen (T08: community
  /// rows have no shell tab — the detail push is their deep link).
  final ValueChanged<String>? onOpenCommunityPost;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  /// In-flight protection for the single optimistic "mark all read" action.
  bool _markingAll = false;

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
      // REST is authoritative on resume: cheap, idempotent, and the only
      // refresh a device without a socket ever gets (acceptance 5).
      ref.read(notificationsControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifTitle),
        actions: [
          if (state.live)
            Tooltip(
              message: l10n.sockLive,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: StegSpacing.sm),
                child: Icon(Icons.bolt, color: StegColors.success, size: 20),
              ),
            ),
          TextButton(
            onPressed: _markingAll ? null : () => _markAllRead(controller),
            child: Text(
              l10n.notifMarkAllRead,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                StegSpacing.md, StegSpacing.sm, StegSpacing.md, 0),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.notifUnreadOnly),
                  selected: state.unreadOnly,
                  onSelected: _markingAll
                      ? null
                      : (value) => controller.setUnreadOnly(value),
                ),
              ],
            ),
          ),
          if (state.offlineCache) _OfflineStrip(label: l10n.notifOfflineCached),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: _body(context, l10n, locale, role, state, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    Locale locale,
    UserRole role,
    NotificationsState state,
    NotificationsController controller,
  ) {
    if (state.loading && state.items.isEmpty) return const StegLoading();

    final failure = state.error;
    if (failure != null && state.items.isEmpty) {
      return StegErrorView(
        message: context.userError(failure).message,
        onRetry: controller.refresh,
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          StegEmptyView(
            title: l10n.notifEmpty,
            hint: l10n.notifWelcomeEmpty,
            icon: Icons.notifications_outlined,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: StegSpacing.screenPadding,
      children: _groupedRows(context, l10n, locale, role, state),
    );
  }

  /// Day-grouped rows: one header per calendar day ("Aujourd'hui" for the
  /// current day, the localized short date otherwise). Rows keep a stable key
  /// per notification id, so a live frame merging into the list never resets
  /// the scroll position (realtime.md: no jump, dedupe by id).
  List<Widget> _groupedRows(
    BuildContext context,
    AppLocalizations l10n,
    Locale locale,
    UserRole role,
    NotificationsState state,
  ) {
    final rows = <Widget>[];
    String? currentGroup;
    final now = DateTime.now();
    for (final n in state.items) {
      final local = n.createdAt.toLocal();
      final group = DateTime(local.year, local.month, local.day);
      final isToday = group.year == now.year &&
          group.month == now.month &&
          group.day == now.day;
      final header = isToday ? l10n.notifToday : formatDay(group, locale);
      if (header != currentGroup) {
        currentGroup = header;
        rows.add(Padding(
          key: ValueKey('notif-group-$header'),
          padding: const EdgeInsets.only(
              top: StegSpacing.sm, bottom: StegSpacing.xxs),
          child: Text(header, style: Theme.of(context).textTheme.titleSmall),
        ));
      }
      rows.add(_row(context, l10n, locale, role, n));
    }
    return rows;
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    Locale locale,
    UserRole role,
    NotificationItem n,
  ) {
    final route = resolveNotificationRoute(n, role);
    // T08 community deep link: no shell tab exists, so a community row
    // with a post id pushes the detail directly (relatedEntityType is
    // always CommunityPost for the three catalogue keys). Without a post
    // id or callback the row stays in the center (fail-safe preserved).
    final communityPostId = _communityPostId(n);
    final communityTarget = communityPostId != null &&
            widget.onOpenCommunityPost != null
        ? communityPostId
        : null;
    final routable = (route != null && widget.onOpenTab != null) ||
        communityTarget != null;
    final unread = !n.isRead;
    final typeLabel = notificationTypeLabel(n.type, l10n);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: Key('notif-${n.id}'),
      child: ListTile(
        leading: Badge(
          isLabelVisible: unread,
          smallSize: 8,
          child: Icon(
            notificationTypeIcon(n.type),
            color: unread ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          n.title.isEmpty ? typeLabel : n.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Unread is never colour-only: weight + badge + the semantic label
          // below carry the same information.
          style: TextStyle(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
            color: unread ? null : scheme.onSurfaceVariant,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n.message,
                maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: StegSpacing.xxs),
            Row(
              children: [
                Semantics(
                  label: unread ? l10n.notifUnreadOnly : typeLabel,
                  child: StegStatusChip(
                    label: typeLabel,
                    kind: notificationTypeKind(n.type),
                  ),
                ),
                const SizedBox(width: StegSpacing.xs),
                Expanded(
                  child: Text(
                    '${formatDay(n.createdAt, locale)} • '
                    '${priorityLabel(n.priority, l10n)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: routable
            ? Semantics(
                button: true,
                label: l10n.notifOpen,
                child: IconButton(
                  tooltip: l10n.notifOpen,
                  icon: const Icon(Icons.arrow_forward_outlined),
                  onPressed: () {
                    final target = communityTarget;
                    if (target != null) {
                      _openCommunity(n, target);
                    } else {
                      _open(n, route!);
                    }
                  },
                ),
              )
            : (unread
                ? TextButton(
                    onPressed: () => _markRead(n),
                    child: Text(l10n.notifMarkRead),
                  )
                : null),
        onTap: routable
            ? () {
                final target = communityTarget;
                if (target != null) {
                  _openCommunity(n, target);
                } else {
                  _open(n, route!);
                }
              }
            : (unread
                ? () => _markRead(n)
                // Read rows have nothing left to do: tapping shows the full,
                // untruncated text (and says honestly when the related content
                // is gone instead of pretending to navigate).
                : () => _showDetail(n, role, l10n)),
        onLongPress: () => _showDetail(n, role, l10n),
      ),
    );
  }

  Future<void> _markAllRead(NotificationsController controller) async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await controller.markAllRead();
      controller.invalidateRelatedCaches();
    } on Exception catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _markRead(NotificationItem n) async {
    try {
      await ref.read(notificationsControllerProvider.notifier).markRead(n);
      ref
          .read(notificationsControllerProvider.notifier)
          .invalidateRelatedCaches();
    } on Exception catch (e) {
      _showError(e);
    }
  }

  /// Mark read (when needed) then route into the shell tab. A failed read flag
  /// is cosmetic and retried on the next sync — it never blocks the deep link.
  Future<void> _open(NotificationItem n, NotificationRoute route) async {
    final controller = ref.read(notificationsControllerProvider.notifier);
    // Localizations are captured before the await so the failure sentence can
    // still be built after the async gap without touching a stale context.
    final l10n = AppLocalizations.of(context);
    String? failure;
    if (!n.isRead) {
      try {
        await controller.markRead(n);
      } on Exception catch (e) {
        failure = userMessageOf(e, l10n);
      }
    }
    if (!mounted) return;
    controller.invalidateRelatedCaches();
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
    }
    Navigator.of(context).pop();
    widget.onOpenTab?.call(route.tab);
  }

  /// Community post id for the three T08 catalogue keys, else null.
  /// The backend always sets relatedEntityType `CommunityPost` with the
  /// post id for these rows (comment removals deep-link to the parent
  /// post); anything else stays in the center.
  String? _communityPostId(NotificationItem n) {
    switch (n.type) {
      case NotificationType.communityComment:
      case NotificationType.communityPostRemoved:
      case NotificationType.communityCommentRemoved:
        final entity = (n.relatedEntityType ?? '').toUpperCase();
        final id = n.relatedEntityId ?? '';
        if (entity == 'COMMUNITYPOST' && id.isNotEmpty) return id;
        return null;
      default:
        return null;
    }
  }

  /// Mark read (when needed), pop, then push the post detail. Same
  /// cosmetic-read rule as [_open]: a failed flag never blocks the link.
  /// A removed post renders the honest gone-note inside the detail.
  Future<void> _openCommunity(NotificationItem n, String postId) async {
    final controller = ref.read(notificationsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    String? failure;
    if (!n.isRead) {
      try {
        await controller.markRead(n);
      } on Exception catch (e) {
        failure = userMessageOf(e, l10n);
      }
    }
    if (!mounted) return;
    controller.invalidateRelatedCaches();
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
    }
    Navigator.of(context).pop();
    widget.onOpenCommunityPost?.call(postId);
  }

  /// Full text of a row (long titles/messages truncate in the list, never
  /// here) plus an honest note when the related content no longer exists.
  void _showDetail(NotificationItem n, UserRole role, AppLocalizations l10n) {
    final route = resolveNotificationRoute(n, role);
    final typeLabel = notificationTypeLabel(n.type, l10n);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              StegSpacing.md, 0, StegSpacing.md, StegSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(notificationTypeIcon(n.type)),
                  const SizedBox(width: StegSpacing.sm),
                  Expanded(
                    child: Text(
                      n.title.isEmpty ? typeLabel : n.title,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StegSpacing.sm),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(n.message.isEmpty ? '—' : n.message),
                ),
              ),
              const SizedBox(height: StegSpacing.sm),
              Wrap(
                spacing: StegSpacing.sm,
                runSpacing: StegSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StegStatusChip(
                    label: typeLabel,
                    kind: notificationTypeKind(n.type),
                  ),
                  Text(
                    '${formatDay(n.createdAt, Localizations.localeOf(context))}'
                    ' • ${priorityLabel(n.priority, l10n)}',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ],
              ),
              if (route == null && n.relatedEntityId != null) ...[
                const SizedBox(height: StegSpacing.sm),
                Text(
                  l10n.notifUnavailable,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
              if (route != null && widget.onOpenTab != null) ...[
                const SizedBox(height: StegSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: StegButton(
                    label: l10n.notifOpen,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _open(n, route);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.userError(error).message)),
    );
  }
}

/// Degraded-state banner: rows on screen are the last known server state —
/// never a silently blank list (UX_UI.md §6.3).
class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: StegColors.warning.withValues(alpha: 0.14),
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md, vertical: StegSpacing.xs),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 16, color: StegColors.warning),
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
