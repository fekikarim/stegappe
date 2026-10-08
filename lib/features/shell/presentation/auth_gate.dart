import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/settings_providers.dart';
import '../../../core/offline/pending_writes.dart';
import '../../../core/widgets/steg_states.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/screens/login_screen.dart';
import '../../auth/presentation/screens/splash_screen.dart';
import '../../auth/presentation/screens/change_password_screen.dart';
import '../../internship/presentation/providers/assistant_providers.dart';
import '../../messaging/presentation/providers/messaging_providers.dart';
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
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (prev, next) {
      if (next is AuthUnauthenticated) {
        // Tear down the socket on logout; a fresh service (and fresh
        // subscriptions) is created on next login.
        ref.read(stompChatServiceProvider).disconnect().catchError((_) {});
        ref.invalidate(stompChatServiceProvider);
        // T06 §10/§11: the queue belongs to the signed-in user — wipe it so
        // no write leaks into the next session (silent: leaving is no error).
        ref.read(pendingWritesProvider.notifier).clear().catchError((_) {});
        // T11: same rule for the local assistant history — one user's
        // questions must never leak into the next session on a shared
        // device. The controller is reset so its memory follows the store.
        final signedOut = prev is AuthAuthenticated ? prev.user : null;
        if (signedOut != null) {
          ref
              .read(assistantHistoryStoreProvider)
              .clear(signedOut.id)
              .catchError((_) {});
        }
        ref.invalidate(assistantControllerProvider);
        // T14: the language choice is a per-account preference on the server
        // (`PUT /api/users/me/locale`), so the device copy must not outlive
        // the session — otherwise the next account on a shared device is
        // rendered in the previous user's language.
        ref.read(localeProvider.notifier).resetToDeviceDefault();
      }
    });
    if (state is AuthAuthenticated) {
      // Foreground socket sync for the whole session (notifications +
      // unread badges). Idempotent: provider boots subscriptions once.
      ref.watch(foregroundSyncProvider);
      if (state.user.mustChangePassword) return const ChangePasswordScreen();
    }
    return switch (state) {
      AuthInitial() || AuthLoading() => const SplashScreen(),
      AuthUnauthenticated() => const LoginScreen(),
      // Admin-as-supervisor (D1) reuses the supervisor shell: the backend
      // scopes "my students" from the supervision link, and no admin-only
      // staff module is reachable from here (BR-07).
      AuthAuthenticated(:final user) => switch (user.mobileRole) {
        UserRole.intern => InternShell(user: user),
        UserRole.supervisor || UserRole.adminSupervisor =>
          SupervisorShell(user: user),
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
        onAction: () => ref.read(authControllerProvider.notifier).logout(),
      ),
    );
  }
}
