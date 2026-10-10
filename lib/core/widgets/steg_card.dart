import 'package:flutter/material.dart';

import '../theme/steg_colors.dart';
import '../theme/steg_spacing.dart';

/// Grouping card with title, optional action, consistent padding.
///
/// Modern finish: 16 px radius, hairline border, soft shadow.
/// Never fixed height — grows with content + text scaling (UI_UX.md §9.5).
class StegCard extends StatelessWidget {
  const StegCard({
    super.key,
    this.title,
    this.action,
    required this.child,
    this.semanticsLabel,
    this.accent = false,
  });

  final String? title;
  final Widget? action;
  final Widget child;
  final String? semanticsLabel;

  /// Renders a subtle brand-tinted surface for hero/featured cards.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final bg = accent
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: dark ? 0.16 : 0.07),
            dark ? StegColors.darkSurface : StegColors.lightSurface,
          )
        : (dark ? StegColors.darkSurface : StegColors.lightSurface);

    // A real Material Card (not a decorated box) so ListTile ink splashes
    // render and the widget contract stays stable for callers and tests.
    final card = Card(
      color: bg,
      elevation: dark ? 0 : 2,
      shadowColor: dark
          ? Colors.black54
          : StegColors.brandPrimary.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        side: BorderSide(
          color: dark ? StegColors.darkBorder : StegColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title case final t?) ...[
              // T15: an unbounded action (a TextButton with a long label at
              // 2.0×) overflowed the header by up to 164 px. The action is
              // capped at 40 % of the card width and the title ellipsizes, so
              // both stay readable and nothing is clipped away.
              LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Expanded(
                      child: Text(t,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(letterSpacing: -0.1)),
                    ),
                    if (action case final Widget a)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.4),
                        // T15: a tight 48 dp height gives the header action a
                        // real touch target. Loose, it reported 28 px (e.g.
                        // the supervisor home "see all" button — measured).
                        child: SizedBox(
                            height: StegSpacing.minTouchTarget,
                            child: a),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: StegSpacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
    final String? label = semanticsLabel ?? title;
    if (label == null) return card;
    return Semantics(
      container: true,
      header: title != null,
      label: label,
      child: card,
    );
  }
}
