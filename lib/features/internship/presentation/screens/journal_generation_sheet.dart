import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../domain/entities/work_items.dart';
import '../providers/journal_document_providers.dart';
import '../providers/workspace_providers.dart';
import '../services/file_share.dart';
import 'journal_composer_screen.dart';

/// T09/B5+B6 — the student's journal generation flow (ST-JRN-03…06).
///
/// The server owns everything that matters: the eligibility window
/// ([JournalEligibility] comes from the API), the AI call, the strict schema,
/// the PDF (period + task table) and the deliverable. This sheet only renders
/// state and sends intents:
///
/// * chooser — from my tasks / from my text (one sentence each, with the
///   <75 % warning and the empty-task note shown BEFORE generating, BR-24);
/// * progress — cancellable (cancelling abandons the wait; the server may have
///   persisted the draft, so the lists are refreshed and the truth is shown);
/// * result — preview through the platform viewer, regenerate (with a confirm
///   that the previous draft is discarded) and keep (which notifies nobody,
///   ST-JRN-06);
/// * degraded AI — the localized sentence from the backend code plus the
///   manual journal-entry path one tap away (BR-50).
/// T09/ST-JRN-03 — the prominent red, full-width journal generation action.
///
/// It is VISIBLE but honestly disabled outside the server's window, with the
/// reason ("available in N days", BR-20/BR-21): the backend decides the window,
/// this bar only mirrors its decision and never derives dates from the device
/// clock. Offline says so instead of failing silently (D12). The eligibility
/// read also carries the <75 % warning (BR-24), which the sheet shows BEFORE
/// generating.
class JournalGenerationBar extends ConsumerWidget {
  const JournalGenerationBar({super.key, required this.internshipId});

  final String internshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final eligibility =
        ref.watch(journalEligibilityProvider(internshipId)).valueOrNull;
    final isOnline = ref.watch(isOnlineProvider);
    final enabled = isOnline && eligibility != null && eligibility.eligible;

    final String? reason = eligibility == null
        ? null
        : !isOnline
            ? l10n.journalGenOffline
            : eligibility.beforeWindow
                ? l10n.journalGenOpensIn(eligibility.daysUntilOpen)
                : eligibility.eligible
                    ? null
                    : eligibility.reason == 'CANCELLED'
                        ? l10n.journalGenCancelled
                        : l10n.journalGenNoPeriod;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
          start: StegSpacing.md, end: StegSpacing.md, top: StegSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            child: StegButton(
              label: l10n.journalGenButton,
              icon: Icons.auto_awesome,
              variant: StegButtonVariant.destructive,
              onPressed: enabled
                  ? () => showJournalGenerationSheet(
                        context,
                        ref,
                        internshipId: internshipId,
                        eligibility: eligibility,
                      )
                  : null,
            ),
          ),
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: StegSpacing.xs),
              child: Text(reason,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

Future<void> showJournalGenerationSheet(
  BuildContext context,
  WidgetRef ref, {
  required String internshipId,
  required JournalEligibility eligibility,
}) {
  ref.read(journalGenerationProvider.notifier).reset();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => JournalGenerationSheet(
      internshipId: internshipId,
      eligibility: eligibility,
    ),
  );
}

class JournalGenerationSheet extends ConsumerStatefulWidget {
  const JournalGenerationSheet({
    super.key,
    required this.internshipId,
    required this.eligibility,
  });

  final String internshipId;
  final JournalEligibility eligibility;

  @override
  ConsumerState<JournalGenerationSheet> createState() =>
      _JournalGenerationSheetState();
}

