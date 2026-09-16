import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/connectivity_banner.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../internship/presentation/screens/intern_home_screen.dart';
import '../../internship/presentation/screens/journal_list_screen.dart';
import '../../internship/presentation/screens/supervised_interns_screen.dart';
import '../../internship/presentation/screens/supervisor_home_screen.dart';
import '../../internship/presentation/screens/supervisor_validations_screen.dart';
import '../../internship/presentation/screens/task_list_screen.dart';
import '../../messaging/presentation/providers/messaging_providers.dart';
import '../../messaging/presentation/screens/conversations_screen.dart';
import '../../messaging/presentation/screens/notifications_screen.dart';
import 'more_tab.dart';

/// Bottom-navigation scaffold shared by both roles. Uses only
/// directional widgets (AlignmentDirectional/EdgeInsetsDirectional via
/// Material bottom nav) so Arabic mirrors automatically.
class RoleScaffold extends ConsumerWidget {
  const RoleScaffold({
    super.key,
    required this.user,
    required this.destinations,
    required this.index,
    required this.onIndexChanged,
  });

  final AppUser user;
  final List<RoleDestination> destinations;
  final int index;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final current = destinations[index];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        actions: [
          _NotificationBell(onOpenTab: (tab) {
            // The center already popped itself; just switch tabs.
            onIndexChanged(tab);
          }),
          Semantics(
            label: AppLocalizations.of(context).logout,
            button: true,
            child: IconButton(
              tooltip: AppLocalizations.of(context).logout,
              icon: const Icon(Icons.logout_outlined),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectivityBanner(isOnline: isOnline),
          Expanded(
            child: reducedMotion
                ? current.page
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(
                      key: ValueKey(index),
                      child: current.page,
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Semantics(
        label: user.mobileRole == UserRole.intern
            ? AppLocalizations.of(context).roleIntern
            : AppLocalizations.of(context).roleSupervisor,
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onIndexChanged,
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      ),
    );
  }
}

class RoleDestination {
  const RoleDestination({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}

/// Notification bell with unread badge → notification center.
/// Badge reads the foreground-refreshed count (socket/resume/pull).
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unreadAsync = ref.watch(unreadNotificationsProvider);
    final unread = unreadAsync.valueOrNull ?? 0;
    return Semantics(
      button: true,
      label: '${l10n.notifTitle}, $unread',
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          IconButton(
            tooltip: l10n.notifTitle,
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) =>
                      NotificationsScreen(onOpenTab: onOpenTab)),
            ),
          ),
          if (unread > 0)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onError,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// INTERN shell (UI_UX.md §12.2): Home / Tasks / Journal / Messages / More.
class InternShell extends StatefulWidget {
  const InternShell({super.key, required this.user});

  final AppUser user;

  @override
  State<InternShell> createState() => _InternShellState();
}

class _InternShellState extends State<InternShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RoleScaffold(
      user: widget.user,
      index: _index,
      onIndexChanged: (i) => setState(() => _index = i),
      destinations: [
        RoleDestination(
          label: l10n.navHome,
          icon: Icons.home_outlined,
          page: InternHomeScreen(
            user: widget.user,
            onOpenTab: (i) => setState(() => _index = i),
          ),
        ),
        RoleDestination(
          label: l10n.navTasks,
          icon: Icons.checklist_outlined,
          page: const TaskListScreen(),
        ),
        RoleDestination(
          label: l10n.navJournal,
          icon: Icons.book_outlined,
          page: const JournalListScreen(),
        ),
        RoleDestination(
          label: l10n.navMessages,
          icon: Icons.chat_bubble_outline,
          page: const ConversationsScreen(),
        ),
        RoleDestination(
          label: l10n.navMore,
          icon: Icons.more_horiz,
          page: const MoreTab(),
        ),
      ],
    );
  }
}

/// SUPERVISOR shell: Overview / Interns / Validations / Messages / More.
/// Supervisor workspace lands in D4; placeholders keep navigation honest.
class SupervisorShell extends StatefulWidget {
  const SupervisorShell({super.key, required this.user});

  final AppUser user;

  @override
  State<SupervisorShell> createState() => _SupervisorShellState();
}

class _SupervisorShellState extends State<SupervisorShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RoleScaffold(
      user: widget.user,
      index: _index,
      onIndexChanged: (i) => setState(() => _index = i),
      destinations: [
        RoleDestination(
          label: l10n.navHome,
          icon: Icons.dashboard_outlined,
          page: SupervisorHomeScreen(
            onOpenTab: (i) => setState(() => _index = i),
          ),
        ),
        RoleDestination(
            label: l10n.navInterns,
            icon: Icons.people_outline,
            page: const SupervisedInternsScreen()),
        RoleDestination(
            label: l10n.navValidations,
            icon: Icons.fact_check_outlined,
            page: const SupervisorValidationsScreen()),
        RoleDestination(
            label: l10n.navMessages,
            icon: Icons.chat_bubble_outline,
            page: const ConversationsScreen()),
        RoleDestination(
            label: l10n.navMore,
            icon: Icons.more_horiz,
            page: const MoreTab()),
      ],
    );
  }
}
