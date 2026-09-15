import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/steg_states.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/screens/login_screen.dart';
import '../../auth/presentation/screens/splash_screen.dart';
import 'role_shells.dart';

/// Role-aware entry point. Routes by backend-issued role claims;
/// unsupported staff roles get an explicit access-denied state.
/// Client routing is UX convenience — backend re-authorizes everything.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(authControllerProvider.notifier).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return switch (state) {
      AuthInitial() || AuthLoading() => const SplashScreen(),
      AuthUnauthenticated() => const LoginScreen(),
      AuthAuthenticated(:final user) => switch (user.mobileRole) {
          UserRole.intern => InternShell(user: user),
          UserRole.supervisor => SupervisorShell(user: user),
          UserRole.unsupported => const UnsupportedRoleScreen(),
        },
    };
  }
}

class UnsupportedRoleScreen extends ConsumerWidget {
  const UnsupportedRoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: StegEmptyView(
        title: l10n.unsupportedRole,
        icon: Icons.lock_outline,
        actionLabel: l10n.logout,
        onAction: () =>
            ref.read(authControllerProvider.notifier).logout(),
      ),
    );
  }
}
