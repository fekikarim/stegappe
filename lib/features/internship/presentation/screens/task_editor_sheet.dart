import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/status_labels.dart';

/// Task create/edit sheet. Backend owns validation; client pre-validates
/// the title for immediate UX and maps server field errors inline.
class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.internshipId,
    this.existing,
  });

  final String internshipId;
  final InternTask? existing;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();

  static Future<void> show(
    BuildContext context, {
    required String internshipId,
    InternTask? existing,
  }) =>
      showStegSheet(
        context,
        title: existing == null
            ? AppLocalizations.of(context).taskNew
            : AppLocalizations.of(context).taskEdit,
        builder: (_) => TaskEditorSheet(
            internshipId: internshipId, existing: existing),
      );
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  DateTime? _due;
  TaskStatus? _status;
  bool _saving = false;
  bool _allowPop = false;
  String? _titleError;
  String? _serverError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description =
        TextEditingController(text: widget.existing?.description ?? '');
    _due = widget.existing?.dueDate;
    _status = widget.existing?.status;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _dirty {
    final e = widget.existing;
    if (e == null) {
      return _title.text.trim().isNotEmpty ||
          _description.text.trim().isNotEmpty ||
          _due != null;
    }
    return _title.text != e.title ||
        _description.text != (e.description ?? '') ||
        _due != e.dueDate ||
        _status != e.status;
  }

  Future<bool> _confirmDiscard() => showStegConfirmDialog(
        context,
        title: AppLocalizations.of(context).unsavedTitle,
        message: AppLocalizations.of(context).unsavedMessage,
        confirmLabel: AppLocalizations.of(context).discardAction,
        cancelLabel: AppLocalizations.of(context).keepEditingAction,
        destructive: true,
      );

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = l10n.taskTitleRequired);
      return;
    }
    setState(() {
      _saving = true;
      _titleError = null;
      _serverError = null;
    });
    try {
      final repo = ref.read(internshipRepositoryProvider);
      if (_isEdit) {
        await repo.updateTask(widget.existing!.id,
            title: _title.text.trim(),
            description:
                _description.text.trim().isEmpty ? null : _description.text.trim(),
            dueDate: _due,
            status: _status);
      } else {
        await repo.createTask(widget.internshipId,
            title: _title.text.trim(),
            description:
                _description.text.trim().isEmpty ? null : _description.text.trim(),
            dueDate: _due);
      }
      ref
        ..invalidate(taskListProvider)
        ..invalidate(dashboardProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.taskSaved)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _titleError = e.fieldMessage('title');
        _serverError =
            _titleError == null ? e.message : null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = e.toString();
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _due = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return PopScope(
      canPop: _allowPop || !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _dirty && !_saving && !_allowPop) {
          final discard = await _confirmDiscard();
          if (discard && context.mounted) {
            setState(() => _allowPop = true);
            Navigator.of(context).pop();
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StegTextField(
            controller: _title,
            label: l10n.taskTitleLabel,
            required: true,
            error: _titleError,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: StegSpacing.md),
          StegTextField(
            controller: _description,
            label: l10n.taskDescLabel,
          ),
          const SizedBox(height: StegSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  _due == null
                      ? '${l10n.taskDueLabel} : ${l10n.noDueDate}'
                      : '${l10n.taskDueLabel} : ${formatDay(_due!, locale)}',
                ),
              ),
              TextButton(
                onPressed: _pickDate,
                child: Text(l10n.taskPickDate),
              ),
              if (_due != null)
                TextButton(
                  onPressed: () => setState(() => _due = null),
                  child: Text(l10n.taskClearDate),
                ),
            ],
          ),
          if (_isEdit) ...[
            const SizedBox(height: StegSpacing.sm),
            Wrap(
              spacing: StegSpacing.xs,
              children: TaskStatus.values.map((s) {
                return ChoiceChip(
                  label: Text(taskStatusLabel(s, l10n)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                );
              }).toList(),
            ),
          ],
          if (_serverError != null) ...[
            const SizedBox(height: StegSpacing.sm),
            Semantics(
              liveRegion: true,
              label: _serverError,
              excludeSemantics: true,
              child: Text(_serverError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ),
          ],
          const SizedBox(height: StegSpacing.md),
          StegButton(
            label: l10n.taskSave,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
