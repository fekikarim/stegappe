import 'package:flutter/material.dart';

import '../theme/steg_colors.dart';
import '../theme/steg_spacing.dart';

/// Status chip: label + semantic color + icon. Never color-only (UI_UX.md §2.3).
///
/// Modern finish: soft tinted pill with matching border.
enum StegStatusKind { info, success, warning, error, neutral }

class StegStatusChip extends StatelessWidget {
  const StegStatusChip({
    super.key,
    required this.label,
    this.kind = StegStatusKind.neutral,
  });

  final String label;
  final StegStatusKind kind;

  (Color, Color, IconData) _style(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    switch (kind) {
      case StegStatusKind.info:
        final fg = dark ? StegColors.primaryBright : StegColors.info;
        return (fg, fg.withValues(alpha: dark ? 0.22 : 0.12), Icons.info_outline);
      case StegStatusKind.success:
        final fg = dark ? StegColors.successDark : StegColors.success;
        return (fg, fg.withValues(alpha: dark ? 0.22 : 0.12),
            Icons.check_circle_outline);
      case StegStatusKind.warning:
        final fg = dark ? StegColors.warningDark : StegColors.warning;
        return (fg, fg.withValues(alpha: dark ? 0.22 : 0.12),
            Icons.warning_amber_outlined);
      case StegStatusKind.error:
        final fg = scheme.error;
        return (fg, fg.withValues(alpha: dark ? 0.22 : 0.12), Icons.error_outline);
      case StegStatusKind.neutral:
        final fg = scheme.onSurfaceVariant;
        return (
          fg,
          scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.7 : 0.6),
          Icons.circle_outlined
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = _style(context);
    return Semantics(
      excludeSemantics: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.sm, vertical: StegSpacing.xxs),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(StegSpacing.radiusFull),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: StegSpacing.xxs),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
