import 'package:flutter/material.dart';

import '../theme/steg_colors.dart';
import '../theme/steg_spacing.dart';

/// Primary/secondary/destructive buttons with enforced 48px touch target,
/// loading state, and semantic labels (UI_UX.md §9.1 + §7).
///
/// Modern finish: gradient primary with soft glow, 14 px radius.
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: StegSpacing.xs),
              ],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );

    Widget button;
    switch (variant) {
      case StegButtonVariant.primary:
        final enabled = onPressed != null && !loading;
        button = DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: dark
                        ? const [Color(0xFF3E9BDC), Color(0xFF6FBDEE)]
                        : const [Color(0xFF0B61A0), Color(0xFF1478C8)],
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                  )
                : null,
            color: enabled ? null : Theme.of(context).disabledColor,
            borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
            boxShadow: enabled ? StegColors.buttonShadow : null,
          ),
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
              ),
            ),
            child: child,
          ),
        );
      case StegButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: loading ? null : onPressed,
          child: child,
        );
      case StegButtonVariant.destructive:
        button = ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StegSpacing.radiusMd)),
          ),
          onPressed: loading ? null : onPressed,
          child: child,
        );
      case StegButtonVariant.text:
        button = TextButton(
          onPressed: loading ? null : onPressed,
          child: child,
        );
    }

    final sized = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: StegSpacing.minTouchTarget,
        minHeight: StegSpacing.minTouchTarget,
      ),
      child: button,
    );
    if (!loading && semanticsLabel == null) return sized;
    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: semanticsLabel ?? label,
      child: sized,
    );
  }
}
