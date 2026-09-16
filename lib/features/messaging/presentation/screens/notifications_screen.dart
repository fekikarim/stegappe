import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/network/paged.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/notification_item.dart';
import '../providers/messaging_providers.dart';
import '../widgets/status_labels.dart'
    show formatDay, priorityLabel;

/// In-app notification center for workflow events (task/journal/
/// evaluation/messaging + internship/finance events).
///
/// Tapping a notification marks it read and — when its related entity
/// maps to a tab for the current role — navigates there (in-app only;
/// the app defines no OS deep-link scheme).
/// Push delivery is unavailable: the backend push sender is a no-op
/// stub and no provider credentials are configured
/// (`TODO — push provider`). The center refreshes via socket payloads,
/// app resume, and pull-to-refresh instead — always foreground-honest.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.onOpenTab});

  /// Switch the underlying shell tab, then pop this screen.
  final ValueChanged<int>? onOpenTab;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver {
  bool _unreadOnly = false;

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
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(_filteredProvider(_unreadOnly));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifTitle),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(notificationRepositoryProvider)
                    .markAllRead();
                ref
                  ..invalidate(notificationsProvider)
                  ..invalidate(unreadNotificationsProvider);
              } on Exception catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e is ApiException
                          ? e.message
                          : e.toString()),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.notifMarkAllRead,
                style: const TextStyle(color: Colors.white)),
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
                  selected: _unreadOnly,
                  onSelected: (v) =>
                      setState(() => _unreadOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref
                  ..invalidate(notificationsProvider)
                  ..invalidate(unreadNotificationsProvider);
                try {
                  await ref.read(notificationsProvider.future);
                } on Exception {
                  // Error UI renders via the AsyncValue.
                }
              },
              child: async.when(
                loading: () => const StegLoading(),
                error: (e, _) => StegErrorView(
                  message:
                      e is ApiException ? e.message : e.toString(),
                  onRetry: () =>
                      ref.invalidate(notificationsProvider),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        StegEmptyView(
                          title: l10n.notifEmpty,
                          icon: Icons.notifications_outlined,
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: StegSpacing.screenPadding,
                    itemCount: page.items.length,
                    itemBuilder: (ctx, i) {
                      final n = page.items[i];
                      final auth = ref.watch(authControllerProvider);
                      final role = auth is AuthAuthenticated
                          ? auth.user.mobileRole
                          : UserRole.unsupported;
                      final target =
                          _tabFor(n.relatedEntityType, role);
                      final routable = target != null &&
                          widget.onOpenTab != null;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            n.isRead
                                ? Icons.notifications_outlined
                                : Icons
                                    .notifications_active_outlined,
                          ),
                          title: Text(
                              n.title.isEmpty ? '—' : n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${n.message}\n${formatDay(n.createdAt, locale)} • ${priorityLabel(n.priority, l10n)}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: routable
                              ? Semantics(
                                  button: true,
                                  label: l10n.notifOpen,
                                  child: IconButton(
                                    tooltip: l10n.notifOpen,
                                    icon: const Icon(Icons
                                        .arrow_forward_outlined),
                                    onPressed: () => _open(
                                        context,
                                        ref,
                                        n,
                                        target),
                                  ),
                                )
                              : (n.isRead
                                  ? null
                                  : TextButton(
                                      onPressed: () =>
                                          _markRead(
                                              context,
                                              ref,
                                              n),
                                      child: Text(l10n
                                          .notifMarkRead),
                                    )),
                          onTap: routable
                              ? () => _open(
                                  context, ref, n, target)
                              : (n.isRead
                                  ? null
                                  : () => _markRead(
                                      context, ref, n)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markRead(
      BuildContext context, WidgetRef ref, NotificationItem n) async {
    try {
      await ref
          .read(notificationRepositoryProvider)
          .markRead(n.id);
      ref
        ..invalidate(notificationsProvider)
        ..invalidate(unreadNotificationsProvider);
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e is ApiException ? e.message : e.toString()),
          ),
        );
      }
    }
  }

  /// Mark read (when needed) then route into the shell tab. Unknown
  /// entity types stay in the center — never a dead tap.
  Future<void> _open(BuildContext context, WidgetRef ref,
      NotificationItem n, int tab) async {
    if (!n.isRead) {
      try {
        await ref
            .read(notificationRepositoryProvider)
            .markRead(n.id);
        ref
          ..invalidate(notificationsProvider)
          ..invalidate(unreadNotificationsProvider);
      } on Exception catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e is ApiException
                  ? e.message
                  : e.toString()),
            ),
          );
          return;
        }
      }
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    widget.onOpenTab?.call(tab);
  }
}

/// Backend event vocabulary → shell tab per role. Unknown types map to
/// null (stay in the center) rather than a wrong destination.
int? _tabFor(String? entity, UserRole role) {
  final t = (entity ?? '').toUpperCase();
  return switch (role) {
    UserRole.intern => switch (t) {
        'TASK' => 1,
        'JOURNALENTRY' => 2,
        'CONVERSATION' || 'MESSAGE' => 3,
        _ => null,
      },
    UserRole.supervisor => switch (t) {
        'TASK' || 'JOURNALENTRY' || 'DELIVERABLE' => 2,
        'CONVERSATION' || 'MESSAGE' => 3,
        'INTERNSHIP' => 1,
        _ => null,
      },
    UserRole.unsupported => null,
  };
}

final _filteredProvider = FutureProvider.family<
    Paged<NotificationItem>, bool>((ref, unreadOnly) async {
  final repo = ref.watch(notificationRepositoryProvider);
  // Reuse the shared page provider for the default view so socket
  // invalidations refresh both; filtered view fetches directly.
  if (!unreadOnly) return ref.watch(notificationsProvider.future);
  return repo.list(unreadOnly: true);
});
