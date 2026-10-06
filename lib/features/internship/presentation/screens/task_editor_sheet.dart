import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../features/auth/domain/entities/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/status_labels.dart';

/// Task create/edit sheet.
/// - Creation: a new task for the internship (status defaults to `todo`).
/// - Edit: the author may edit any field; a student may only edit his *own*
///   tasks (BR-14). The status chip set is scoped to what the current actor
///   may legitimately write — students never see `APPROVED`/`DENIED`/`CANCELLED`
///   (staff review decisions) and `unknown` is never part of the vocabulary.
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
    // A student may only edit his own tasks (BR-14). A task whose
    // authorship is unknown (legacy row, absent `createdById`) defaults to
    // supervisor-authored — the safe answer is read-only.
    _canEdit = _isEdit
        ? studentOwnsTask(widget.existing!, _currentUser?.id)
        : _isIntern;
    // Status vocabulary is scoped to the current actor. Students never see
    // staff-only review decisions; everyone excludes `unknown`.
    // (_editableStatuses is a getter computed from the current actor.)
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

  /// Current actor, if the auth controller has bootstrapped to an
  /// authenticated state. `null` = not yet known (auth not ready) — in that
  /// case authorship checks are conservative.
  AppUser? get _currentUser {
    final auth = ref.read(authControllerProvider);
    return switch (auth) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
  }

  /// `true` when the cached user is an intern (student). Used to scope the
  /// status vocabulary for the create flow and to gate edit of existing tasks.
  bool get _isIntern =>
      _currentUser?.roles.contains('INTERN') ?? false;

  /// `true` when the current actor may change the status field at all. A
  /// student editing his own task may still only pick from student statuses;
  /// a supervisor/admin editing any task sees the full writable set.
  late final bool _canEdit;



  /// Student-scoped status vocabulary (BR-11/BR-14): the student's own
  /// progress only. `APPROVED`/`DENIED`/`CANCELLED` are staff review/staff
  /// actions and `unknown` is not part of the backend vocabulary.
  static const _studentStatuses = [
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.awaitingApproval,
  ];

  List<TaskStatus> get _editableStatuses {
    // A student editing his own task still only sees student statuses;
    // a supervisor/admin editing any task sees everything writable.
    if (_isIntern) return _studentStatuses;
    return TaskStatus.values.where((s) => s != TaskStatus.unknown).toList();
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
            _titleError == null ? userMessageOf(e, l10n) : null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = userMessageOf(e, l10n);
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
          ),            if (_isEdit) ...[
            const SizedBox(height: StegSpacing.sm),
            if (!_canEdit)
              Semantics(
                label: l10n.taskNoEditSupervisorTask,
                child: Text(
                  taskStatusLabel(widget.existing!.status, l10n),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Wrap(
                spacing: StegSpacing.xs,
                children: _editableStatuses.map((s) {
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
