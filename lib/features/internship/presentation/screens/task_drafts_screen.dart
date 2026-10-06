import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/task_drafts.dart';
import '../providers/task_draft_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/schedule_field.dart';

/// T05 supervisor AI task drafts screen (SU-TASK-02).
///
/// Flow: pick the reference student → provide a PDF **or** a description →
/// generate (progress + abandon, never a blocking spinner) → review the
/// draft list (manual edit, revise-with-AI, add manually, delete) → pick
/// target students → bulk-add with an explicit per-pair result.
///
/// Drafts render as proposals (accent border + draft chip), never as tasks;
/// only bulk-add creates real tasks. Manual drafts keep the flow usable
/// when AI is down.
class TaskDraftsScreen extends ConsumerStatefulWidget {
  const TaskDraftsScreen({super.key, required this.referenceInternshipId});

  final String referenceInternshipId;

  @override
  ConsumerState<TaskDraftsScreen> createState() =>
      _TaskDraftsScreenState();
}

class _TaskDraftsScreenState extends ConsumerState<TaskDraftsScreen> {
  final TextEditingController _spec = TextEditingController();
  bool _showManualForm = false;

  TaskDraftFlowController _controller() => ref.read(
      taskDraftFlowProvider(widget.referenceInternshipId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(taskDraftFlowProvider(widget.referenceInternshipId)
              .notifier)
          .reload();
    });
  }

  @override
  void dispose() {
    _spec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final flow =
        ref.watch(taskDraftFlowProvider(widget.referenceInternshipId));
    final internsAsync = ref.watch(supervisedInternsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiDraftTitle)),
      body: RefreshIndicator(
        onRefresh: () => _controller().reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: StegSpacing.screenPadding,
          children: [
            Text(l10n.aiDraftProposalNote,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: StegSpacing.sm),
            internsAsync.when(
              loading: () => const StegLoading(),
              error: (e, _) => StegErrorView(
                message: context.userError(e).message,
                onRetry: () =>
                    ref.invalidate(supervisedInternsProvider),
              ),
              data: (interns) => _ReferencePicker(
                interns: interns,
                selected: flow.referenceInternshipId,
                onSelect: (id) {
                  _controller().setReference(id);
                  _controller().reload();
                },
              ),
            ),
            const SizedBox(height: StegSpacing.sm),
            _SourceSection(
              flow: flow,
              specController: _spec,
              isOnline: isOnline,
              onGenerate: _controller().generate,
              onAbandon: _controller().abandon,
              onPickPdf: (name, bytes) {
                _controller().setPdf(name, bytes);
              },
              onClearPdf: _controller().clearPdf,
              onSource: _controller().setSource,
              onSpecChanged: _controller().setSpecText,
            ),
            const SizedBox(height: StegSpacing.sm),
            ScheduleField(
              scheduled: flow.visibleFrom,
              onPick: () async {
                final picked = await pickTunisMoment(context,
                    initial: flow.visibleFrom);
                if (picked != null) {
                  _controller().setSchedule(picked);
                }
              },
              onClear: () => _controller().setSchedule(null),
            ),
            if (flow.error != null) ...[
              const SizedBox(height: StegSpacing.sm),
              _FlowError(
                error: flow.error!,
                hasDrafts: flow.drafts.isNotEmpty,
                onRetry: () => flow.drafts.isEmpty
                    ? _controller().generate()
                    : _controller().reload(),
              ),
            ],
            const SizedBox(height: StegSpacing.sm),
            _DraftsSection(
              referenceId: widget.referenceInternshipId,
              flow: flow,
              isOnline: isOnline,
              showManualForm: _showManualForm,
              onToggleManual: () =>
                  setState(() => _showManualForm = !_showManualForm),
              onManualAdded: () =>
                  setState(() => _showManualForm = false),
            ),
            const SizedBox(height: StegSpacing.sm),
            _TargetsSection(
              referenceId: widget.referenceInternshipId,
              flow: flow,
              isOnline: isOnline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferencePicker extends StatelessWidget {
  const _ReferencePicker({
    required this.interns,
    required this.selected,
    required this.onSelect,
  });

  final List<SupervisedIntern> interns;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: StegSpacing.xs,
      runSpacing: StegSpacing.xxs,
      children: [
        for (final intern in interns)
          ChoiceChip(
            label: Text(intern.internName),
            selected: intern.internshipId == selected,
            onSelected: (_) => onSelect(intern.internshipId),
          ),
      ],
    );
  }
}

class _SourceSection extends StatelessWidget {
  const _SourceSection({
    required this.flow,
    required this.specController,
    required this.isOnline,
    required this.onGenerate,
    required this.onAbandon,
    required this.onPickPdf,
    required this.onClearPdf,
    required this.onSource,
    required this.onSpecChanged,
  });

  final TaskDraftFlowState flow;
  final TextEditingController specController;
  final bool isOnline;
  final VoidCallback onGenerate;
  final VoidCallback onAbandon;
  final void Function(String name, Uint8List bytes) onPickPdf;
  final VoidCallback onClearPdf;
  final ValueChanged<DraftSource> onSource;
  final ValueChanged<String> onSpecChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canGenerate = isOnline &&
        !flow.generating &&
        flow.referenceInternshipId != null &&
        (flow.source == DraftSource.text ||
            flow.pdfName != null);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<DraftSource>(
              segments: [
                ButtonSegment(
                    value: DraftSource.pdf,
                    label: Text(l10n.aiDraftPdfTab),
                    icon:
                        const Icon(Icons.picture_as_pdf_outlined)),
                ButtonSegment(
                    value: DraftSource.text,
                    label: Text(l10n.aiDraftTextTab),
                    icon: const Icon(Icons.edit_note_outlined)),
              ],
              selected: {flow.source},
              onSelectionChanged: (s) => onSource(s.single),
            ),
            const SizedBox(height: StegSpacing.xs),
            if (flow.source == DraftSource.pdf)
              _PdfRow(
                  fileName: flow.pdfName,
                  isOnline: isOnline,
                  onPickPdf: onPickPdf,
                  onClearPdf: onClearPdf)
            else
              StegTextField(
                controller: specController,
                label: l10n.aiDraftTextLabel,
                hint: l10n.aiDraftTextHint,
                onChanged: onSpecChanged,
              ),
            const SizedBox(height: StegSpacing.xxs),
            Text(l10n.aiDraftAiNote,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: StegSpacing.xs),
            if (flow.generating) ...[
              if (flow.uploadProgress != null)
                LinearProgressIndicator(
                    value: flow.uploadProgress),
              const SizedBox(height: StegSpacing.xs),
              Row(
                children: [
                  Expanded(child: Text(l10n.aiDraftGenerating)),
                  TextButton(
                    onPressed: onAbandon,
                    child: Text(l10n.aiDraftCancel),
                  ),
                ],
              ),
            ] else
              StegButton(
                label: l10n.aiDraftGenerate,
                icon: Icons.auto_awesome_outlined,
                onPressed: canGenerate ? onGenerate : null,
              ),
            if (!isOnline)
              Padding(
                padding:
                    const EdgeInsets.only(top: StegSpacing.xs),
                child: Text(l10n.aiDraftNeedsConnection,
                    style:
                        Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _PdfRow extends StatelessWidget {
  const _PdfRow({
    required this.fileName,
    required this.isOnline,
    required this.onPickPdf,
    required this.onClearPdf,
  });

  final String? fileName;
  final bool isOnline;
  final void Function(String name, Uint8List bytes) onPickPdf;
  final VoidCallback onClearPdf;

  Future<void> _pick(BuildContext context) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF documents',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
        ),
      ],
    );
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    // Client pre-check mirrors the server caps (UX only; the backend
    // re-validates magic bytes + 25 MB + 50 pages authoritatively).
    if (bytes.lengthInBytes > 25 * 1024 * 1024) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)
                .errUploadRejected)));
      }
      return;
    }
    onPickPdf(file.name, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            fileName ?? l10n.aiDraftPickPdf,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: !isOnline ? null : () => _pick(context),
          child: Text(fileName == null
              ? l10n.aiDraftPickPdf
              : l10n.aiDraftChangePdf),
        ),
        if (fileName != null)
          IconButton(
            tooltip: l10n.supTaskDelete,
            icon: const Icon(Icons.clear),
            onPressed: onClearPdf,
          ),
      ],
    );
  }
}

