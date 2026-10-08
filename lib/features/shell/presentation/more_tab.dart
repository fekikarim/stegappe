import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/settings_providers.dart';
import '../../../core/theme/steg_spacing.dart';
import '../../../core/widgets/steg_button.dart';
import '../../../core/widgets/steg_card.dart';
import '../../../core/widgets/steg_dialog.dart';
import '../../../core/widgets/steg_fields.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/role_label.dart';
import '../../auth/presentation/screens/change_password_screen.dart';
import '../../community/presentation/screens/community_feed_screen.dart';
import '../../community/presentation/screens/community_reports_screen.dart';
import '../../internship/presentation/providers/workspace_providers.dart';
import 'about_screen.dart';
import 'profile_screen.dart';

/// Settings tab (T14 SH-SET-*): profile header, account, appearance,
/// language, about, logout — sectioned, 48 px rows. Identity shows email
/// and role only (CIN is not exposed by any mobile endpoint, and the raw
/// user id carries no meaning for the user, so neither is rendered).
class MoreTab extends ConsumerWidget {
  const MoreTab({super.key});

  /// Best-effort server sync of the UI locale (T14): local state applies
  /// immediately; a failed sync keeps the local value and never blocks.
  Future<void> _syncLocale(WidgetRef ref, String code) async {
    try {
      await ref.read(internshipRepositoryProvider).syncLocale(code);
    } on Exception {
      // Local preference already applied; the server retry happens on
      // the next switch (never a blocking error).
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ListView(
      padding: StegSpacing.screenPadding,
      children: [
        if (user != null) ...[
          _ProfileHeaderCard(user: user),
          const SizedBox(height: StegSpacing.md),
        ],
        // --- Community (T08 / ST-COM-01): peer help feed for students;
        // staff open the same surface with moderation affordances.
        StegCard(
          title: l10n.communityTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.forum_outlined),
                title: Text(l10n.communityTitle),
                subtitle: Text(l10n.communityEmptyHint,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.arrow_forward_outlined),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CommunityFeedScreen()),
                ),
              ),
              // Moderation queue entry: staff roles only (UX affordance;
              // the server enforces moderation on every call).
              if (user != null &&
                  (user.mobileRole == UserRole.supervisor ||
                      user.mobileRole == UserRole.adminSupervisor))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l10n.communityReports),
                  trailing: const Icon(Icons.arrow_forward_outlined),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CommunityReportsScreen()),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: StegSpacing.md),
        StegCard(
          title: l10n.accountTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.profileTitle),
                trailing: const Icon(Icons.arrow_forward_outlined),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: Text(l10n.profileChangePassword),
                trailing: const Icon(Icons.arrow_forward_outlined),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: StegSpacing.md),
        StegCard(
          title: l10n.appearanceTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.theme,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: StegSpacing.xs),
              Wrap(
                spacing: StegSpacing.xs,
                children: [
                  ChoiceChip(
                    label: Text(l10n.themeSystem),
                    selected: themeMode == StegThemeMode.system,
                    onSelected: (_) => ref
                        .read(themeModeProvider.notifier)
                        .setMode(StegThemeMode.system),
                  ),
                  ChoiceChip(
                    label: Text(l10n.themeLight),
                    selected: themeMode == StegThemeMode.light,
                    onSelected: (_) => ref
                        .read(themeModeProvider.notifier)
                        .setMode(StegThemeMode.light),
                  ),
                  ChoiceChip(
                    label: Text(l10n.themeDark),
                    selected: themeMode == StegThemeMode.dark,
                    onSelected: (_) => ref
                        .read(themeModeProvider.notifier)
                        .setMode(StegThemeMode.dark),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: StegSpacing.md),
        StegCard(
          title: l10n.language,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: StegSpacing.xs,
                children: [
                  for (final loc in StegLocales.supported)
                    ChoiceChip(
                      label: Text(_localeName(loc.languageCode, l10n)),
                      selected:
                          (locale ?? StegLocales.french).languageCode ==
                              loc.languageCode,
                      onSelected: (_) async {
                        await ref
                            .read(localeProvider.notifier)
                            .setLocale(loc);
                        await _syncLocale(ref, loc.languageCode);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: StegSpacing.md),
        StegCard(
          title: l10n.aboutTitle,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.aboutTitle),
            trailing: const Icon(Icons.arrow_forward_outlined),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ),
        const SizedBox(height: StegSpacing.md),
        StegCard(
          title: l10n.navMore,
          child: StegButton(
            label: l10n.logout,
            variant: StegButtonVariant.secondary,
            icon: Icons.logout_outlined,
            onPressed: () async {
              final confirmed = await showStegConfirmDialog(
                context,
                title: l10n.logoutConfirmTitle,
                message: l10n.logoutConfirmMessage,
                confirmLabel: l10n.logout,
                cancelLabel: l10n.cancelAction,
              );
              if (confirmed && context.mounted) {
                await ref
                    .read(authControllerProvider.notifier)
                    .logout();
              }
            },
          ),
        ),
      ],
    );
  }

  String _localeName(String code, AppLocalizations l10n) => switch (code) {
        'fr' => 'Français',
        'en' => 'English',
        'ar' => 'العربية',
        _ => code,
      };
}

/// Profile header: generated-initial avatar, email and localized role.
/// Taps through to the read-only profile screen.
class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StegCard(
      title: l10n.profileTitle,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: UserAvatar(displayName: user.email),
        // T15/RTL: an email must stay an isolated LTR run inside Arabic.
        title: BidiText(user.email,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(roleLabel(l10n, user.mobileRole)),
        trailing: const Icon(Icons.arrow_forward_outlined),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      ),
    );
  }
}
