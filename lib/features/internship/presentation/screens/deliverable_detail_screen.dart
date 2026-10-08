import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../messaging/presentation/providers/messaging_providers.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../domain/deliverable_file_rules.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../services/file_share.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import 'deliverable_upload_sheet.dart';

/// Deliverable detail: status, version history (never overwritten —
/// every upload appends), feedback comments, secure download per
/// version, and role transitions (intern submit / new version,
/// supervisor validate-reject with comments).
class DeliverableDetailScreen extends ConsumerStatefulWidget {
  const DeliverableDetailScreen({super.key, required this.deliverableId});

  final String deliverableId;

  @override
  ConsumerState<DeliverableDetailScreen> createState() =>
      _DeliverableDetailScreenState();
}

class _DeliverableDetailScreenState
    extends ConsumerState<DeliverableDetailScreen> {
  bool _downloading = false;
  bool _submitting = false;

  Future<void> _download({int? version, required String fileName}) async {
    setState(() => _downloading = true);
    try {
      await downloadAndShare(ref,
          deliverableId: widget.deliverableId,
          version: version,
          fileName: fileName);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.userError(e).message),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context);
    try {
      final repo = ref.read(internshipRepositoryProvider);
      final detail =
          await repo.getDeliverable(widget.deliverableId);
      await repo.submitDeliverable(widget.deliverableId);
      refreshDeliverables(ref, widget.deliverableId);
      final internshipId = detail.internshipId;
      if (internshipId != null) {
        // T10/B7: the window read stays honest after a successful submit.
        ref.invalidate(submissionWindowProvider(internshipId));
      }
      if (!mounted) return;
      // The guard stays held: the refetched SUBMITTED state removes the
      // action, so no spinner lingers and no second submit can start. A tap
      // landing in the refetch window hits the server, which owns the
      // transition (409 INVALID_STATUS_TRANSITION maps to an honest error).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deliverableSubmittedOk)),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessageOf(e, l10n)),
        ),
      );
    }
  }

  /// T10/B7: a declared validation document (journal/report) may only be
  /// submitted inside the final week (BR-22, server-owned window). The read
  /// shows/hides the action honestly — outside the window the app explains
  /// and offers to contact the supervisor, never an override.
  List<Widget> _submitAction(BuildContext context, AppLocalizations l10n,
      Locale locale, DeliverableDetail d) {
    if (d.documentKind == null || d.internshipId == null) {
      return [
        StegButton(
          label: l10n.deliverableSubmitAction,
          icon: Icons.send_outlined,
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ];
    }
    final windowAsync =
        ref.watch(submissionWindowProvider(d.internshipId!));
    return windowAsync.when(
      loading: () => [
        StegButton(
          label: l10n.deliverableSubmitAction,
          icon: Icons.send_outlined,
          loading: true,
          onPressed: null,
        ),
      ],
      // The window read failed: the server still enforces on submit and the
      // coded refusal maps to an honest sentence — never a silent bypass.
      error: (e, _) => [
        StegButton(
          label: l10n.deliverableSubmitAction,
          icon: Icons.send_outlined,
          loading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
      data: (w) {
        if (w.open) {
          return [
            StegButton(
              label: l10n.deliverableSubmitAction,
              icon: Icons.send_outlined,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            if (w.closesAt != null) ...[
              const SizedBox(height: StegSpacing.xs),
              Text(
                  l10n.submissionWindowUntil(
                      formatDay(w.closesAt!, locale)),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ];
        }
        return [
          _closedWindowCard(context, l10n, locale, w, d.internshipId!),
        ];
      },
    );
  }

  Widget _closedWindowCard(BuildContext context, AppLocalizations l10n,
      Locale locale, SubmissionWindow w, String internshipId) {
    final reason = switch (w.reason) {
      'BEFORE_WINDOW' when w.opensAt != null =>
        l10n.submissionWindowOpens(formatDay(w.opensAt!, locale)),
      'AFTER_WINDOW' when w.closesAt != null =>
        l10n.submissionWindowLate(formatDay(w.closesAt!, locale)),
      'NO_PERIOD' => l10n.submissionWindowNoPeriod,
      'CANCELLED' => l10n.submissionWindowCancelled,
      _ => l10n.errSubmissionWindowClosed,
    };
    return Container(
      padding: const EdgeInsets.all(StegSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(StegSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            label: reason,
            excludeSemantics: true,
            child: Text(reason,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: StegSpacing.sm),
          StegButton(
            label: l10n.contactSupervisorAction,
            variant: StegButtonVariant.secondary,
            icon: Icons.chat_outlined,
            onPressed: () => _contactSupervisor(internshipId),
          ),
        ],
      ),
    );
  }

  /// T10 edge case: refused outside the window → offer the supervisor chat
  /// (the app never overrides the server decision).
  Future<void> _contactSupervisor(String internshipId) async {
    final l10n = AppLocalizations.of(context);
    try {
      final conversations =
          await ref.read(conversationsProvider.future);
      final match = conversations
          .where((c) => c.internshipId == internshipId)
          .toList();
      if (!mounted) return;
      if (match.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.contactNoConversation)));
        return;
      }
      final conversation = match.first;
      final kindLabel = conversation.isPrivate
          ? l10n.convPrivate
          : l10n.convGroup;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          title: conversation.title.isEmpty
              ? kindLabel
              : conversation.title,
        ),
      ));
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessageOf(e, l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async =
        ref.watch(deliverableDetailProvider(widget.deliverableId));
    final commentsAsync = ref
        .watch(deliverableCommentsProvider(widget.deliverableId));
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliverablesTitle)),
      body: async.when(
        loading: () => const StegLoading(),
        error: (e, _) => StegErrorView(
          message: context.userError(e).message,
          onRetry: () =>
              refreshDeliverables(ref, widget.deliverableId),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            refreshDeliverables(ref, widget.deliverableId);
            try {
              await ref.read(
                  deliverableDetailProvider(widget.deliverableId).future);
            } on Exception {
              // Error UI renders via the AsyncValue.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: StegSpacing.screenPadding,
            children: [
              Semantics(
                header: true,
                label: d.title,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(d.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge),
                    if (d.description?.isNotEmpty == true) ...[
                      const SizedBox(height: StegSpacing.xs),
                      Text(d.description!),
                    ],
                    const SizedBox(height: StegSpacing.xs),
                    Wrap(
                      spacing: StegSpacing.xs,
                      runSpacing: StegSpacing.xs,
                      children: [
                        StegStatusChip(
                          label: deliverableStatusLabel(
                              d.status, l10n),
                          kind:
                              deliverableStatusKind(d.status),
                        ),
                        StegStatusChip(
                            label: l10n
                                .versionLabel(d.currentVersion)),
                      ],
                    ),
                    if (d.validatedByName?.isNotEmpty == true)
                      BidiText(
                        l10n.journalValidatedBy(
                            d.validatedByName!),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: StegSpacing.md),

              // --- Actions ---
              if (role == UserRole.intern &&
                  d.canSubmit) ...[
                ..._submitAction(context, l10n, locale, d),
                const SizedBox(height: StegSpacing.xs),
              ],
              if (role == UserRole.intern &&
                  d.canUploadNewVersion) ...[
                StegButton(
                  label: l10n.deliverableNewVersion,
                  variant: StegButtonVariant.secondary,
                  icon: Icons.upload_outlined,
                  onPressed: () =>
                      VersionUploadSheet.showNewVersion(context,
                          deliverableId: d.id),
                ),
                const SizedBox(height: StegSpacing.xs),
              ],
              if (role == UserRole.intern &&
                  !d.canUploadNewVersion)
                Text(l10n.deliverableValidatedLocked,
                    style:
                        Theme.of(context).textTheme.bodySmall),
              if (role == UserRole.supervisor &&
                  d.awaitsSupervisor)
                _SupervisorActions(detailId: d.id),
              const SizedBox(height: StegSpacing.md),

              // --- Version history ---
              DashboardSection(
                title:
                    '${l10n.deliverableVersions} (${d.versions.length})',
                child: d.versions.isEmpty
                    ? Text(l10n.deliverableChecklistEmpty,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium)
                    : Column(
                        children: [
                          for (final v in d.versions)
                            _VersionTile(
                              version: v,
                              isLatest:
                                  v.versionNumber ==
                                      d.currentVersion,
                              downloading: _downloading,
                              onDownload: () => _download(
                                  version: v.versionNumber,
                                  fileName: v.fileName),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: StegSpacing.md),

              // --- Feedback comments ---
              DashboardSection(
                title: l10n.journalComments,
                child: commentsAsync.when(
                  loading: () => const Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))),
                  error: (e, _) => Text(
                      context.userError(e).message,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .error)),
                  data: (comments) => comments.isEmpty
                      ? Text(l10n.journalNoComments,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall)
                      : Column(
                          children: [
                            for (final c in comments)
                              ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                dense: true,
                                leading: const Icon(
                                    Icons.comment_outlined,
                                    size: 20),
                                title: Text(c.content),
                                subtitle: Text(
                                    '${c.authorEmail} • ${formatDay(c.createdAt, locale)}',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    required this.version,
    required this.isLatest,
    required this.downloading,
    required this.onDownload,
  });

  final DeliverableVersionInfo version;
  final bool isLatest;
  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Semantics(
      label:
          '${l10n.versionLabel(version.versionNumber)}, ${version.fileName}',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          isLatest
              ? Icons.picture_as_pdf
              : Icons.history_outlined,
        ),
        // T15/RTL: a filename is an LTR technical run inside the localized
        // version caption.
        title: Text(
          '${l10n.versionLabel(version.versionNumber)} • '
          '${BidiText.isolate(version.fileName)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatDay(version.uploadedAt, locale)} • '
          '${DeliverableFileRules.formatBytes(version.size)}'
          '${version.changeSummary?.isNotEmpty == true ? ' • ${version.changeSummary!}' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: downloading
            ? const SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                tooltip: l10n.deliverableDownload,
                icon: const Icon(Icons.download_outlined),
                onPressed: onDownload,
              ),
      ),
    );
  }
}

class _SupervisorActions extends StatelessWidget {
  const _SupervisorActions({required this.detailId});

  final String detailId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: StegButton(
            label: l10n.validateAction,
            icon: Icons.check_outlined,
            onPressed: () => showDeliverableReviewDialog(context,
                deliverableId: detailId, approve: true),
          ),
        ),
        const SizedBox(width: StegSpacing.sm),
        Expanded(
          child: StegButton(
            label: l10n.rejectAction,
            variant: StegButtonVariant.secondary,
            icon: Icons.rate_review_outlined,
            onPressed: () => showDeliverableReviewDialog(context,
                deliverableId: detailId, approve: false),
          ),
        ),
      ],
    );
  }
}

