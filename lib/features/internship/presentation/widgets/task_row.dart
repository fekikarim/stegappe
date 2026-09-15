import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import 'status_labels.dart';

/// Single task row: checkbox (server-confirmed toggle), title, due date,
/// status chip. Tapping opens the detail sheet (provided by parent).
class TaskRow extends ConsumerWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.now,
    this.onOpen,
    this.compact = false,
  });

  final InternTask task;
  final DateTime now;
  final VoidCallback? onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final overdue = task.isOverdue(now);

    return Semantics(
      button: onOpen != null,
      label: '${task.title}, ${taskStatusLabel(task.status, l10n)}',
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: StegSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: StegSpacing.minTouchTarget,
                height: StegSpacing.minTouchTarget,
                child: Checkbox(
                  value: task.isDone,
                  onChanged: (_) => _toggle(context, ref),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      task.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.dueDate == null
                          ? l10n.noDueDate
                          : formatDay(task.dueDate!, locale),
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
                label: taskStatusLabel(task.status, l10n),
                kind: taskStatusKind(task.status, overdue: overdue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final next =
        task.isDone ? TaskStatus.todo : TaskStatus.completed;
    try {
      await ref
          .read(internshipRepositoryProvider)
          .updateTaskStatus(task.id, next);
      ref
        ..invalidate(taskListProvider)
        ..invalidate(dashboardProvider);
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }
}
