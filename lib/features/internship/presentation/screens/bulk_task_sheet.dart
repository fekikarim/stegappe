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
import '../../data/models/internship_dtos.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/supervisor_tasks.dart';
import '../providers/supervisor_tasks_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/schedule_field.dart';
import '../widgets/status_labels.dart';

/// T04 bulk-add sheet (SU-HOME-01, BR-16): pick several of the supervisor's
/// own students, compose one or more tasks (shared due date + schedule),
/// preview the explicit plan, submit once with a fresh idempotency key, then
/// render the per-item result summary.
///
/// The backend executes atomically: success means every item applied; any
/// failure rolls back everything and arrives as a typed error — the sheet
/// then offers fix-and-resend (a new key is generated per submit, never
/// reused across payloads).
class BulkTaskSheet extends ConsumerStatefulWidget {
  const BulkTaskSheet({super.key});

  static Future<void> show(BuildContext context) => showStegSheet<void>(
        context,
        title: AppLocalizations.of(context).supBulkTitle,
        builder: (_) => const BulkTaskSheet(),
      );

  @override
  ConsumerState<BulkTaskSheet> createState() => _BulkTaskSheetState();
}

class _ComposedTask {
  final TextEditingController title = TextEditingController();
  final TextEditingController description = TextEditingController();

  void dispose() {
    title.dispose();
    description.dispose();
  }
}

class _BulkTaskSheetState extends ConsumerState<BulkTaskSheet> {
  final Set<String> _students = {};
  final List<_ComposedTask> _tasks = [_ComposedTask()];
  DateTime? _due;
  DateTime? _scheduled;
  Object? _error;
  SupervisorBulkResult? _result;

  @override
  void dispose() {
    for (final t in _tasks) {
      t.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _students.isNotEmpty &&
      _tasks.any((t) => t.title.text.trim().isNotEmpty);

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) setState(() => _due = picked);
  }

  Future<void> _pickSchedule() async {
    final picked = await pickTunisMoment(context, initial: _scheduled);
    if (picked != null && mounted) setState(() => _scheduled = picked);
  }

