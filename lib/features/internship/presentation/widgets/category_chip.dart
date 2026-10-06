import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../domain/entities/task_classification.dart';

/// Classification chip for task cards (T03/ST-TASK-05).
///
/// Classification is visibly **secondary** to the workflow status: an outlined
/// chip with a folder icon, the category name and a small color dot. Color is
/// never the only indicator (icon + text always present); an unknown future
/// color token falls back to the default swatch.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: category.name,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.xs, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StegSpacing.radiusSm),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: categoryColor(category.colorToken, theme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Unclassified" marker shown on cards when the board has categories but
/// the task carries none. Rendered only when [show] (at least one category
/// exists) so boards without classification stay clean.
class UnclassifiedMarker extends StatelessWidget {
  const UnclassifiedMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      label: l10n.catUnclassified,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            l10n.catUnclassified,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

/// Closed token → swatch mapping shared with the backend vocabulary.
/// Unknown tokens fall back to the neutral swatch (never a crash).
Color categoryColor(String? token, ThemeData theme) {
  final swatches = {
    'red': Colors.red,
    'orange': Colors.orange,
    'amber': Colors.amber,
    'lime': Colors.lime,
    'green': Colors.green,
    'teal': Colors.teal,
    'cyan': Colors.cyan,
    'blue': Colors.blue,
    'indigo': Colors.indigo,
    'violet': Colors.purple,
    'pink': Colors.pink,
    'slate': Colors.blueGrey,
  };
  final swatch = swatches[token?.toLowerCase()];
  if (swatch == null) return theme.colorScheme.onSurfaceVariant;
  // Keep the dot readable in both themes: shade 600 in light, 300 in dark.
  final light = theme.brightness == Brightness.light;
  return light ? swatch.shade600 : swatch.shade300;
}
