import 'package:flutter/material.dart';

import '../theme/steg_spacing.dart';
import 'steg_button.dart';

/// Confirmation dialog for consequential actions + bottom-sheet helper.
/// All actions meet the 48px touch target via [StegButton].
Future<bool> showStegConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
    ),
  );
  return result ?? false;
}

/// Modal bottom sheet that becomes near-full-screen on small devices
/// and respects safe areas + text scaling.
Future<T?> showStegSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
          top: Radius.circular(StegSpacing.radiusLg)),
    ),
    builder: (ctx) => Semantics(
      header: true,
      label: title,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: StegSpacing.md,
          end: StegSpacing.md,
          top: StegSpacing.md,
          bottom:
              MediaQuery.of(ctx).viewInsets.bottom + StegSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: StegSpacing.sm),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}
