import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/steg_spacing.dart';
import 'steg_button.dart';

/// Reusable async-state widgets: loading / error / empty.
/// Every async feature must use these — never a blank screen (UI_UX.md §6.3).
class StegLoading extends StatelessWidget {
  const StegLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      excludeSemantics: true,
      label: AppLocalizations.of(context).loading,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: StegSpacing.sm),
            Text(message ?? AppLocalizations.of(context).loading),
          ],
        ),
      ),
    );
  }
}

class StegErrorView extends StatelessWidget {
  const StegErrorView({
    super.key,
    required this.message,
    this.traceId,
    this.onRetry,
  });

  final String message;
  final String? traceId;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      excludeSemantics: true,
      label: message,
      child: Center(
        child: Padding(
          padding: StegSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 40, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: StegSpacing.sm),
              Text(message, textAlign: TextAlign.center),
              if (traceId != null) ...[
                const SizedBox(height: StegSpacing.xs),
                // LTR-forced: trace IDs are technical values (UI_UX.md §8.2).
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText('trace: $traceId',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: StegSpacing.md),
                StegButton(label: l10n.retry, onPressed: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StegEmptyView extends StatelessWidget {
  const StegEmptyView({
    super.key,
    this.title,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String? title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      excludeSemantics: true,
      label: title ?? l10n.emptyTitle,
      child: Center(
        child: Padding(
          padding: StegSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 44,
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: StegSpacing.sm),
              Text(title ?? l10n.emptyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              if (hint != null) ...[
                const SizedBox(height: StegSpacing.xs),
                Text(hint!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: StegSpacing.md),
                StegButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
