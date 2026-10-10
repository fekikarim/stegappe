import 'package:flutter/material.dart';

import '../theme/steg_colors.dart';
import '../theme/steg_spacing.dart';
import 'user_avatar.dart';

/// Modern shared surfaces used by every screen.
///
/// [StegGradientHeader]: hero identity block with brand gradient,
/// decorative orbs and slot for chips/actions — replaces plain Row headers.
/// [StegSectionHeader]: eyebrow-style title row with "see all" action.
/// [StegMenuTile]: rounded settings-style row with icon medallion.
/// [StegStatTile]: KPI mini-card with gradient icon.
class StegGradientHeader extends StatelessWidget {
  const StegGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.displayName,
    this.avatarRadius = 22,
    this.chips,
    this.trailing,
    this.onAvatarTap,
  });

  final String title;
  final String? subtitle;
  final String? displayName;
  final double avatarRadius;
  final List<Widget>? chips;
  final Widget? trailing;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      header: true,
      label: title,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? const [Color(0xFF0A2540), Color(0xFF123A5E), Color(0xFF1B4E7E)]
                : const [Color(0xFF042843), Color(0xFF0B61A0), Color(0xFF1478C8)],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
          borderRadius: BorderRadius.circular(StegSpacing.radiusLg),
          boxShadow: StegColors.cardShadow(dark),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -40,
              end: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: -60,
              start: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(StegSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName != null)
                    GestureDetector(
                      onTap: onAvatarTap,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: UserAvatar(
                          displayName: displayName!,
                          radius: avatarRadius,
                          ring: false,
                        ),
                      ),
                    ),
                  if (displayName != null)
                    const SizedBox(width: StegSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.75),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (chips != null &&
                            chips!.isNotEmpty) ...[
                          const SizedBox(height: StegSpacing.sm),
                          Wrap(
                            spacing: StegSpacing.xs,
                            runSpacing: StegSpacing.xs,
                            children: chips!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: StegSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eyebrow section title with optional action — modern dashboard rhythm.
class StegSectionHeader extends StatelessWidget {
  const StegSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.action,
    this.icon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: StegSpacing.xs),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 16, letterSpacing: -0.1),
          ),
        ),
        if (action != null)
          SizedBox(height: 44, child: action!)
        else if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(48, 44),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Rounded settings row with gradient icon medallion and chevron.
class StegMenuTile extends StatelessWidget {
  const StegMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.gradient,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient ??
                        (dark
                            ? [
                                StegColors.primaryBright
                                    .withValues(alpha: 0.35),
                                StegColors.aiAccentDark
                                    .withValues(alpha: 0.35)
                              ]
                            : [
                                StegColors.brandPrimary
                                    .withValues(alpha: 0.14),
                                StegColors.aiAccent
                                    .withValues(alpha: 0.14)
                              ]),
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: StegSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// KPI mini-card with gradient icon + big number.
class StegStatTile extends StatelessWidget {
  const StegStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.gradient,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final List<Color>? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: const EdgeInsets.all(StegSpacing.md),
      decoration: BoxDecoration(
        color: dark ? StegColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        border: Border.all(
            color: dark
                ? StegColors.darkBorder
                : StegColors.lightBorder),
        boxShadow: StegColors.cardShadow(dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient ?? StegColors.brandGradient,
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: StegColors.buttonShadow,
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: StegSpacing.sm),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        child: card,
      ),
    );
  }
}

/// Gradient app bar used by top-level screens for a premium entry feel.
class StegGradientAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const StegGradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      title: Text(title),
      actions: actions,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF042843), Color(0xFF0B61A0)],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
        ),
      ),
    );
  }
}
