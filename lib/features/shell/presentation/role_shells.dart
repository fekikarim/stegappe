import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/steg_motion.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/role_label.dart';
import '../../community/presentation/screens/community_post_detail_screen.dart';
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
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final current = destinations[index];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF042843), Color(0xFF0B61A0)],
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
            ),
          ),
        ),
        actions: [
          _NotificationBell(onOpenTab: (tab) {
            // The center already popped itself; just switch tabs.
            onIndexChanged(tab);
          }, onOpenCommunityPost: (postId) {
            // The center already popped itself; push the post detail.
            // A removed post renders the honest gone-note inside.
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) =>
                      CommunityPostDetailScreen(postId: postId)),
            );
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
      body: reducedMotion
          ? current.page
          : AnimatedSwitcher(
              duration: StegMotion.shell,
              child: KeyedSubtree(
                key: ValueKey(index),
                child: current.page,
              ),
            ),
      bottomNavigationBar: Semantics(
        label: roleLabel(AppLocalizations.of(context), user.mobileRole),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onIndexChanged,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon ?? d.icon),
                label: d.label,
              ),
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
    this.selectedIcon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final Widget page;
}

/// Notification bell with unread badge → notification center.
/// Badge reads the foreground-refreshed count (socket/resume/pull).
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell(
      {required this.onOpenTab, this.onOpenCommunityPost});

  final ValueChanged<int> onOpenTab;
  final ValueChanged<String>? onOpenCommunityPost;

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
                  builder: (_) => NotificationsScreen(
                      onOpenTab: onOpenTab,
                      onOpenCommunityPost: onOpenCommunityPost)),
            ),
          ),
          if (unread > 0)
            PositionedDirectional(
              top: 6,
              end: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD32325), Color(0xFFFF6B6B)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1)),
                  ],
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
          selectedIcon: Icons.home_rounded,
          page: InternHomeScreen(
            user: widget.user,
            onOpenTab: (i) => setState(() => _index = i),
          ),
        ),
        RoleDestination(
          label: l10n.navTasks,
          icon: Icons.checklist_outlined,
          selectedIcon: Icons.checklist_rounded,
          page: const TaskListScreen(),
        ),
        RoleDestination(
          label: l10n.navJournal,
          icon: Icons.book_outlined,
          selectedIcon: Icons.book_rounded,
          page: const JournalListScreen(),
        ),
        RoleDestination(
          label: l10n.navMessages,
          icon: Icons.chat_bubble_outline,
          selectedIcon: Icons.chat_bubble_rounded,
          page: const ConversationsScreen(),
        ),
        RoleDestination(
          label: l10n.navMore,
          icon: Icons.more_horiz,
          selectedIcon: Icons.more_horiz_rounded,
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
          selectedIcon: Icons.dashboard_rounded,
          page: SupervisorHomeScreen(
            user: widget.user,
            onOpenTab: (i) => setState(() => _index = i),
          ),
        ),
        RoleDestination(
            label: l10n.navInterns,
            icon: Icons.people_outline,
            selectedIcon: Icons.people_rounded,
            page: const SupervisedInternsScreen()),
        RoleDestination(
            label: l10n.navValidations,
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            page: const SupervisorValidationsScreen()),
        RoleDestination(
            label: l10n.navMessages,
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble_rounded,
            page: const ConversationsScreen()),
        RoleDestination(
            label: l10n.navMore,
            icon: Icons.more_horiz,
            selectedIcon: Icons.more_horiz_rounded,
            page: const MoreTab()),
      ],
    );
  }
}
