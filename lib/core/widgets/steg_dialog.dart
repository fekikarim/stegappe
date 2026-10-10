import 'package:flutter/material.dart';

import '../theme/steg_spacing.dart';
import 'steg_button.dart';

/// Confirmation dialog for consequential actions + bottom-sheet helper.
/// All actions meet the 48px touch target via [StegButton].
///
/// Modern finish: 24 px radius, icon medallion, generous padding.
Future<bool> showStegConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final accent =
          destructive ? scheme.error : scheme.primary;
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel ?? 'OK'),
          ),
          StegButton(
            label: confirmLabel,
            variant: destructive
                ? StegButtonVariant.destructive
                : StegButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Modal bottom sheet that becomes near-full-screen on small devices
/// and respects safe areas + text scaling.
Future<T?> showStegSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Semantics(
      header: true,
      label: title,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: StegSpacing.md + 4,
          end: StegSpacing.md + 4,
          top: StegSpacing.sm,
          bottom:
              MediaQuery.of(ctx).viewInsets.bottom + StegSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: StegSpacing.sm),
            Text(title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(letterSpacing: -0.1)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle,
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: StegSpacing.sm),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}
