import 'package:flutter/material.dart';

import '../theme/steg_colors.dart';

/// Initials avatar for home headers (T13 ST-HOME-04/SH-PRO-01).
///
/// Modern finish: brand-gradient ring with soft-tinted core.
/// Initials by default; colour comes from the theme so both modes stay
/// legible, and the semantics label always carries the full display name.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.displayName,
    this.radius = 24,
    this.ring = true,
  });

  final String displayName;
  final double radius;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: displayName,
      excludeSemantics: true,
      child: Container(
        padding: ring ? const EdgeInsets.all(2.5) : EdgeInsets.zero,
        decoration: ring
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: dark
                      ? const [Color(0xFF3E9BDC), Color(0xFF7C3AED)]
                      : StegColors.brandGradient,
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                boxShadow: StegColors.cardShadow(dark),
              )
            : null,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: dark
              ? StegColors.darkElevated
              : scheme.primary.withValues(alpha: 0.12),
          foregroundColor:
              dark ? Colors.white : StegColors.brandPrimary,
          child: Text(
            initial,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: dark ? Colors.white : StegColors.brandPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}
