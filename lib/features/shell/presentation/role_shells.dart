import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/connectivity_banner.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'more_tab.dart';
import 'placeholder_tab.dart';

/// Bottom-navigation scaffold shared by both roles. Uses only
/// directional widgets (AlignmentDirectional/EdgeInsetsDirectional via
/// Material bottom nav) so Arabic mirrors automatically.
class RoleScaffold extends ConsumerStatefulWidget {
  const RoleScaffold({
    super.key,
    required this.user,
    required this.destinations,
  });

  final AppUser user;
  final List<RoleDestination> destinations;

  @override
  ConsumerState<RoleScaffold> createState() => _RoleScaffoldState();
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

class _RoleScaffoldState extends ConsumerState<RoleScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final current = widget.destinations[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        actions: [
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
                      key: ValueKey(_index),
                      child: current.page,
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Semantics(
        label: widget.user.mobileRole == UserRole.intern
            ? AppLocalizations.of(context).roleIntern
            : AppLocalizations.of(context).roleSupervisor,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final d in widget.destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      ),
    );
  }
}

/// INTERN shell (UI_UX.md §12.2): Home / Tasks / Journal / Messages / More.
class InternShell extends StatelessWidget {
  const InternShell({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RoleScaffold(
      user: user,
      destinations: [
        RoleDestination(
            label: l10n.navHome,
            icon: Icons.home_outlined,
            page: PlaceholderTab(
                title: l10n.navHome, icon: Icons.home_outlined)),
        RoleDestination(
            label: l10n.navTasks,
            icon: Icons.checklist_outlined,
            page: PlaceholderTab(
                title: l10n.navTasks,
                icon: Icons.checklist_outlined)),
        RoleDestination(
            label: l10n.navJournal,
            icon: Icons.book_outlined,
            page: PlaceholderTab(
                title: l10n.navJournal, icon: Icons.book_outlined)),
        RoleDestination(
            label: l10n.navMessages,
            icon: Icons.chat_bubble_outline,
            page: PlaceholderTab(
                title: l10n.navMessages,
                icon: Icons.chat_bubble_outline)),
        RoleDestination(
            label: l10n.navMore,
            icon: Icons.more_horiz,
            page: const MoreTab()),
      ],
    );
  }
}

/// SUPERVISOR shell: Overview / Interns / Validations / Messages / More.
class SupervisorShell extends StatelessWidget {
  const SupervisorShell({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RoleScaffold(
      user: user,
      destinations: [
        RoleDestination(
            label: l10n.navHome,
            icon: Icons.dashboard_outlined,
            page: PlaceholderTab(
                title: l10n.navHome,
                icon: Icons.dashboard_outlined)),
        RoleDestination(
            label: l10n.navInterns,
            icon: Icons.people_outline,
            page: PlaceholderTab(
                title: l10n.navInterns,
                icon: Icons.people_outline)),
        RoleDestination(
            label: l10n.navValidations,
            icon: Icons.fact_check_outlined,
            page: PlaceholderTab(
                title: l10n.navValidations,
                icon: Icons.fact_check_outlined)),
        RoleDestination(
            label: l10n.navMessages,
            icon: Icons.chat_bubble_outline,
            page: PlaceholderTab(
                title: l10n.navMessages,
                icon: Icons.chat_bubble_outline)),
        RoleDestination(
            label: l10n.navMore,
            icon: Icons.more_horiz,
            page: const MoreTab()),
      ],
    );
  }
}
