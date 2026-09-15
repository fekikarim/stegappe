import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import '../widgets/task_row.dart';

/// Task list: daily/weekly planned work with due dates, status filter,
/// completion toggle (server-confirmed) and detail sheet.
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(taskListProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final last = ref.watch(lastTasksProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(taskListProvider);
        try {
          await ref.read(taskListProvider.future);
        } on Exception {
          // Error UI renders via the AsyncValue.
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _FilterBar()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                StegSpacing.md, 0, StegSpacing.md, StegSpacing.md),
            sliver: async.when(
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: (last != null && !isOnline)
                    ? _ListBody(
                        page: last, isOnline: false, showStale: true)
                    : const StegLoading(),
              ),
              error: (e, _) {
                if (e is StateError && e.message == 'no-internship') {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: StegEmptyView(
                      title: l10n.noInternshipTitle,
                      hint: l10n.noInternshipHint,
                      icon: Icons.school_outlined,
                    ),
                  );
                }
                if (last != null && !isOnline) {
                  return SliverToBoxAdapter(
                    child: _ListBody(
                        page: last, isOnline: false, showStale: true),
                  );
                }
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: StegErrorView(
                    message:
                        e is ApiException ? e.message : e.toString(),
                    onRetry: () => ref.invalidate(taskListProvider),
                  ),
                );
              },
              data: (page) => SliverToBoxAdapter(
                child: _ListBody(
                    page: page,
                    isOnline: isOnline,
                    showStale: !isOnline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status filter chips. Filtering is enforced by the backend query
/// (`?status=`); "today/overdue" refinements live on the dashboard.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(taskFilterProvider);
    final options = <TaskStatus?>[
      null,
      TaskStatus.todo,
      TaskStatus.inProgress,
      TaskStatus.completed,
    ];
    String label(TaskStatus? s) => switch (s) {
          null => l10n.filterAll,
          TaskStatus.todo => l10n.tsTodo,
          TaskStatus.inProgress => l10n.tsInProgress,
          TaskStatus.completed => l10n.filterDone,
          TaskStatus.cancelled => l10n.tsCancelled,
        };
    return Semantics(
      label: l10n.navTasks,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: StegSpacing.screenPadding,
        child: Row(
          children: [
            for (final o in options) ...[
              ChoiceChip(
                label: Text(label(o)),
                selected: filter == o,
                onSelected: (_) =>
                    ref.read(taskFilterProvider.notifier).state = o,
              ),
              const SizedBox(width: StegSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody(
      {required this.page, required this.isOnline, required this.showStale});

  final Paged<InternTask> page;
  final bool isOnline;
  final bool showStale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showStale) ...[
          const StaleNotice(),
          const SizedBox(height: StegSpacing.sm),
        ],
        if (page.items.isEmpty)
          StegEmptyView(
            title: l10n.tasksEmpty,
            icon: Icons.checklist_outlined,
          )
        else
          for (final t in page.items)
            TaskRow(
              task: t,
              now: now,
              onOpen: () => showTaskDetailSheet(context, t),
            ),
        if (page.totalElements > page.items.length) ...[
          const SizedBox(height: StegSpacing.sm),
          Center(
            child: Text(
              l10n.moreItems(page.totalElements - page.items.length),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

/// Detail sheet: full description, due date, status transitions
/// (server-confirmed, errors surfaced inline via snackbar).
Future<void> showTaskDetailSheet(BuildContext context, InternTask task) {
  return showStegSheet(
    context,
    title: task.title,
    builder: (ctx) => _TaskDetailBody(task: task),
  );
}

class _TaskDetailBody extends ConsumerWidget {
  const _TaskDetailBody({required this.task});

  final InternTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final now = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: StegSpacing.xs,
          children: [
            StegStatusChip(
              label: taskStatusLabel(task.status, l10n),
              kind: taskStatusKind(task.status,
                  overdue: task.isOverdue(now)),
            ),
            StegStatusChip(
              label: task.dueDate == null
                  ? l10n.noDueDate
                  : formatDay(task.dueDate!, locale),
            ),
          ],
        ),
        if (task.description?.isNotEmpty == true) ...[
          const SizedBox(height: StegSpacing.sm),
          Text(task.description!),
        ],
        const SizedBox(height: StegSpacing.md),
        if (task.status != TaskStatus.completed)
          StegButton(
            label: l10n.taskMarkComplete,
            icon: Icons.check_outlined,
            onPressed: () =>
                _setStatus(context, ref, TaskStatus.completed),
          ),
        if (task.status == TaskStatus.todo) ...[
          const SizedBox(height: StegSpacing.xs),
          StegButton(
            label: l10n.taskSetInProgress,
            variant: StegButtonVariant.secondary,
            icon: Icons.play_arrow_outlined,
            onPressed: () =>
                _setStatus(context, ref, TaskStatus.inProgress),
          ),
        ],
        if (task.status == TaskStatus.completed) ...[
          StegButton(
            label: l10n.taskReopen,
            variant: StegButtonVariant.secondary,
            icon: Icons.replay_outlined,
            onPressed: () => _setStatus(context, ref, TaskStatus.todo),
          ),
        ],
      ],
    );
  }

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, TaskStatus status) async {
    try {
      await ref
          .read(internshipRepositoryProvider)
          .updateTaskStatus(task.id, status);
      ref
        ..invalidate(taskListProvider)
        ..invalidate(dashboardProvider);
      if (context.mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e is ApiException ? e.message : e.toString()),
          ),
        );
      }
    }
  }
}
