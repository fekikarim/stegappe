import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/status_labels.dart';

/// Journal entry detail: full record, validation state, supervisor
/// feedback comments, and role-appropriate actions:
/// - intern + DRAFT/REJECTED → submit (server-confirmed);
/// - supervisor + SUBMITTED → validate / request correction (dialog +
///   comment, server-confirmed, never optimistic).
Future<void> showJournalDetailSheet(
    BuildContext context, JournalEntry entry) {
  return showStegSheet(
    context,
    title: AppLocalizations.of(context).journalDetailTitle,
    builder: (_) => _JournalDetailBody(entry: entry),
  );
}

class _JournalDetailBody extends ConsumerWidget {
  const _JournalDetailBody({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;
    final commentsAsync =
        ref.watch(journalCommentsProvider(entry.id));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: StegSpacing.xs,
          runSpacing: StegSpacing.xs,
          children: [
            StegStatusChip(
              label: journalStatusLabel(entry.status, l10n),
              kind: journalStatusKind(entry.status),
            ),
            StegStatusChip(label: formatDay(entry.entryDate, locale)),
          ],
        ),
        const SizedBox(height: StegSpacing.sm),
        Text(entry.title.isEmpty ? '—' : entry.title,
            style: Theme.of(context).textTheme.titleMedium),
        if (entry.description?.isNotEmpty == true) ...[
          const SizedBox(height: StegSpacing.xs),
          Text(entry.description!),
        ],
        if (entry.validatedByName?.isNotEmpty == true) ...[
          const SizedBox(height: StegSpacing.xs),
          BidiText(
            l10n.journalValidatedBy(entry.validatedByName!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: StegSpacing.md),
        Text(l10n.journalComments,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: StegSpacing.xs),
        commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: StegSpacing.sm),
            child: Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          error: (e, _) => Text(
              e is ApiException ? e.message : e.toString(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error)),
          data: (comments) => comments.isEmpty
              ? Text(l10n.journalNoComments,
                  style: Theme.of(context).textTheme.bodySmall)
              : Column(
                  children: [
                    for (final c in comments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                            Icons.comment_outlined,
                            size: 20),
                        title: Text(c.content),
                        subtitle: Text(
                            '${c.authorEmail} • ${formatDay(c.createdAt, locale)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: StegSpacing.md),
        if (role == UserRole.intern && entry.canSubmit)
          StegButton(
            label: l10n.journalSubmitAction,
            icon: Icons.send_outlined,
            onPressed: () => _submit(context, ref),
          ),
        if (role == UserRole.supervisor && entry.awaitsSupervisor)
          Row(
            children: [
              Expanded(
                child: StegButton(
                  label: l10n.validateAction,
                  icon: Icons.check_outlined,
                  onPressed: () => showReviewDialog(context,
                      entry: entry, approve: true),
                ),
              ),
              const SizedBox(width: StegSpacing.sm),
              Expanded(
                child: StegButton(
                  label: l10n.rejectAction,
                  variant: StegButtonVariant.secondary,
                  icon: Icons.rate_review_outlined,
                  onPressed: () => showReviewDialog(context,
                      entry: entry, approve: false),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(internshipRepositoryProvider)
          .submitJournal(entry.id);
      ref
        ..invalidate(journalListProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(journalCommentsProvider(entry.id));
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journalSubmittedOk)),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e is ApiException ? e.message : e.toString()),
          ),
        );
      }
    }
  }
}

/// Supervisor review dialog: optional note for approval, REQUIRED
/// explanation for correction requests. Server-confirmed: the dialog
/// stays open with the error on failure — a decision is never shown
/// as done until the backend confirms it.
Future<void> showReviewDialog(BuildContext context,
    {required JournalEntry entry, required bool approve}) {
  return showDialog(
    context: context,
    builder: (_) => _ReviewDialog(entry: entry, approve: approve),
  );
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.entry, required this.approve});

  final JournalEntry entry;
  final bool approve;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _comment = TextEditingController();
  bool _working = false;
  String? _error;
  String? _commentError;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _decide() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.approve && _comment.text.trim().isEmpty) {
      setState(() => _commentError = l10n.commentRequired);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
      _commentError = null;
    });
    try {
      final repo = ref.read(internshipRepositoryProvider);
      final text =
          _comment.text.trim().isEmpty ? null : _comment.text.trim();
      if (widget.approve) {
        await repo.validateJournal(widget.entry.id, text);
      } else {
        await repo.rejectJournal(widget.entry.id, text);
      }
      ref
        ..invalidate(pendingValidationsProvider)
        ..invalidate(journalListProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(journalCommentsProvider(widget.entry.id));
      if (!mounted) return;
      Navigator.of(context)
        ..pop() // dialog
        ..pop(); // detail sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.approve
              ? l10n.validationDone
              : l10n.rejectionDone),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.reviewTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.entry.title.isEmpty ? '—' : widget.entry.title,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: StegSpacing.sm),
          StegTextField(
            controller: _comment,
            label: l10n.commentLabel,
            hint: widget.approve
                ? l10n.commentHintValidate
                : l10n.commentHintReject,
            required: !widget.approve,
            error: _commentError,
          ),
          if (_error != null) ...[
            const SizedBox(height: StegSpacing.xs),
            Semantics(
              liveRegion: true,
              label: _error,
              excludeSemantics: true,
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.keepEditingAction),
        ),
        StegButton(
          label: widget.approve
              ? l10n.validateAction
              : l10n.rejectAction,
          variant: widget.approve
              ? StegButtonVariant.primary
              : StegButtonVariant.destructive,
          loading: _working,
          onPressed: _working ? null : _decide,
        ),
      ],
    );
  }
}
