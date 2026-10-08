import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/role_label.dart';
import '../../domain/greeting.dart';

/// First display token of a full name or email (T13 greeting personalizes
/// with it; never sent anywhere, display only).
String homeFirstName(String displayName) {
  final token = displayName.trim().split(RegExp(r'\s+')).firstOrNull ?? '';
  if (token.isEmpty) return '';
  final local = token.split('@').first;
  if (local.isEmpty) return '';
  return local[0].toUpperCase() + (local.length > 1 ? local.substring(1) : '');
}

String greetingFor(AppLocalizations l10n, String displayName, DateTime now) {
  final name = homeFirstName(displayName);
  return switch (greetingBand(now)) {
    DayBand.morning => l10n.homeGreetMorning(name),
    DayBand.afternoon => l10n.homeGreetAfternoon(name),
    DayBand.evening => l10n.homeGreetEvening(name),
    DayBand.night => l10n.homeGreetNight(name),
  };
}

/// Home identity header (T13 ST-HOME-03/04, SU-HOME-04): time-of-day
/// greeting (device clock, display only — BR-53), initials avatar and the
/// localized role label. Shared by both shells.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.displayName,
    required this.role,
    this.now,
  });

  final String displayName;
  final UserRole role;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      label: greetingFor(l10n, displayName, now ?? DateTime.now()),
      excludeSemantics: true,
      child: Row(
        children: [
          UserAvatar(displayName: displayName),
          const SizedBox(width: StegSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  greetingFor(l10n, displayName, now ?? DateTime.now()),
                  style: Theme.of(context).textTheme.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: StegSpacing.xs),
                Text(
                  roleLabel(l10n, role),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable quick action (48px target, labelled for screen readers).
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

/// Four-or-fewer action grid (T13 UX: no more than 4 without "more").
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  /// Cell height = vertical padding + icon + gap + two scaled label lines.
  double _cellExtent(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale(style?.fontSize ?? 12.5) *
        (style?.height ?? 1.5);
    return StegSpacing.sm * 2 + 26 + 4 + lineHeight * 2;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      label: l10n.homeQuickActions,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.homeQuickActions,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StegSpacing.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // T15: the cell must fit two label lines at the user's text scale
            // (Arabic wraps earlier and 2.0× doubles the line height). The
            // height is measured from the real style instead of the default
            // square aspect ratio, which overflowed by 6 px (ar) / 44 px (2×).
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: StegSpacing.xs,
              crossAxisSpacing: StegSpacing.xs,
              mainAxisExtent: _cellExtent(context),
            ),
            itemCount: actions.length,
            itemBuilder: (context, i) {
              final a = actions[i];
              return Semantics(
                button: true,
                label: a.label,
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: StegSpacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a.icon, size: 26),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            a.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
