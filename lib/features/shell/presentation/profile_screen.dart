import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/network/error_messages.dart';
import '../../../core/theme/steg_spacing.dart';
import '../../../core/widgets/steg_card.dart';
import '../../../core/widgets/steg_fields.dart';
import '../../../core/widgets/steg_states.dart';
import '../../../core/widgets/steg_status_chip.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/role_label.dart';
import '../../auth/presentation/screens/change_password_screen.dart';
import '../../internship/presentation/providers/workspace_providers.dart';
import '../../internship/presentation/widgets/status_labels.dart';

/// Read-only identity screen (T14 SH-SET-01/SH-PRO-01).
///
/// There is no server-side profile update capability for any field
/// (no intern/supervisor self-service endpoint exists), so every field
/// renders explicitly read-only — editability is never faked. Identity
/// comes from JWT claims plus the internship payload; CIN, passwords and
/// tokens never enter the widget tree (BR-59).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: StegErrorView(
          message: l10n.errSessionExpired,
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: StegSpacing.screenPadding,
        children: [
          _IdentityCard(user: user),
          const SizedBox(height: StegSpacing.md),
          if (user.mobileRole == UserRole.intern)
            _InternshipCard()
          else
            _SupervisedCountCard(),
          const SizedBox(height: StegSpacing.md),
          StegCard(
            title: l10n.accountTitle,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: Text(l10n.profileChangePassword),
              trailing: const Icon(Icons.arrow_forward_outlined),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar + name + email + role. The user id (UUID) is deliberately not
/// shown: it carries no meaning for the user and stays out of screenshots.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StegCard(
      title: l10n.profileTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(displayName: user.email, radius: 28),
              const SizedBox(width: StegSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      // T15/RTL: an email is an LTR technical run; inside an
                      // RTL paragraph it must be isolated or it reverses.
                      child: BidiText(user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium),
                    ),
                    const SizedBox(height: StegSpacing.xxs),
                    StegStatusChip(
                        label: roleLabel(l10n, user.mobileRole)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: StegSpacing.sm),
          Text(l10n.profileReadOnly,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Intern's linked internship (reference, period, status): read-only facts
/// from the scoped internship payload. No linked internship renders
/// nothing — the identity above already covers that case.
class _InternshipCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final detailAsync = ref.watch(internshipDetailProvider);
    return detailAsync.when(
      loading: () => const StegLoading(),
      error: (e, _) {
        if (e is StateError && e.message == 'no-internship') {
          return const SizedBox.shrink();
        }
        return Text(context.userError(e).message,
            style:
                TextStyle(color: Theme.of(context).colorScheme.error));
      },
      data: (internship) => StegCard(
        title: l10n.profileInternship,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: StegSpacing.xs,
              runSpacing: StegSpacing.xs,
              children: [
                StegStatusChip(
                  label:
                      internshipStatusLabel(internship.status, l10n),
                  kind: internshipStatusKind(internship.status),
                ),
                // Standalone LTR value: renders LTR-visual in RTL as-is
                // (measured), so no invisible isolate characters.
                StegStatusChip(label: internship.reference),
              ],
            ),
            const SizedBox(height: StegSpacing.xs),
            Text(
              '${formatDay(internship.startDate, locale)} → '
              '${formatDay(internship.endDate, locale)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Supervisor's scope at a glance (count only — the Interns tab owns rows).
class _SupervisedCountCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(supervisedInternsProvider);
    return async.when(
      loading: () => const StegLoading(),
      error: (e, _) => Text(context.userError(e).message,
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
      data: (interns) => StegCard(
        title: l10n.myInterns,
        child: Text(
          '${interns.length}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