  Future<void> _submit() async {
    if (!_valid) {
      setState(() => _error = StateError('bulk-empty'));
      return;
    }
    setState(() => _error = null);
    final mutations = [
      for (final t in _tasks)
        if (t.title.text.trim().isNotEmpty)
          for (final internshipId in _students)
            bulkMutationJson(
              action: 'CREATE',
              internshipId: internshipId,
              task: taskWriteJson(
                title: t.title.text.trim(),
                description: t.description.text.trim().isEmpty
                    ? null
                    : t.description.text.trim(),
                dueDate: _due,
                visibleFrom: _scheduled,
              ),
            ),
    ];
    final result = await ref
        .read(supervisorTaskControllerProvider.notifier)
        .bulkTasks(mutations);
    if (!mounted) return;
    if (result == null) {
      setState(() => _error = ref
          .read(supervisorTaskControllerProvider)
          .error);
    } else {
      setState(() => _result = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final internsAsync = ref.watch(supervisedInternsProvider);
    final busy = ref.watch(supervisorTaskControllerProvider).busy;

    return internsAsync.when(
      loading: () => const StegLoading(),
      error: (e, _) => StegErrorView(
        message: context.userError(e).message,
        onRetry: () => ref.invalidate(supervisedInternsProvider),
      ),
      data: (interns) {
        if (_result != null) {
          return _ResultView(
              result: _result!,
              interns: interns,
              onClose: () => setState(() => _result = null));
        }
        if (_students.isEmpty && interns.isNotEmpty) {
          // Default: every own student (explicit, visible, changeable).
          _students.addAll(interns.map((i) => i.internshipId));
        }
        final validCount = _tasks
            .where((t) => t.title.text.trim().isNotEmpty)
            .length;
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.supBulkPlan(validCount, _students.length),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: StegSpacing.xs),
              Wrap(
                spacing: StegSpacing.xs,
                runSpacing: StegSpacing.xxs,
                children: [
                  for (final intern in interns)
                    FilterChip(
                      label: Text(intern.internName),
                      selected: _students.contains(intern.internshipId),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _students.add(intern.internshipId);
                        } else {
                          _students.remove(intern.internshipId);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: StegSpacing.sm),
              for (var i = 0; i < _tasks.length; i++) ...[
                _TaskComposer(
                  index: i,
                  composed: _tasks[i],
                  removable: _tasks.length > 1,
                  onRemove: () =>
                      setState(() => _tasks.removeAt(i).dispose()),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: StegSpacing.xs),
              ],
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _tasks.add(_ComposedTask())),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.supBulkAddTask),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        _due == null
                            ? '${l10n.taskDueLabel} : ${l10n.noDueDate}'
                            : '${l10n.taskDueLabel} : ${formatDay(_due!, Localizations.localeOf(context))}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  // T15: bounded actions (66 px right overflow at 2.0×
                  // measured).
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.sizeOf(context).width * 0.32),
                    child: TextButton(
                      onPressed: _pickDue,
                      child: Text(l10n.taskPickDate,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (_due != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.sizeOf(context).width * 0.32),
                      child: TextButton(
                        onPressed: () => setState(() => _due = null),
                        child: Text(l10n.taskClearDate,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                ],
              ),
              ScheduleField(
                scheduled: _scheduled,
                onPick: _pickSchedule,
                onClear: () => setState(() => _scheduled = null),
              ),
              if (_error != null) ...[
                const SizedBox(height: StegSpacing.xs),
                Text(
                  _error is StateError
                      ? l10n.supBulkEmpty
                      : context.userError(_error!).message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color:
                              Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: StegSpacing.sm),
              StegButton(
                label: l10n.supBulkSubmit,
                icon: Icons.group_add_outlined,
                loading: busy,
                onPressed: !isOnline || busy || !_valid
                    ? null
                    : _submit,
              ),
              if (!isOnline)
                Padding(
                  padding:
                      const EdgeInsets.only(top: StegSpacing.xs),
                  child: Text(l10n.supNeedsConnection,
                      style:
                          Theme.of(context).textTheme.bodySmall),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskComposer extends StatefulWidget {
  const _TaskComposer({
    required this.index,
    required this.composed,
    required this.removable,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _ComposedTask composed;
  final bool removable;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_TaskComposer> createState() => _TaskComposerState();
}

class _TaskComposerState extends State<_TaskComposer> {
  @override
  void initState() {
    super.initState();
    widget.composed.title.addListener(widget.onChanged);
    widget.composed.description.addListener(widget.onChanged);
  }

  @override
  void didUpdateWidget(_TaskComposer old) {
    super.didUpdateWidget(old);
    if (old.composed != widget.composed) {
      old.composed.title.removeListener(old.onChanged);
      old.composed.description.removeListener(old.onChanged);
      widget.composed.title.addListener(widget.onChanged);
      widget.composed.description.addListener(widget.onChanged);
    }
  }

  @override
  void dispose() {
    widget.composed.title.removeListener(widget.onChanged);
    widget.composed.description.removeListener(widget.onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${l10n.taskTitleLabel} ${widget.index + 1}',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
                if (widget.removable)
                  IconButton(
                    tooltip: l10n.supTaskDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            StegTextField(
              controller: widget.composed.title,
              label: l10n.taskTitleLabel,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: StegSpacing.xs),
            StegTextField(
              controller: widget.composed.description,
              label: l10n.taskDescLabel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-item result summary: never a silent partial — every requested pair
/// renders applied/failed with its student.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.interns,
    required this.onClose,
  });

  final SupervisorBulkResult result;
  final List<SupervisedIntern> interns;
  final VoidCallback onClose;

  String _studentName(String? internshipId) {
    for (final i in interns) {
      if (i.internshipId == internshipId) return i.internName;
    }
    return internshipId ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.supBulkDone(result.okCount),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: StegSpacing.xs),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: result.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
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
                title: Text(_studentName(item.internshipId),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('#${item.index + 1} • ${item.action}'),
                trailing: Text(item.status),
              );
            },
          ),
        ),
        const SizedBox(height: StegSpacing.sm),
        StegButton(label: l10n.closeAction, onPressed: onClose),
      ],
    );
  }
}
