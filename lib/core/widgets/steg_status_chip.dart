import 'package:flutter/material.dart';

import '../theme/steg_colors.dart';
import '../theme/steg_spacing.dart';

/// Status chip: label + semantic color + icon. Never color-only (UI_UX.md §2.3).
enum StegStatusKind { info, success, warning, error, neutral }

class StegStatusChip extends StatelessWidget {
  const StegStatusChip({
    super.key,
    required this.label,
    this.kind = StegStatusKind.neutral,
  });

  final String label;
  final StegStatusKind kind;

  (Color, IconData) _style(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (kind) {
      StegStatusKind.info =>
        (dark ? StegColors.primaryBright : StegColors.info, Icons.info_outline),
      StegStatusKind.success => (StegColors.success, Icons.check_circle_outline),
      StegStatusKind.warning => (StegColors.warning, Icons.warning_amber_outlined),
      StegStatusKind.error =>
        (Theme.of(context).colorScheme.error, Icons.error_outline),
      StegStatusKind.neutral => (
          Theme.of(context).colorScheme.onSurfaceVariant,
          Icons.circle_outlined
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style(context);
    return Semantics(
      excludeSemantics: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.sm, vertical: StegSpacing.xxs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(StegSpacing.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: StegSpacing.xxs),
            Flexible(
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
