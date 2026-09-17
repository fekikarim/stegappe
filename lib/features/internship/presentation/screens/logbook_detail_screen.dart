import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/logbook.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';

/// Supervisor's logbook review: read the intern's submitted content,
/// then validate or return it with a required reason. Backend is the
/// single source of truth for every state transition — the UI never
/// degrades permissions or invents rules (D6 §9).
class LogbookDetailScreen extends ConsumerWidget {
  const LogbookDetailScreen({
    super.key,
    required this.internshipId,
    this.internshipReference,
  });

  final String internshipId;
  final String? internshipReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(logbookProvider(internshipId));
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logbookReviewTitle)),
      body: async.when(
        loading: () => const StegLoading(),
        error: (e, _) => StegErrorView(
          message: e is ApiException ? e.message : e.toString(),
          onRetry: () => refreshLogbooks(ref, internshipId),
        ),
        data: (logbook) {
          if (logbook == null) {
            return StegEmptyView(
              title: l10n.logbookNotSubmitted,
              icon: Icons.menu_book_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              refreshLogbooks(ref, internshipId);
              try {
                await ref.read(logbookProvider(internshipId).future);
              } on Exception {
                // Error UI renders via the AsyncValue.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: StegSpacing.screenPadding,
              children: [
                Wrap(
                  spacing: StegSpacing.xs,
                  runSpacing: StegSpacing.xs,
                  children: [
                    if (internshipReference?.isNotEmpty == true)
                      StegStatusChip(label: internshipReference!),
                    StegStatusChip(
                      label: logbookStatusLabel(
                          logbook.status, l10n),
                      kind: logbookStatusKind(logbook.status),
                    ),
                    if (logbook.submittedAt != null)
                      StegStatusChip(
                        label: formatDay(
                            logbook.submittedAt!, locale),
                      ),
                  ],
                ),
                const SizedBox(height: StegSpacing.md),
                DashboardSection(
                  title: l10n.logbookContentLabel,
                  child: SelectableText(
                    logbook.finalText?.isNotEmpty == true
                        ? logbook.finalText!
                        : '—',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (logbook.rejectionReason?.isNotEmpty == true) ...[
                  const SizedBox(height: StegSpacing.md),
                  DashboardSection(
                    title: l10n.logbookRejectReasonLabel,
                    child: SelectableText(
                        logbook.rejectionReason!),
                  ),
                ],
                const SizedBox(height: StegSpacing.md),
                if (role == UserRole.supervisor &&
                    logbook.status == LogbookStatus.submitted)
                  _SupervisorLogbookActions(
                    internshipId: internshipId,
                    internshipReference:
                        internshipReference ?? '—',
                    logbookId: logbook.id,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupervisorLogbookActions extends StatelessWidget {
  const _SupervisorLogbookActions({
    required this.internshipId,
    required this.internshipReference,
    required this.logbookId,
  });

  final String internshipId;
  final String internshipReference;
  final String logbookId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: StegButton(
            label: l10n.validateAction,
            icon: Icons.check_outlined,
            onPressed: () => showLogbookReviewDialog(context,
                internshipId: internshipId,
                internshipReference: internshipReference,
                logbookId: logbookId,
                approve: true),
          ),
        ),
        const SizedBox(width: StegSpacing.sm),
        Expanded(
          child: StegButton(
            label: l10n.rejectAction,
            variant: StegButtonVariant.secondary,
            icon: Icons.rate_review_outlined,
            onPressed: () => showLogbookReviewDialog(context,
                internshipId: internshipId,
                internshipReference: internshipReference,
                logbookId: logbookId,
                approve: false),
          ),
        ),
      ],
    );
  }
}

/// Logbook review decision. Validation is a plain confirm; rejection
/// requires a reason (backend enforces non-empty too — no local rule).
Future<void> showLogbookReviewDialog(
  BuildContext context, {
  required String internshipId,
  required String internshipReference,
  required String logbookId,
  required bool approve,
}) {
  return showDialog(
    context: context,
    builder: (_) => _LogbookReviewDialog(
      internshipId: internshipId,
      internshipReference: internshipReference,
      logbookId: logbookId,
      approve: approve,
    ),
  );
}

class _LogbookReviewDialog extends ConsumerStatefulWidget {
  const _LogbookReviewDialog({
    required this.internshipId,
    required this.internshipReference,
    required this.logbookId,
    required this.approve,
  });

  final String internshipId;
  final String internshipReference;
  final String logbookId;
  final bool approve;

  @override
  ConsumerState<_LogbookReviewDialog> createState() =>
      _LogbookReviewDialogState();
}

class _LogbookReviewDialogState extends ConsumerState<_LogbookReviewDialog> {
  final _reason = TextEditingController();
  bool _working = false;
  String? _error;
  String? _reasonError;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.approve && _reason.text.trim().isEmpty) {
      setState(() => _reasonError = l10n.logbookRejectReasonRequired);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
      _reasonError = null;
    });
    try {
      final repo = ref.read(internshipRepositoryProvider);
      if (widget.approve) {
        await repo.validateLogbook(
            widget.internshipId, widget.logbookId);
      } else {
        await repo.rejectLogbook(widget.internshipId, widget.logbookId,
            _reason.text.trim());
      }
      refreshLogbooks(ref, widget.internshipId);
      refreshValidations(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.approve
              ? l10n.logbookValidatedOk
              : l10n.logbookRejectedOk),
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
      title: Text(widget.approve
          ? l10n.logbookReviewTitle
          : l10n.rejectAction),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(widget.internshipReference,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          if (!widget.approve) ...[
            const SizedBox(height: StegSpacing.sm),
            StegTextField(
              controller: _reason,
              label: l10n.logbookRejectReasonLabel,
              hint: l10n.logbookRejectReasonHint,
              required: true,
              error: _reasonError,
            ),
          ],
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
          onPressed:
              _working ? null : () => Navigator.of(context).pop(),
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