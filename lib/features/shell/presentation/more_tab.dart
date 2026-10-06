import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/settings_providers.dart';
import '../../../core/theme/steg_spacing.dart';
import '../../../core/widgets/steg_button.dart';
import '../../../core/widgets/steg_card.dart';
import '../../../core/widgets/steg_fields.dart';
import '../../community/presentation/screens/community_feed_screen.dart';
import '../../community/presentation/screens/community_reports_screen.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/role_label.dart';

/// Profile / settings tab: user identity (CIN never shown — not exposed
/// by any mobile endpoint), language + theme controls.
class MoreTab extends ConsumerWidget {
  const MoreTab({super.key});

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
        // --- Community (T08 / ST-COM-01): peer help feed for students;
        // staff open the same surface with moderation affordances.
        StegCard(
          title: l10n.communityTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.forum_outlined),
                title: Text(l10n.communityTitle),
                subtitle: Text(l10n.communityEmptyHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                trailing:
                    const Icon(Icons.arrow_forward_outlined),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const CommunityFeedScreen()),
                ),
              ),
              // Moderation queue entry: staff roles only (UX affordance;
              // the server enforces moderation on every call).
              if (user != null &&
                  (user.mobileRole == UserRole.supervisor ||
                      user.mobileRole ==
                          UserRole.adminSupervisor))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.flag_outlined),
                  title: Text(l10n.communityReports),
                  trailing:
                      const Icon(Icons.arrow_forward_outlined),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            const CommunityReportsScreen()),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: StegSpacing.md),
        StegCard(
          title: l10n.navMore,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user != null) ...[
                Text(user.email,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: StegSpacing.xxs),
                // SH-PRO-01: the role is visible (and announced) so a
                // supervisor/admin-supervisor never has to guess.
                Text(roleLabel(l10n, user.mobileRole),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )),
                const SizedBox(height: StegSpacing.xs),
                BidiText(
                  user.id.isEmpty ? '—' : user.id,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: StegSpacing.md),
              ],
              Text(l10n.language,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: StegSpacing.xs),
              Wrap(
                spacing: StegSpacing.xs,
                children: [
                  for (final loc in StegLocales.supported)
                    ChoiceChip(
                      label: Text(_localeName(loc.languageCode, l10n)),
                      selected:
                          (locale ?? StegLocales.french).languageCode ==
                              loc.languageCode,
                      onSelected: (_) => ref
                          .read(localeProvider.notifier)
                          .setLocale(loc),
                    ),
                ],
              ),
              const SizedBox(height: StegSpacing.md),
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
              const SizedBox(height: StegSpacing.lg),
              StegButton(
                label: l10n.logout,
                variant: StegButtonVariant.secondary,
                icon: Icons.logout_outlined,
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .logout(),
              ),
            ],
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
