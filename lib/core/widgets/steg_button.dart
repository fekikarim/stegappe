import 'package:flutter/material.dart';

import '../theme/steg_spacing.dart';

/// Primary/secondary/destructive buttons with enforced 48px touch target,
/// loading state, and semantic labels (UI_UX.md §9.1 + §7).
enum StegButtonVariant { primary, secondary, destructive, text }

class StegButton extends StatelessWidget {
  const StegButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StegButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final StegButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: StegSpacing.xs),
              ],
              Flexible(child: Text(label)),
            ],
          );

    final button = switch (variant) {
      StegButtonVariant.primary => ElevatedButton(
          onPressed: loading ? null : onPressed,
          child: child,
        ),
      StegButtonVariant.secondary => OutlinedButton(
          onPressed: loading ? null : onPressed,
          child: child,
        ),
      StegButtonVariant.destructive => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        ),
      StegButtonVariant.text => TextButton(
          onPressed: loading ? null : onPressed,
          child: child,
        ),
    };

    final sized = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: StegSpacing.minTouchTarget,
        minHeight: StegSpacing.minTouchTarget,
      ),
      child: button,
    );
    // T15: the Material button already publishes its role and derives its
    // label from the child text. The extra wrapper was only needed when the
    // visible child is a spinner (loading) or when a different label must be
    // announced. Left in place unconditionally it produced an *unlabelled*
    // actionable node — the wrapper carried the label while the button
    // carried the tap (measured on the task board and the logbook).
    if (!loading && semanticsLabel == null) return sized;
    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: semanticsLabel ?? label,
      child: sized,
    );
  }
}
