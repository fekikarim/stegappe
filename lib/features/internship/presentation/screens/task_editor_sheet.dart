import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import '../../domain/schedule.dart';
import '../providers/supervisor_tasks_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/schedule_field.dart' show pickTunisMoment;
import '../widgets/status_labels.dart';

/// T15: the share of a row an inline action may occupy before it truncates.
/// Keeps the label readable at 1.0× and makes an overflow impossible at 2.0×.
BoxConstraints _actionBox(BuildContext context) =>
    BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.32);

/// Task create/edit sheet.
/// - Creation: a new task for the internship (status defaults to `todo`).
/// - Edit: the author may edit any field; a student may only edit his *own*
///   tasks (BR-14). The status chip set is scoped to what the current actor
///   may legitimately write — students never see `APPROVED`/`DENIED`/`CANCELLED`
///   (staff review decisions) and `unknown` is never part of the vocabulary.
/// - Staff mode (T04/SU-TASK-01/03/04): the supervisor creates/edits for the
///   chosen student, with an optional schedule (D8): the task appears to the
///   student at the picked Tunis moment, immediately when cleared. Status is
///   never edited here in staff mode — review owns it (BR-11).
class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.internshipId,
    this.existing,
    this.staffMode = false,
  });

  final String internshipId;
  final InternTask? existing;

  /// Supervisor editing/creating for a student (own scope enforced by the
  /// backend; the UI gate is UX only).
  final bool staffMode;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();

  static Future<void> show(
    BuildContext context, {
    required String internshipId,
    InternTask? existing,
    bool staffMode = false,
  }) =>
      showStegSheet(
        context,
        title: existing == null
            ? (staffMode
                ? AppLocalizations.of(context).supTaskNew
                : AppLocalizations.of(context).taskNew)
            : (staffMode
                ? AppLocalizations.of(context).supTaskEdit
                : AppLocalizations.of(context).taskEdit),
        builder: (_) => TaskEditorSheet(
            internshipId: internshipId,
            existing: existing,
            staffMode: staffMode),
      );
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  DateTime? _due;
  TaskStatus? _status;
  // T04/D8 schedule: absolute UTC instant (Tunis wall converted on pick).
  // Null = immediate on create, unchanged on update.
  DateTime? _scheduled;
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
    _scheduled = widget.existing?.visibleFrom;
    // A student may only edit his own tasks (BR-14). A task whose
    // authorship is unknown (legacy row, absent `createdById`) defaults to
    // supervisor-authored — the safe answer is read-only. Staff mode always
    // edits (scope is enforced server-side, 404 out of scope).
    _canEdit = widget.staffMode ||
        (_isEdit
            ? studentOwnsTask(widget.existing!, _currentUser?.id)
            : _isIntern);
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
          _due != null ||
          _scheduled != null;
    }
    return _title.text != e.title ||
        _description.text != (e.description ?? '') ||
        _due != e.dueDate ||
        _status != e.status ||
        _scheduled != e.visibleFrom;
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
            status: widget.staffMode ? null : _status,
            visibleFrom: widget.staffMode ? _scheduled : null);
      } else {
        await repo.createTask(widget.internshipId,
            title: _title.text.trim(),
            description:
                _description.text.trim().isEmpty ? null : _description.text.trim(),
            dueDate: _due,
            visibleFrom: widget.staffMode ? _scheduled : null);
      }
      if (widget.staffMode) {
        ref
          ..invalidate(supervisorTasksProvider)
          ..invalidate(supervisedInternsProvider)
          ..invalidate(
              supervisedInternDetailProvider(widget.internshipId));
      } else {
        ref
          ..invalidate(taskListProvider)
          ..invalidate(dashboardProvider);
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.staffMode
                  ? (_isEdit ? l10n.supTaskUpdated : l10n.supTaskCreated)
                  : l10n.taskSaved)),
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

  /// T04/D8 schedule pickers: Tunis wall date + time → absolute UTC instant.
  /// Clearing means immediate on create; on edit it stamps "now" (a past
  /// instant is immediate server-side, since null would mean "unchanged").
  Future<void> _pickScheduleDate() async {
    final picked =
        await pickTunisMoment(context, initial: _scheduled);
    if (picked != null && mounted) setState(() => _scheduled = picked);
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // T15: the two actions are bounded so a long label at 2.0×
              // ellipsizes instead of overflowing the row by 66 px (measured).
              ConstrainedBox(
                constraints: _actionBox(context),
                child: TextButton(
                  onPressed: _pickDate,
                  child: Text(l10n.taskPickDate,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              if (_due != null)
                ConstrainedBox(
                  constraints: _actionBox(context),
                  child: TextButton(
                    onPressed: () => setState(() => _due = null),
                    child: Text(l10n.taskClearDate,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
            ],
          ),
          if (widget.staffMode) ...[
            const SizedBox(height: StegSpacing.sm),
            _ScheduleRow(
              scheduled: _scheduled,
              onPick: _pickScheduleDate,
              onClear: () => setState(() => _scheduled =
                  _isEdit ? DateTime.now().toUtc() : null),
            ),
          ],
          if (_isEdit && !widget.staffMode) ...[
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

/// T04/D8 schedule row (staff mode only): shows the Tunis moment the task
/// appears to the student, or "immediately". Picking converts Tunis wall
/// time to an absolute UTC instant (never a bare device-local string).
class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.scheduled,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? scheduled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final moment = scheduled == null
        ? l10n.supScheduleNone
        : _formatTunisMoment(scheduled!, locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${l10n.supScheduleLabel} : $moment'),
            ),
            // T15: bounded actions (38 px right overflow at 2.0× measured).
            ConstrainedBox(
              constraints: _actionBox(context),
              child: TextButton(
                onPressed: onPick,
                child: Text(
                    scheduled == null
                        ? l10n.supSchedulePickDate
                        : l10n.supSchedulePickTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
            if (scheduled != null)
              ConstrainedBox(
                constraints: _actionBox(context),
                child: TextButton(
                  onPressed: onClear,
                  child: Text(l10n.supScheduleClear,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
        ),
        Text(
          l10n.supScheduleOutsideNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Tunis wall rendering of an absolute instant (date + 24h time, locale
/// digits via intl).
String _formatTunisMoment(DateTime instant, Locale locale) {
  final wall = tunisWallFromInstant(instant);
  final tag = locale.toString();
  final date = DateFormat.yMd(tag).format(wall);
  final time = DateFormat.Hm(tag).format(wall);
  return '$date $time';
}
