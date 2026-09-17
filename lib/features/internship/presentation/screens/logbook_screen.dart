import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/logbook.dart';
import '../providers/workspace_providers.dart';

/// Local status of the review-then-submit flow.
enum LogbookSubmitStatus { idle, submitting }

/// Advisory logbook draft screen (intern side).
///
/// Safety properties (acceptance-critical):
/// - clearly labeled AI, advisory only, human review required;
/// - draft is REVIEW-ONLY: editable locally, never auto-submitted or
///   turned into an official record by the app;
/// - the client sends only the internship id; CIN/restricted documents
///   structurally cannot reach the model from here (server assembles
///   inputs through its restricted-excluding query + asserts
///   `cinExcluded`; the flag is displayed as evidence);
/// - AI outage/rate-limit/timeout degrades to a retry card and NEVER
///   blocks core internship operations.
///
/// Authoritative state (mirror of the backend `LogbookResponse`):
/// after submission the server record is the truth — the screen locks to
/// SUBMITTED/VALIDATED/OFFICIAL, and on REJECTED shows the supervisor's
/// reason and lets the intern resubmit. No local business rule.
class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  final _editor = TextEditingController();
  String? _seededFor;

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(logbookDraftProvider);
    final id = ref.watch(myInternshipIdProvider).valueOrNull;
    final logbookAsync =
        id == null ? null : ref.watch(logbookProvider(id));
    final logbook = logbookAsync?.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logbookTitle)),
      body: async.when(
        loading: () => const StegLoading(),
        error: (e, _) => Center(
          child: Padding(
            padding: StegSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  label: l10n.aiBadge,
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_outlined),
                      const SizedBox(width: StegSpacing.xs),
                      Text(l10n.aiBadge,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium),
                    ],
                  ),
                ),
                const SizedBox(height: StegSpacing.sm),
                Text(l10n.logbookUnavailable,
                    textAlign: TextAlign.center),
                if (e is ApiException && e.traceId != null) ...[
                  const SizedBox(height: StegSpacing.xs),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText('trace: ${e.traceId}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall),
                  ),
                ],
                const SizedBox(height: StegSpacing.md),
                StegButton(
                  label: l10n.logbookRegenerate,
                  icon: Icons.refresh_outlined,
                  onPressed: () =>
                      ref.invalidate(logbookDraftProvider),
                ),
              ],
            ),
          ),
        ),
        data: (draft) {
          String desired;
          String seed;
          if (logbook?.status == LogbookStatus.rejected) {
            desired = logbook!.finalText?.isNotEmpty == true
                ? logbook.finalText!
                : draft.draftText;
            seed = 'rejected:${logbook.id}';
          } else {
            desired = draft.draftText;
            seed = draft.analysisId;
          }
          if (_seededFor != seed) {
            _editor.text = desired;
            _seededFor = seed;
            // Persist the review copy across rebuilds only.
            Future.microtask(() => ref
                .read(logbookEditProvider.notifier)
                .state = desired);
          }
          return _DraftReview(
              draft: draft, editor: _editor, logbook: logbook);
        },
      ),
    );
  }
}

class _DraftReview extends ConsumerWidget {
  const _DraftReview({
    required this.draft,
    required this.editor,
    required this.logbook,
  });

  final LogbookDraft draft;
  final TextEditingController editor;
  final LogbookState? logbook;

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = editor.text.trim();
    if (text.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.logbookSubmitEmpty)));
      return;
    }
    ref.read(logbookSubmitProvider.notifier).state = true;
    try {
      final id = await ref.watch(myInternshipIdProvider.future);
      if (id == null) return;
      final repo = ref.read(internshipRepositoryProvider);
      await repo.submitLogbook(id, text);
      refreshLogbooks(ref, id);
      if (context.mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.logbookSubmittedOk)));
      }
    } on Exception catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.logbookSubmitFailed('$e'))));
      }
    } finally {
      ref.read(logbookSubmitProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final submitting = ref.watch(logbookSubmitProvider);
    final status = logbook?.status;
    final locked = status == LogbookStatus.submitted ||
        status == LogbookStatus.validated ||
        status == LogbookStatus.official;
    final rejected = status == LogbookStatus.rejected;

    return ListView(
      padding: StegSpacing.screenPadding,
      children: [
        _AdvisoryHeader(draft: draft),
        const SizedBox(height: StegSpacing.md),
        if (status != null &&
            status != LogbookStatus.draft &&
            status != LogbookStatus.unknown) ...[
          _StatusBanner(status: status, logbook: logbook!),
          const SizedBox(height: StegSpacing.md),
        ],
        if (locked)
          _FinalContent(logbook: logbook!)
        else
          _EditorSection(
            editor: editor,
            l10n: l10n,
            onChanged: (v) =>
                ref.read(logbookEditProvider.notifier).state = v,
          ),
        if (draft.recommendations.isNotEmpty &&
            !locked) ...[
          const SizedBox(height: StegSpacing.md),
          Text(l10n.logbookSuggestions,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StegSpacing.xs),
          for (final r in draft.recommendations)
            Card(
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(r),
              ),
            ),
        ],
        if (status == null ||
            status == LogbookStatus.draft ||
            status == LogbookStatus.unknown ||
            rejected) ...[
          if (!locked) ...[
            const SizedBox(height: StegSpacing.md),
            StegButton(
              label: l10n.logbookRegenerate,
              variant: StegButtonVariant.secondary,
              icon: Icons.refresh_outlined,
              onPressed: submitting
                  ? null
                  : () => ref.invalidate(logbookDraftProvider),
            ),
          ],
          const SizedBox(height: StegSpacing.md),
          submitting
              ? StegButton(
                  label: l10n.logbookSubmitSending,
                  icon: Icons.hourglass_top,
                  onPressed: null,
                )
              : StegButton(
                  label: rejected
                      ? l10n.logbookResubmit
                      : l10n.logbookSubmit,
                  variant: StegButtonVariant.primary,
                  icon: Icons.send,
                  onPressed: () => _submit(context, ref),
                ),
        ],
      ],
    );
  }
}