/// Supervisor review dialog for deliverables: same server-confirmed
/// contract as journal review (comment required to request correction).
Future<void> showDeliverableReviewDialog(BuildContext context,
    {required String deliverableId, required bool approve}) {
  return showDialog(
    context: context,
    builder: (_) => _DeliverableReviewDialog(
        deliverableId: deliverableId, approve: approve),
  );
}

class _DeliverableReviewDialog extends ConsumerStatefulWidget {
  const _DeliverableReviewDialog(
      {required this.deliverableId, required this.approve});

  final String deliverableId;
  final bool approve;

  @override
  ConsumerState<_DeliverableReviewDialog> createState() =>
      _DeliverableReviewDialogState();
}

class _DeliverableReviewDialogState
    extends ConsumerState<_DeliverableReviewDialog> {
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
        await repo.validateDeliverable(widget.deliverableId, text);
      } else {
        await repo.rejectDeliverable(widget.deliverableId, text);
      }
      refreshDeliverables(ref, widget.deliverableId);
      refreshValidations(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
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
        _error = userMessageOf(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.deliverableReviewTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StegTextField(
            controller: _comment,
            label: l10n.commentLabel,
            hint: widget.approve
                ? l10n.commentHintValidate
                : l10n.commentHintReject,
            required: !widget.approve,
            error: _commentError,
          ),
          // D2/BR-28 first-level framing: approving registers the document
          // for the administration, which alone takes the final decision.
          if (widget.approve) ...[
            const SizedBox(height: StegSpacing.xs),
            Text(l10n.reviewFirstLevelNote,
                style: Theme.of(context).textTheme.bodySmall),
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
