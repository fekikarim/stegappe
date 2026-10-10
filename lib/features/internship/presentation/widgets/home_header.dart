import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_colors.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_modern.dart';
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
///
/// Modern finish: gradient hero card with decorative orbs.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.displayName,
    required this.role,
    this.now,
    this.trailing,
  });

  final String displayName;
  final UserRole role;
  final DateTime? now;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StegGradientHeader(
      title: greetingFor(l10n, displayName, now ?? DateTime.now()),
      subtitle: roleLabel(l10n, role),
      displayName: displayName,
      trailing: trailing,
    );
  }
}

/// One tappable quick action (48px target, labelled for screen readers).
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final List<Color>? gradient;
}

/// Four-or-fewer action grid (T13 UX: no more than 4 without "more").
///
/// Modern finish: elevated tiles with gradient icon medallions.
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  /// Cell height = vertical padding + icon + gap + two scaled label lines.
  double _cellExtent(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale(style?.fontSize ?? 12.5) *
        (style?.height ?? 1.5);
    return StegSpacing.sm * 2 + 36 + 6 + lineHeight * 2;
  }

  static const _defaultGradients = <List<Color>>[
    [Color(0xFF0B61A0), Color(0xFF3E9BDC)],
    [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    [Color(0xFF0E7490), Color(0xFF4FB3C9)],
    [Color(0xFF1B7A3D), Color(0xFF4CC46E)],
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      label: l10n.homeQuickActions,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StegSectionHeader(
              title: l10n.homeQuickActions,
              icon: Icons.bolt_rounded),
          const SizedBox(height: StegSpacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: StegSpacing.sm,
              crossAxisSpacing: StegSpacing.sm,
              mainAxisExtent: _cellExtent(context),
            ),
            itemCount: actions.length,
            itemBuilder: (context, i) {
              final a = actions[i];
              final gradient =
                  a.gradient ?? _defaultGradients[i % _defaultGradients.length];
              return Semantics(
                button: true,
                label: a.label,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: a.onTap,
                    borderRadius:
                        BorderRadius.circular(StegSpacing.radiusMd),
                    child: Container(
                      decoration: BoxDecoration(
                        color: dark
                            ? StegColors.darkSurface
                            : Colors.white,
                        borderRadius: BorderRadius.circular(
                            StegSpacing.radiusMd),
                        border: Border.all(
                          color: dark
                              ? StegColors.darkBorder
                              : StegColors.lightBorder,
                        ),
                        boxShadow: StegColors.cardShadow(dark),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: StegSpacing.sm,
                          horizontal: StegSpacing.xs),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradient,
                                begin: AlignmentDirectional.topStart,
                                end: AlignmentDirectional.bottomEnd,
                              ),
                              borderRadius:
                                  BorderRadius.circular(12),
                              boxShadow: StegColors.buttonShadow,
                            ),
                            child: Icon(a.icon,
                                size: 20, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: Text(
                              a.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
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