/// AI advisory header (label, provenance, CIN-exclusion evidence).
class _AdvisoryHeader extends StatelessWidget {
  const _AdvisoryHeader({required this.draft});

  final LogbookDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.aiAdvisoryNote,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined),
              const SizedBox(width: StegSpacing.xs),
              Expanded(
                child: Text(l10n.aiBadge,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: StegSpacing.xs),
          Wrap(
            spacing: StegSpacing.xs,
            runSpacing: StegSpacing.xs,
            children: [
              const StegStatusChip(
                  label: 'AI', kind: StegStatusKind.info),
              if (draft.cinExcluded)
                StegStatusChip(
                    label: l10n.aiCinExcluded,
                    kind: StegStatusKind.success),
            ],
          ),
          const SizedBox(height: StegSpacing.xs),
          Text(l10n.logbookExplain,
              style: Theme.of(context).textTheme.bodyMedium),
          Text(l10n.aiAdvisoryNote,
              style: Theme.of(context).textTheme.bodySmall),
          if (draft.modelUsed.isNotEmpty)
            Text(l10n.logbookModel(draft.modelUsed),
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Backend-authoritative status callout. Text is a display hint only; the
/// status chip mirrors the server state.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.logbook});

  final LogbookStatus status;
  final LogbookState logbook;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (status) {
      LogbookStatus.submitted => l10n.logbookSubmittedBanner,
      LogbookStatus.validated => l10n.logbookValidatedBanner,
      LogbookStatus.official => l10n.logbookOfficialBanner,
      LogbookStatus.rejected => l10n.logbookRejectedBanner(
          logbook.rejectionReason?.isNotEmpty == true
              ? logbook.rejectionReason!
              : '—'),
      _ => '',
    };
    return Card(
      child: ListTile(
        leading: StegStatusChip(
          label: _label(l10n),
          kind: _kind(),
        ),
        title: Text(message),
      ),
    );
  }

  String _label(AppLocalizations l10n) => switch (status) {
        LogbookStatus.submitted => l10n.logbookStatusSubmitted,
        LogbookStatus.validated => l10n.logbookStatusValidated,
        LogbookStatus.rejected => l10n.logbookStatusRejected,
        LogbookStatus.official => l10n.logbookStatusOfficial,
        _ => '',
      };

  StegStatusKind _kind() => switch (status) {
        LogbookStatus.submitted => StegStatusKind.info,
        LogbookStatus.validated => StegStatusKind.success,
        LogbookStatus.rejected => StegStatusKind.warning,
        LogbookStatus.official => StegStatusKind.success,
        _ => StegStatusKind.neutral,
      };
}

/// Read-only view of the server-submitted content (locked states).
class _FinalContent extends StatelessWidget {
  const _FinalContent({required this.logbook});

  final LogbookState logbook;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.logbookContentLabel,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: StegSpacing.xs),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(StegSpacing.md),
            child: SelectableText(
              logbook.finalText?.isNotEmpty == true
                  ? logbook.finalText!
                  : '—',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.editor,
    required this.l10n,
    required this.onChanged,
  });

  final TextEditingController editor;
  final AppLocalizations l10n;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: l10n.logbookTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.logbookEditHint,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: StegSpacing.xs),
          TextField(
            controller: editor,
            maxLines: null,
            minLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}