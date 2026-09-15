import 'package:flutter/material.dart';

import '../theme/steg_spacing.dart';

/// Grouping card with title, optional action, consistent padding.
/// Never fixed height — grows with content + text scaling (UI_UX.md §9.5).
class StegCard extends StatelessWidget {
  const StegCard({
    super.key,
    this.title,
    this.action,
    required this.child,
    this.semanticsLabel,
  });

  final String? title;
  final Widget? action;
  final Widget child;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: StegSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title case final t?) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(t,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (action case final Widget a) a,
                ],
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
