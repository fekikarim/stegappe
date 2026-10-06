import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/offline/pending_writes.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/task_classification.dart';
import '../../domain/entities/work_items.dart';
import '../providers/classification_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/category_chip.dart';
import '../widgets/status_labels.dart';

/// Single task row: completion toggle, title, due date, status chip, and — for
/// the two states the app used to hide — the awaiting-approval notice
/// (BR-11/D6) or the supervisor's denial reason (BR-12/ST-TASK-07).
///
/// The toggle is OPTIMISTIC (reversible action): the new state shows
/// immediately and rolls back with an error message if the server rejects it.
/// It never fabricates approval: the only targets are the student's own
/// transitions (`studentToggleTarget`).
class TaskRow extends ConsumerStatefulWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.now,
    this.onOpen,
    this.editable = true,
    this.compact = false,
    this.category,
    this.showUnclassifiedMarker = false,
  });

  final InternTask task;
  final DateTime now;
  final VoidCallback? onOpen;

  /// Whether the student may move THIS task through the workflow (a role
  /// question; authorship is BR-14 and only gates the editor, never progress).
  final bool editable;
  final bool compact;

  /// Personal classification (T03): purely organizational, rendered
  /// secondarily to the status chip and never changing it.
  final TaskCategory? category;

  /// Show the "unclassified" marker when the board has categories but this
  /// task carries none.
  final bool showUnclassifiedMarker;

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
    final target = studentToggleTarget(_shown);
    if (target == null) return;
    // T06/D12 offline path: accept into the visible persisted queue instead
    // of failing — the flush applies it exactly once with its own key.
    if (!ref.read(isOnlineProvider)) {
      final ok = await ref
          .read(pendingWritesProvider.notifier)
          .enqueueStatus(taskId: widget.task.id, status: target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? AppLocalizations.of(context).offlineQueued
              : AppLocalizations.of(context).queueFull),
        ),
      );
      return;
    }
    setState(() {
      _optimistic = target;
      _syncing = true;
    });
    try {
      await ref
          .read(internshipRepositoryProvider)
          .updateTaskStatus(widget.task.id, target);
      ref
        ..invalidate(taskListProvider)
        ..invalidate(dashboardProvider);
    } on ApiException catch (e) {
      // Roll back: never display an unconfirmed state.
      if (mounted) {
        setState(() => _optimistic = null);
        if (e.kind == ApiErrorKind.network) {
          // Lost connectivity mid-write: queue it instead of dropping it.
          final ok = await ref
              .read(pendingWritesProvider.notifier)
              .enqueueStatus(taskId: widget.task.id, status: target);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok
                  ? AppLocalizations.of(context).offlineQueued
                  : AppLocalizations.of(context).queueFull),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.userError(e).message),
            ),
          );
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _optimistic = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.userError(e).message),
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
    // T03: the card resolves its own classification chip from the board so
    // every surface (board columns, flat list) renders it without threading
    // props through each layout. Absent board = no chips, never a crash.
    final board = ref.watch(classificationBoardProvider).valueOrNull ??
        ref.watch(lastClassificationProvider);
    final category =
        (widget.category ?? board?.categoryById(board.categoryOf(widget.task.id)));
    final showUnclassified = widget.showUnclassifiedMarker ||
        (board != null &&
            board.categories.isNotEmpty &&
            board.categoryOf(widget.task.id) == null);
    final shown = _shown;
    final target = studentToggleTarget(shown);
    // BR-11: "finished by the student" — either awaiting the supervisor's
    // decision or already approved. A denied task is never shown as done.
    final finished =
        shown == TaskStatus.awaitingApproval || shown == TaskStatus.approved;
    final isOpen = shown == TaskStatus.todo || shown == TaskStatus.inProgress;
    final overdue = isOpen && widget.task.isOverdue(widget.now);
    final denialReason = shown == TaskStatus.denied
        ? widget.task.denialReason
        : null;

    return Semantics(
      label: '${widget.task.title}, ${taskStatusLabel(shown, l10n)}',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: widget.compact ? StegSpacing.xxs : StegSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: StegSpacing.minTouchTarget,
                  height: StegSpacing.minTouchTarget,
                  child: Tooltip(
                    message: target == null
                        ? taskStatusLabel(shown, l10n)
                        : taskTransitionLabel(shown, target, l10n),
                    child: Checkbox(
                      value: finished,
                      onChanged: widget.editable && target != null
                          ? (_) => _toggle()
                          : null,
                    ),
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
                              decoration: finished
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
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StegStatusChip(
                        label: taskStatusLabel(shown, l10n),
                        kind: taskStatusKind(shown, overdue: overdue),
                      ),
                      // T06/D12: a visibly pending queued write — never shown
                      // as sent. The chip disappears when the flush lands.
                      if (ref.watch(pendingWritesProvider.select(
                          (s) => s.hasQueuedStatus(widget.task.id))))
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 2),
                          child: StegStatusChip(
                            label: l10n.pendingLabel,
                            kind: StegStatusKind.info,
                          ),
                        ),
                    ],
                  ),
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
            if (shown == TaskStatus.awaitingApproval)
              _Notice(
                icon: Icons.hourglass_top_outlined,
                text: l10n.taskWaitingReview,
                kind: StegStatusKind.warning,
              ),
            if (category != null || showUnclassified)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: StegSpacing.minTouchTarget, top: 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: category != null
                      ? CategoryChip(category: category)
                      : const UnclassifiedMarker(),
                ),
              ),            if (denialReason != null)
              _Notice(
                icon: Icons.report_outlined,
                label: l10n.taskDenialReason,
                text: denialReason,
                caption: widget.task.reviewedAt == null
                    ? null
                    : l10n.taskReviewedOn(
                        formatDay(widget.task.reviewedAt!, locale)),
                kind: StegStatusKind.error,
              ),
          ],
        ),
      ),
    );
  }
}

/// Inline, non-modal explanation under a task (never hidden behind a dialog).
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    required this.kind,
    this.label,
    this.caption,
  });

  final IconData icon;
  final String text;
  final String? label;
  final String? caption;
  final StegStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (kind) {
      StegStatusKind.error => theme.colorScheme.error,
      StegStatusKind.warning => theme.colorScheme.tertiary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(
          start: StegSpacing.minTouchTarget, top: StegSpacing.xxs),
      child: Container(
        padding: const EdgeInsets.all(StegSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(StegSpacing.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: StegSpacing.xxs),
                Expanded(
                  child: Text(
                    label == null ? text : '$label : $text',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
