import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/work_items.dart';
import '../../domain/task_board.dart';
import 'status_labels.dart';
import 'task_row.dart';

/// The status board (ST-TASK-01/06): one column per board group.
///
/// Responsive by width: on a tablet/desktop width the groups are columns side
/// by side that scroll horizontally; on a phone they become swipeable pages
/// with a tappable, counted indicator. Empty groups always render (and say so)
/// so a student never mistakes an empty column for missing data.
///
/// The layout is deliberately free of business rules: it renders [sections]
/// produced by `buildTaskBoard` and forwards the single action it owns (open a
/// task). Progress changes stay in [TaskRow], which keeps the optimistic
/// toggle and its rollback in exactly one place.
class TaskBoardView extends StatefulWidget {
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

  /// Below this width the board pages instead of showing columns.
  static const double columnsBreakpoint = 700;
  static const double columnWidth = 300;

  @override
  State<TaskBoardView> createState() => _TaskBoardViewState();
}

class _TaskBoardViewState extends State<TaskBoardView> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= TaskBoardView.columnsBreakpoint;
        return columns ? _columns(context) : _paged(context);
      },
    );
  }

  Widget _columns(BuildContext context) {
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
            for (final section in widget.sections)
              SizedBox(
                width: TaskBoardView.columnWidth,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                      end: StegSpacing.sm),
                  child: _TaskGroupColumn(
                    section: section,
                    now: widget.now,
                    editable: widget.editable,
                    onOpen: widget.onOpen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _paged(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = widget.sections.length;
    return Column(
      children: [
        SizedBox(
          height: StegSpacing.minTouchTarget,
          child: Semantics(
            label: l10n.navTasks,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.only(
                  start: StegSpacing.md, end: StegSpacing.md),
              children: [
                for (var i = 0; i < count; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        end: StegSpacing.xs),
                    child: FilterChip(
                      label: Text('${taskGroupLabel(widget.sections[i].group, l10n)}'
                          ' (${widget.sections[i].count})'),
                      selected: _page == i,
                      onSelected: (_) {
                        if (i >= widget.sections.length) return;
                        _pages.animateToPage(i,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            scrollDirection: Axis.horizontal,
            physics: const ScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final section in widget.sections)
                ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: StegSpacing.screenPadding,
                  children: [
                    _GroupHeader(section: section),
                    if (section.isEmpty)
                      _EmptyGroup(group: section.group)
                    else
                      for (final task in section.tasks)
                        _TaskCard(
                          task: task,
                          now: widget.now,
                          editable: widget.editable,
                          onOpen: widget.onOpen,
                        ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(
          top: StegSpacing.xs, bottom: StegSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: StegStatusChip(
              label: label,
              kind: taskGroupKind(section.group),
            ),
          ),
          const SizedBox(width: StegSpacing.xxs),
          Semantics(
            label: '$label: ${section.count}',
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(
                  minWidth: StegSpacing.xl, minHeight: StegSpacing.lg),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                  horizontal: StegSpacing.xs, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(StegSpacing.radiusFull),
              ),
              child: Text(
                '${section.count}',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({required this.group});

  final TaskGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: StegSpacing.xs),
      padding: const EdgeInsets.all(StegSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: StegSpacing.xxs),
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
    return Card(
      margin: const EdgeInsetsDirectional.only(bottom: StegSpacing.xs),
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.xs, vertical: StegSpacing.xxs),
        child: TaskRow(
          task: task,
          now: now,
          editable: editable,
          onOpen: () => onOpen(task),
        ),
      ),
    );
  }
}
