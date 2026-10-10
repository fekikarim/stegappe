import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_colors.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/work_items.dart';
import '../../domain/task_board.dart';
import 'status_labels.dart';
import 'task_row.dart';

/// The status board (ST-TASK-01/06) for wide screens: one column per board
/// group, side by side, scrolling horizontally when they do not fit.
///
/// On a phone the same groups are stacked in one culled column — see
/// [buildTaskBoardSlivers] — because a second row of group tabs there only
/// duplicated the status filter above the board.
///
/// Empty groups always render (and say so) so a student never mistakes an
/// empty column for missing data. The layout is deliberately free of business
/// rules: it renders [TaskBoardSection]s produced by `buildTaskBoard` and
/// forwards the single action it owns (open a task). Progress changes stay in
/// [TaskRow], which keeps the optimistic toggle and its rollback in exactly
/// one place.
class TaskBoardView extends StatelessWidget {
  const TaskBoardView({
    super.key,
    required this.sections,
    required this.now,
    required this.editable,
    required this.onOpen,
  });

  final List<TaskBoardSection> sections;
  final DateTime now;

  /// Whether the student may move tasks through the workflow (role gate).
  final bool editable;
  final void Function(InternTask task) onOpen;

  /// Below this width the board stacks instead of showing columns.
  static const double columnsBreakpoint = 700;
  static const double columnWidth = 300;

  @override
  Widget build(BuildContext context) {
    // The parent CustomScrollView owns vertical scrolling; the columns only
    // scroll horizontally when they do not fit on screen.
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.only(
          start: StegSpacing.md, end: StegSpacing.md, bottom: StegSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in sections)
              SizedBox(
                width: columnWidth,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                      end: StegSpacing.sm),
                  child: _TaskGroupColumn(
                    section: section,
                    now: now,
                    editable: editable,
                    onOpen: onOpen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Phone-width board: the groups stacked in ONE scrollable column, each with
/// its own header. Returned as slivers so the task lists are culled like any
/// other list — a long board stays light instead of building every row.
List<Widget> buildTaskBoardSlivers({
  required List<TaskBoardSection> sections,
  required DateTime now,
  required bool editable,
  required void Function(InternTask task) onOpen,
}) {
  const horizontal = EdgeInsetsDirectional.symmetric(
      horizontal: StegSpacing.md);
  return [
    for (final section in sections) ...[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(top: StegSpacing.sm),
          child: _GroupHeader(section: section),
        ),
      ),
      if (section.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                StegSpacing.md, 0, StegSpacing.md, StegSpacing.sm),
            child: _EmptyGroup(group: section.group),
          ),
        )
      else
        SliverPadding(
          padding: horizontal,
          sliver: SliverList.builder(
            itemCount: section.tasks.length,
            itemBuilder: (context, i) => _TaskCard(
              task: section.tasks[i],
              now: now,
              editable: editable,
              onOpen: onOpen,
            ),
          ),
        ),
    ],
  ];
}

/// Tablet/desktop group column: header + cards sized to their content so the
/// whole page scrolls vertically as one.
class _TaskGroupColumn extends StatelessWidget {
  const _TaskGroupColumn({
    required this.section,
    required this.now,
    required this.editable,
    required this.onOpen,
  });

  final TaskBoardSection section;
  final DateTime now;
  final bool editable;
  final void Function(InternTask task) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHeader(section: section),
        if (section.isEmpty)
          _EmptyGroup(group: section.group)
        else
          for (final task in section.tasks)
            _TaskCard(
              task: task,
              now: now,
              editable: editable,
              onOpen: onOpen,
            ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.section});

  final TaskBoardSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = taskGroupLabel(section.group, l10n);
    final kind = taskGroupKind(section.group);
    final (fg, bg) = _groupColors(context, kind);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
          top: StegSpacing.xs, bottom: StegSpacing.xs),
      child: Semantics(
        header: true,
        label: '$label: ${section.count}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: StegSpacing.sm, vertical: StegSpacing.xs),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
            border: Border.all(color: fg.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: StegSpacing.xs),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: StegSpacing.xs),
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                alignment: AlignmentDirectional.center,
                padding: const EdgeInsets.symmetric(
                    horizontal: StegSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.16),
                  borderRadius:
                      BorderRadius.circular(StegSpacing.radiusFull),
                ),
                child: Text(
                  '${section.count}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: fg, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tinted pair derived from the group's semantic kind, so the header keeps
  /// the status colour identity (never colour-only: the label is always there)
  /// while staying legible in both themes.
  static (Color, Color) _groupColors(
      BuildContext context, StegStatusKind kind) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = switch (kind) {
      StegStatusKind.success => dark ? StegColors.successDark : StegColors.success,
      StegStatusKind.warning => dark ? StegColors.warningDark : StegColors.warning,
      StegStatusKind.error => Theme.of(context).colorScheme.error,
      StegStatusKind.info =>
        dark ? StegColors.primaryBright : StegColors.brandPrimary,
      StegStatusKind.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    final bg = fg.withValues(alpha: dark ? 0.18 : 0.10);
    return (fg, bg);
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({required this.group});

  final TaskGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: StegSpacing.xs),
      padding: const EdgeInsets.all(StegSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: StegSpacing.xs),
          Expanded(
            child: Text(
              l10n.taskGroupEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rich board card: the shared [TaskRow] (one optimistic toggle implementation)
/// inside a themed surface, so the board and the flat list can never drift.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.now,
    required this.editable,
    required this.onOpen,
  });

  final InternTask task;
  final DateTime now;
  final bool editable;
  final void Function(InternTask task) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = task.isOverdue(now) &&
        (task.status == TaskStatus.todo ||
            task.status == TaskStatus.inProgress);
    final accent = overdue ? theme.colorScheme.error : theme.colorScheme.primary;
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: StegSpacing.sm),
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        side: BorderSide(
          color: overdue
              ? accent.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, StegSpacing.xxs, 0, StegSpacing.xxs),
        child: Stack(
          children: [
            // Status rail: the group's colour identity at a glance, paired
            // with the row's own status chip (never colour-only).
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 4,
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.65),
                ),
              ),
            ),
            TaskRow(
              task: task,
              now: now,
              editable: editable,
              onOpen: () => onOpen(task),
            ),
          ],
        ),
      ),
    );
  }
}
