import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_colors.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_card.dart';

/// Offline stale-data notice: honest labeling, never silent.
class StaleNotice extends StatelessWidget {
  const StaleNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      excludeSemantics: true,
      label: l10n.staleData,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md, vertical: StegSpacing.xs),
        decoration: BoxDecoration(
          color: StegColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(StegSpacing.radiusSm),
          border: Border.all(
              color: StegColors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 16, color: StegColors.warning),
            const SizedBox(width: StegSpacing.xs),
            Expanded(
              child: Text(l10n.staleData,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard section: title row with optional trailing action + content.
/// Answers one question per section ("what should I do?" etc.).
class DashboardSection extends StatelessWidget {
  const DashboardSection({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
    this.onAction,
    required this.child,
  }) : assert((actionLabel == null) == (onAction == null),
            'actionLabel and onAction go together');

  final String title;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StegCard(
      title: title,
      action: action ??
          (actionLabel != null
              ? TextButton(onPressed: onAction, child: Text(actionLabel!))
              : null),
      child: child,
    );
  }
}

/// Linear progress with semantic label (never color-only).
class LabeledProgress extends StatelessWidget {
  const LabeledProgress({
    super.key,
    required this.label,
    required this.fraction,
    required this.counter,
  });

  final String label;
  final double fraction;
  final String counter;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $counter',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              // Counter is a technical value: keep LTR in RTL layouts.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(counter,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: StegSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(StegSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