class _FlowError extends StatelessWidget {
  const _FlowError({
    required this.error,
    required this.hasDrafts,
    required this.onRetry,
  });

  final Object error;
  final bool hasDrafts;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAiDown =
        context.userError(error).message == l10n.errAiUnavailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StegErrorView(
            message: context.userError(error).message,
            onRetry: onRetry),
        if (isAiDown)
          Padding(
            padding:
                const EdgeInsets.only(top: StegSpacing.xs),
            child: Text(l10n.aiDraftManualHint,
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _DraftsSection extends StatelessWidget {
  const _DraftsSection({
    required this.referenceId,
    required this.flow,
    required this.isOnline,
    required this.showManualForm,
    required this.onToggleManual,
    required this.onManualAdded,
  });

  final String referenceId;
  final TaskDraftFlowState flow;
  final bool isOnline;
  final bool showManualForm;
  final VoidCallback onToggleManual;
  final VoidCallback onManualAdded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.aiDraftTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: !isOnline ? null : onToggleManual,
              icon: const Icon(Icons.add),
              label: Text(l10n.aiDraftManualAdd),
            ),
          ],
        ),
        if (showManualForm)
          _ManualDraftForm(
              referenceId: referenceId,
              isOnline: isOnline,
              onAdded: onManualAdded),
        if (flow.generating && flow.drafts.isEmpty)
          const StegLoading()
        else if (flow.drafts.isEmpty)
          StegEmptyView(
            title: l10n.aiDraftEmpty,
            hint: l10n.aiDraftEmptyHint,
            icon: Icons.auto_awesome_outlined,
          )
        else
          for (final draft in flow.drafts)
            _DraftCard(
                referenceId: referenceId,
                draft: draft,
                flow: flow,
                isOnline: isOnline),
      ],
    );
  }
}

