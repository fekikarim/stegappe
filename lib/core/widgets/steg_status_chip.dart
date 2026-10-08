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
      StegStatusKind.success => (
        // T15: the light success/warning tokens measure 2.76:1 / 2.92:1 on the
        // deep-navy page — unreadable. ux-ui §1 asks for the on-dark pair.
        dark ? StegColors.successDark : StegColors.success,
        Icons.check_circle_outline
      ),
      StegStatusKind.warning => (
        dark ? StegColors.warningDark : StegColors.warning,
        Icons.warning_amber_outlined
      ),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      excludeSemantics: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.sm, vertical: StegSpacing.xxs),
        decoration: BoxDecoration(
          // T15: a 12 % tint of the label colour behind the label eroded its
          // own contrast (measured 4.07:1 on the dark theme, 4.31:1 on the
          // light one). The chip now sits on the page surface and keeps the
          // colour identity in its border, icon and text.
          color: dark ? StegColors.darkPage : StegColors.lightPage,
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
                  // T15: a chip inside a tight row (a long Arabic label at
                  // 2.0×) must truncate rather than force a Row overflow.
                  // The full label stays available through the Semantics
                  // wrapper above, so nothing is lost to a screen reader.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
