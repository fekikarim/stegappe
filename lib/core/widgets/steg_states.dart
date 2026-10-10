import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/steg_colors.dart';
import '../theme/steg_spacing.dart';
import 'steg_button.dart';

/// Reusable async-state widgets: loading / error / empty.
///
/// Modern finish: gradient icon medallions, generous whitespace, friendly
/// typography. Every async feature must use these — never a blank screen.
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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: StegColors.brandGradient,
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                boxShadow: StegColors.buttonShadow,
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: StegSpacing.md),
            Text(
              message ?? AppLocalizations.of(context).loading,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
    final error = Theme.of(context).colorScheme.error;
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
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: error.withValues(alpha: 0.12),
                  border:
                      Border.all(color: error.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.error_outline_rounded,
                    size: 34, color: error),
              ),
              const SizedBox(height: StegSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (traceId != null) ...[
                const SizedBox(height: StegSpacing.xs),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: SelectableText('trace: $traceId',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: StegSpacing.lg),
                StegButton(
                    label: l10n.retry,
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry),
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
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      excludeSemantics: true,
      label: title ?? l10n.emptyTitle,
      child: Center(
        child: Padding(
          padding: StegSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: dark
                        ? [
                            StegColors.primaryBright
                                .withValues(alpha: 0.35),
                            StegColors.aiAccentDark
                                .withValues(alpha: 0.35)
                          ]
                        : [
                            StegColors.brandPrimary
                                .withValues(alpha: 0.14),
                            StegColors.aiAccent
                                .withValues(alpha: 0.14)
                          ],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(icon, size: 36, color: scheme.primary),
              ),
              const SizedBox(height: StegSpacing.md),
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
                const SizedBox(height: StegSpacing.lg),
                StegButton(
                    label: actionLabel!,
                    icon: Icons.add_rounded,
                    onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