class _ManualDraftForm extends ConsumerStatefulWidget {
  const _ManualDraftForm({
    required this.referenceId,
    required this.isOnline,
    required this.onAdded,
  });

  final String referenceId;
  final bool isOnline;
  final VoidCallback onAdded;

  @override
  ConsumerState<_ManualDraftForm> createState() =>
      _ManualDraftFormState();
}

class _ManualDraftFormState extends ConsumerState<_ManualDraftForm> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  DateTime? _due;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final ok = await ref
        .read(taskDraftFlowProvider(widget.referenceId).notifier)
        .addManual(
          title: _title.text,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          dueDate: _due,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onAdded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: StegSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StegTextField(
                controller: _title, label: l10n.taskTitleLabel),
            const SizedBox(height: StegSpacing.xs),
            StegTextField(
                controller: _description,
                label: l10n.taskDescLabel),
            const SizedBox(height: StegSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(_due == null
                      ? '${l10n.taskDueLabel} : ${l10n.noDueDate}'
                      : '${l10n.taskDueLabel} : ${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-${_due!.day.toString().padLeft(2, '0')}'),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _due ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null && mounted) {
                      setState(() => _due = picked);
                    }
                  },
                  child: Text(l10n.taskPickDate),
                ),
                if (_due != null)
                  TextButton(
                    onPressed: () => setState(() => _due = null),
                    child: Text(l10n.taskClearDate),
                  ),
              ],
            ),
            const SizedBox(height: StegSpacing.xs),
            StegButton(
              label: l10n.aiDraftManualAdd,
              icon: Icons.add,
              loading: _saving,
              onPressed:
                  !widget.isOnline || _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// One draft card: proposal styling (accent border + draft chip), due date,
/// and per-item edit / revise-with-AI / delete.
class _DraftCard extends ConsumerWidget {
  const _DraftCard({
    required this.referenceId,
    required this.draft,
    required this.flow,
    required this.isOnline,
  });

  final String referenceId;
  final TaskDraft draft;
  final TaskDraftFlowState flow;
  final bool isOnline;

  TaskDraftFlowController _controller(WidgetRef ref) => ref.read(
      taskDraftFlowProvider(referenceId).notifier);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = flow.busyDraftId == draft.id;
    final actionsEnabled =
        isOnline && flow.busyDraftId == null && !flow.bulkAdding;
    return Container(
      margin: const EdgeInsets.only(bottom: StegSpacing.xs),
      padding: const EdgeInsets.all(StegSpacing.sm),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(StegSpacing.radiusSm),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .tertiary
              .withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(draft.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.bodyLarge),
              ),
              StegStatusChip(
                  label: l10n.aiDraftBadge,
                  kind: StegStatusKind.info),
            ],
          ),
          if ((draft.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(draft.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: StegSpacing.xxs),
          Text(
            draft.dueDate == null
                ? l10n.noDueDate
                : '${l10n.taskDueLabel} : ${draft.dueDate!.year}-${draft.dueDate!.month.toString().padLeft(2, '0')}-${draft.dueDate!.day.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: StegSpacing.xs),
          Wrap(
            spacing: StegSpacing.xs,
            children: [
              StegButton(
                label: l10n.aiDraftEdit,
                variant: StegButtonVariant.text,
                icon: Icons.edit_outlined,
                loading: busy,
                onPressed: actionsEnabled
                    ? () => _editDraft(context, ref)
                    : null,
              ),
              StegButton(
                label: l10n.aiDraftRevise,
                variant: StegButtonVariant.text,
                icon: Icons.auto_awesome_outlined,
                loading: busy,
                onPressed: actionsEnabled
                    ? () => _reviseDraft(context, ref)
                    : null,
              ),
              StegButton(
                label: l10n.aiDraftDelete,
                variant: StegButtonVariant.text,
                icon: Icons.delete_outline,
                loading: busy,
                onPressed: actionsEnabled
                    ? () => _deleteDraft(context, ref)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editDraft(BuildContext context, WidgetRef ref) async {
    final edited = await showDialog<_EditedDraft>(
      context: context,
      builder: (ctx) => _EditDraftDialog(draft: draft),
    );
    if (edited == null || !context.mounted) return;
    await _controller(ref).updateDraft(draft.id,
        title: edited.title,
        description: edited.description,
        dueDate: edited.dueDate);
  }

  Future<void> _reviseDraft(BuildContext context, WidgetRef ref) async {
    final instruction = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReviseDraftDialog(),
    );
    if (instruction == null ||
        instruction.trim().isEmpty ||
        !context.mounted) {
      return;
    }
    await _controller(ref).reviseDraft(draft.id, instruction.trim());
  }

  Future<void> _deleteDraft(BuildContext context, WidgetRef ref) async {    final l10n = AppLocalizations.of(context);
    final confirmed = await showStegConfirmDialog(
      context,
      title: l10n.aiDraftDeleteTitle,
      message: draft.title,
      confirmLabel: l10n.aiDraftDelete,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      await _controller(ref).deleteDraft(draft.id);
    }
  }
}

class _TargetsSection extends ConsumerWidget {
  const _TargetsSection({
    required this.referenceId,
    required this.flow,
    required this.isOnline,
  });

  final String referenceId;
  final TaskDraftFlowState flow;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final internsAsync = ref.watch(supervisedInternsProvider);
    final controller =
        ref.read(taskDraftFlowProvider(referenceId).notifier);

    if (flow.lastBulk != null) {
      return _BulkResultView(
          result: flow.lastBulk!, referenceId: referenceId);
    }
    return internsAsync.when(
      loading: () => const StegLoading(),
      error: (e, _) => StegErrorView(
        message: context.userError(e).message,
        onRetry: () => ref.invalidate(supervisedInternsProvider),
      ),
      data: (interns) {
        final canSend = isOnline &&
            !flow.bulkAdding &&
            !flow.generating &&
            flow.drafts.isNotEmpty &&
            flow.targets.isNotEmpty;
        String? hint;
        if (flow.drafts.isEmpty) {
          hint = l10n.aiDraftNoDrafts;
        } else if (flow.targets.isEmpty) {
          hint = l10n.aiDraftNoTargets;
        }
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(StegSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.aiDraftTargets,
                    style:
                        Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: StegSpacing.xs),
                Wrap(
                  spacing: StegSpacing.xs,
                  runSpacing: StegSpacing.xxs,
                  children: [
                    for (final intern in interns)
                      FilterChip(
                        label: Text(intern.internName),
                        selected: flow.targets
                            .contains(intern.internshipId),
                        onSelected: (on) => controller.toggleTarget(
                            intern.internshipId, on),
                      ),
                  ],
                ),
                if (hint != null) ...[
                  const SizedBox(height: StegSpacing.xs),
                  Text(hint,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall),
                ],
                const SizedBox(height: StegSpacing.xs),
                StegButton(
                  label: l10n.aiDraftBulkAdd,
                  icon: Icons.done_all_outlined,
                  loading: flow.bulkAdding,
                  onPressed: canSend
                      ? () => controller.bulkAdd()
                      : null,
                ),
                if (!isOnline)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: StegSpacing.xs),
                    child: Text(l10n.supNeedsConnection,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Per-pair bulk-add result: every draft-student pair renders applied with
/// its student — never a silent partial (the backend is all-or-nothing, so
/// a success screen means everything applied).
class _BulkResultView extends ConsumerWidget {
  const _BulkResultView({required this.result, required this.referenceId});

  final DraftBulkResult result;
  final String referenceId;

  String _studentName(List<SupervisedIntern> interns, String id) {
    for (final i in interns) {
      if (i.internshipId == id) return i.internName;
    }
    return id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final interns =
        ref.watch(supervisedInternsProvider).valueOrNull ?? const [];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.aiDraftBulkDone(result.okCount),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: StegSpacing.xs),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: result.items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = result.items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      item.ok
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: item.ok
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                        _studentName(interns, item.internshipId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle:
                        Text('#${item.index + 1} • ${item.status}'),
                  );
                },
              ),
            ),
            const SizedBox(height: StegSpacing.sm),
            StegButton(
              label: l10n.closeAction,
              variant: StegButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit result for one draft (null = cancelled).
class _EditedDraft {
  const _EditedDraft({required this.title, this.description, this.dueDate});

  final String title;
  final String? description;
  final DateTime? dueDate;
}

/// Draft edit dialog owning its controllers (disposed with its own State,
/// never while the pop animation still uses them).
class _EditDraftDialog extends StatefulWidget {
  const _EditDraftDialog({required this.draft});

  final TaskDraft draft;

  @override
  State<_EditDraftDialog> createState() => _EditDraftDialogState();
}

class _EditDraftDialogState extends State<_EditDraftDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.draft.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.draft.description ?? '');
  late DateTime? _due = widget.draft.dueDate;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.aiDraftEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StegTextField(
                controller: _title, label: l10n.taskTitleLabel),
            const SizedBox(height: StegSpacing.xs),
            StegTextField(
                controller: _description,
                label: l10n.taskDescLabel),
            const SizedBox(height: StegSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(_due == null
                      ? l10n.noDueDate
                      : '${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-${_due!.day.toString().padLeft(2, '0')}'),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _due ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null && mounted) {
                      setState(() => _due = picked);
                    }
                  },
                  child: Text(l10n.taskPickDate),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        StegButton(
          label: l10n.aiDraftEdit,
          onPressed: () => Navigator.of(context).pop(_EditedDraft(
            title: _title.text,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            dueDate: _due,
          )),
        ),
      ],
    );
  }
}

/// Revision-instruction dialog owning its controller.
class _ReviseDraftDialog extends StatefulWidget {
  const _ReviseDraftDialog();

  @override
  State<_ReviseDraftDialog> createState() => _ReviseDraftDialogState();
}

class _ReviseDraftDialogState extends State<_ReviseDraftDialog> {
  final TextEditingController _instruction = TextEditingController();

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.aiDraftRevise),
      content: StegTextField(
        controller: _instruction,
        label: l10n.aiDraftReviseLabel,
        hint: l10n.aiDraftReviseHint,
        textInputAction: TextInputAction.done,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        StegButton(
          label: l10n.aiDraftRevise,
          onPressed: () =>
              Navigator.of(context).pop(_instruction.text),
        ),
      ],
    );
  }
}