class _JournalGenerationSheetState
    extends ConsumerState<JournalGenerationSheet> {
  final _text = TextEditingController();
  bool _textPath = false;
  bool _sharing = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _share(JournalGenerationResult result) async {
    setState(() => _sharing = true);
    final l10n = AppLocalizations.of(context);
    try {
      await downloadAndShare(ref,
          deliverableId: result.deliverableId, fileName: result.fileName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.journalGenOpenFailed)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Re-runs the last kind of attempt (text when the student used the text
  /// path, tasks otherwise) — the retry action of the failure state.
  Future<void> _runCurrent() async {
    final controller = ref.read(journalGenerationProvider.notifier);
    if (_textPath || _text.text.trim().isNotEmpty) {
      await controller.generateFromText(
          widget.internshipId, _text.text.trim());
    } else {
      await controller.generateFromTasks(widget.internshipId);
    }
  }

  Future<void> _confirmRegenerate() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showStegConfirmDialog(
      context,
      title: l10n.journalGenRegenerate,
      message: l10n.journalGenRegenerateConfirm,
      confirmLabel: l10n.journalGenRegenerate,
      cancelLabel: l10n.journalGenCancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runCurrent();
  }

  void _openManualPath() {
    final day = ref.read(selectedDayProvider);
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JournalComposerScreen(
        internshipId: widget.internshipId,
        day: day,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(journalGenerationProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.journalGenTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: StegSpacing.sm),
              _AdvisoryNote(l10n: l10n),
              const SizedBox(height: StegSpacing.sm),
              _FactsNotes(
                eligibility: widget.eligibility,
                l10n: l10n,
              ),
              const SizedBox(height: StegSpacing.sm),
              if (state.isGenerating)
                _Progress(l10n: l10n)
              else if (state.status == JournalGenerationStatus.done &&
                  state.result != null)
                _Result(
                  result: state.result!,
                  sharing: _sharing,
                  l10n: l10n,
                  onOpen: () => _share(state.result!),
                  onRegenerate: _confirmRegenerate,
                  onKeep: () => Navigator.of(context).pop(),
                  onManual: _openManualPath,
                )
              else if (state.status == JournalGenerationStatus.failed)
                _Failure(
                  state: state,
                  l10n: l10n,
                  onRetry: _runCurrent,
                  onManual: _openManualPath,
                  onChooser: () => ref
                      .read(journalGenerationProvider.notifier)
                      .reset(),
                )
              else if (_textPath)
                _TextForm(
                  controller: _text,
                  l10n: l10n,
                  onStart: () => ref
                      .read(journalGenerationProvider.notifier)
                      .generateFromText(
                          widget.internshipId, _text.text.trim()),
                  onBack: () => setState(() => _textPath = false),
                )
              else
                _Chooser(
                  l10n: l10n,
                  onTasks: () => ref
                      .read(journalGenerationProvider.notifier)
                      .generateFromTasks(widget.internshipId),
                  onText: () => setState(() => _textPath = true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvisoryNote extends StatelessWidget {
  const _AdvisoryNote({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.auto_awesome, size: 16),
          const SizedBox(width: StegSpacing.xs),
          Expanded(
            child: Text(l10n.aiAdvisoryNote,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      );
}

/// BR-24 (warning before generating) + honest empty/late states.
class _FactsNotes extends StatelessWidget {
  const _FactsNotes({required this.eligibility, required this.l10n});

  final JournalEligibility eligibility;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final notes = <String>[
      if (eligibility.belowThreshold)
        l10n.journalGenBelowThreshold(
            eligibility.approvedTasks, eligibility.taskCount),
      if (eligibility.taskCount == 0) l10n.journalGenNoTasks,
      if (eligibility.isLate) l10n.journalGenLate,
    ];
    if (notes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: StegSpacing.xs),
            child: Text(note, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _Chooser extends StatelessWidget {
  const _Chooser({
    required this.l10n,
    required this.onTasks,
    required this.onText,
  });

  final AppLocalizations l10n;
  final VoidCallback onTasks;
  final VoidCallback onText;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.journalGenChooserHint,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: StegSpacing.sm),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: Text(l10n.journalGenFromTasks),
            subtitle: Text(l10n.journalGenFromTasksHint),
            onTap: onTasks,
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(l10n.journalGenFromText),
            subtitle: Text(l10n.journalGenFromTextHint),
            onTap: onText,
          ),
          const SizedBox(height: StegSpacing.xs),
          StegButton(
            label: l10n.journalGenCancel,
            variant: StegButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
}

class _TextForm extends StatefulWidget {
  const _TextForm({
    required this.controller,
    required this.l10n,
    required this.onStart,
    required this.onBack,
  });

  final TextEditingController controller;
  final AppLocalizations l10n;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  State<_TextForm> createState() => _TextFormState();
}

class _TextFormState extends State<_TextForm> {
  @override
  Widget build(BuildContext context) {
    final used = widget.controller.text.trim().length;
    final tooShort = used < kJournalTextMinLength;
    final tooLong = used > kJournalTextMaxLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: 6,
          maxLength: kJournalTextMaxLength,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: widget.l10n.journalGenTextLabel,
            hintText: widget.l10n.journalGenTextHint,
            counterText: widget.l10n.journalGenTextCounter(
                used, kJournalTextMaxLength),
            errorText: tooShort
                ? widget.l10n.journalGenTextTooShort(kJournalTextMinLength)
                : tooLong
                    ? widget.l10n.errJournalTextInvalid
                    : null,
          ),
        ),
        const SizedBox(height: StegSpacing.sm),
        StegButton(
          label: widget.l10n.journalGenStart,
          icon: Icons.auto_awesome,
          onPressed: tooShort || tooLong ? null : widget.onStart,
        ),
        StegButton(
          label: widget.l10n.journalGenCancel,
          variant: StegButtonVariant.text,
          onPressed: widget.onBack,
        ),
      ],
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: StegSpacing.sm),
          Text(l10n.journalGenProgress,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: StegSpacing.sm),
          StegButton(
            label: l10n.journalGenCancel,
            variant: StegButtonVariant.secondary,
            onPressed: () =>
                ref.read(journalGenerationProvider.notifier).cancel(),
          ),
        ],
      );
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.sharing,
    required this.l10n,
    required this.onOpen,
    required this.onRegenerate,
    required this.onKeep,
    required this.onManual,
  });

  final JournalGenerationResult result;
  final bool sharing;
  final AppLocalizations l10n;
  final VoidCallback onOpen;
  final VoidCallback onRegenerate;
  final VoidCallback onKeep;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(result.title,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StegSpacing.xs),
          Text(l10n.journalGenDone(result.currentVersion),
              style: Theme.of(context).textTheme.bodyMedium),
          Text(result.source == 'TEXT'
              ? l10n.journalGenSourceText
              : l10n.journalGenSourceTasks,
              style: Theme.of(context).textTheme.bodySmall),
          if (result.replacedDraft)
            Padding(
              padding: const EdgeInsets.only(top: StegSpacing.xs),
              child: Text(l10n.journalGenReplaced,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (result.previousSubmitted)
            Padding(
              padding: const EdgeInsets.only(top: StegSpacing.xs),
              child: Text(l10n.journalGenPreviousSubmitted,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (result.belowThreshold)
            Padding(
              padding: const EdgeInsets.only(top: StegSpacing.xs),
              child: Text(
                  l10n.journalGenBelowThreshold(
                      result.approvedTasks, result.taskCount),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: StegSpacing.sm),
          StegButton(
            label: l10n.journalGenOpen,
            icon: Icons.picture_as_pdf_outlined,
            loading: sharing,
            onPressed: onOpen,
          ),
          const SizedBox(height: StegSpacing.xs),
          StegButton(
            label: l10n.journalGenRegenerate,
            variant: StegButtonVariant.secondary,
            icon: Icons.refresh,
            onPressed: onRegenerate,
          ),
          const SizedBox(height: StegSpacing.xs),
          StegButton(
            label: l10n.journalGenKeep,
            variant: StegButtonVariant.secondary,
            onPressed: onKeep,
          ),
          Padding(
            padding: const EdgeInsets.only(top: StegSpacing.xs),
            child: Text(l10n.journalGenKeepNote,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          StegButton(
            label: l10n.journalGenManualPath,
            variant: StegButtonVariant.text,
            onPressed: onManual,
          ),
        ],
      );
}

/// BR-50: a failed generation never blocks the manual path and never shows a
/// raw provider error — the localized sentence comes from the typed code.
class _Failure extends StatelessWidget {
  const _Failure({
    required this.state,
    required this.l10n,
    required this.onRetry,
    required this.onManual,
    required this.onChooser,
  });

  final JournalGenerationState state;
  final AppLocalizations l10n;
  final VoidCallback onRetry;
  final VoidCallback onManual;
  final VoidCallback onChooser;

  @override
  Widget build(BuildContext context) {
    final message = state.offline
        ? l10n.journalGenOffline
        : userErrorOf(
                state.error ?? StateError('journal-generation-failed'),
                l10n)
            .message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: StegSpacing.sm),
        StegButton(
          label: l10n.retry,
          icon: Icons.refresh,
          onPressed: onRetry,
        ),
        const SizedBox(height: StegSpacing.xs),
        StegButton(
          label: l10n.journalGenManualPath,
          variant: StegButtonVariant.secondary,
          onPressed: onManual,
        ),
        StegButton(
          label: l10n.journalGenCancel,
          variant: StegButtonVariant.text,
          onPressed: onChooser,
        ),
      ],
    );
  }
}
