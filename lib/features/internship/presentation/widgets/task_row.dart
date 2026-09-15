import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/status_labels.dart';

/// Single task row: checkbox, title, due date, status chip.
///
/// Completion toggle is OPTIMISTIC (reversible action): the new state
/// shows immediately and rolls back with an error message if the server
/// rejects it. Tapping opens the detail/editor (provided by parent).
class TaskRow extends ConsumerStatefulWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.now,
    this.onOpen,
    this.editable = true,
    this.compact = false,
  });

  final InternTask task;
  final DateTime now;
  final VoidCallback? onOpen;
  final bool editable;
  final bool compact;

  @override
  ConsumerState<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<TaskRow> {
  /// Local optimistic override; null = show server truth.
  TaskStatus? _optimistic;
  bool _syncing = false;

  TaskStatus get _shown => _optimistic ?? widget.task.status;

  @override
  void didUpdateWidget(TaskRow old) {
    super.didUpdateWidget(old);
    // Server truth arrived (invalidate after write): drop the override.
    if (old.task.status != widget.task.status) _optimistic = null;
  }

  Future<void> _toggle() async {
    if (_syncing) return;
    final next = widget.task.isDone ? TaskStatus.todo : TaskStatus.completed;
    setState(() {
      _optimistic = next;
      _syncing = true;
    });
    try {
      await ref
          .read(internshipRepositoryProvider)
          .updateTaskStatus(widget.task.id, next);
      ref
        ..invalidate(taskListProvider)
        ..invalidate(dashboardProvider);
    } on Exception catch (e) {
      // Roll back: never display an unconfirmed state.
      if (mounted) {
        setState(() => _optimistic = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final shownDone = _shown == TaskStatus.completed;
    final overdue =
        widget.task.copyWithStatus(_shown).isOverdue(widget.now);

    return Semantics(
      label: '${widget.task.title}, ${taskStatusLabel(_shown, l10n)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: StegSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: StegSpacing.minTouchTarget,
              height: StegSpacing.minTouchTarget,
              child: Checkbox(
                value: shownDone,
                onChanged: widget.editable ? (_) => _toggle() : null,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.task.title,
                    maxLines: widget.compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                          decoration: shownDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.task.dueDate == null
                        ? l10n.noDueDate
                        : formatDay(widget.task.dueDate!, locale),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: overdue
                              ? Theme.of(context).colorScheme.error
                              : null,
                          fontWeight:
                              overdue ? FontWeight.w700 : null,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: StegSpacing.xs),
            StegStatusChip(
              label: taskStatusLabel(_shown, l10n),
              kind: taskStatusKind(_shown, overdue: overdue),
            ),
            if (widget.onOpen != null)
              Semantics(
                button: true,
                label: widget.task.title,
                child: IconButton(
                  tooltip: widget.task.title,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: widget.onOpen,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension on InternTask {
  InternTask copyWithStatus(TaskStatus s) => InternTask(
        id: id,
        title: title,
        description: description,
        status: s,
        dueDate: dueDate,
        completedAt: completedAt,
      );
}
