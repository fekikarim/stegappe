import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/offline/pending_writes.dart';
import '../../../../core/realtime/realtime_sync.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/work_items.dart';
import '../../domain/task_board.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/classification_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/category_chip.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import '../widgets/task_board_view.dart';
import '../widgets/task_row.dart';
import 'classification_sheet.dart';
import 'classification_suggest_sheet.dart';
import 'journal_generation_sheet.dart';
import 'task_editor_sheet.dart';

/// Student task board (ST-TASK-01/02/06/07):
/// **To do / In progress / Needs attention / Done** with per-group counts, a
/// client-side search, the existing server status filter, and the flat list as
/// a second view.
///
/// The two states the app used to hide are first-class here: a completion the
/// supervisor has not reviewed yet reads *awaiting approval* (never "done",
/// BR-11/D6) and a denial shows the supervisor's reason inline (BR-12).
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen>
    with WidgetsBindingObserver {
  final TextEditingController _search = TextEditingController();

  /// Board is the default surface; the flat list stays one tap away.
  bool _boardView = true;

  @override
  void initState() {
    super.initState();
    // Sockets die in background; resync the authoritative lists on resume
    // (plus the socket's own reconnect → resyncRequested path, T06 §10).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  /// Sockets die in background; resync the authoritative lists on resume
  /// (plus the socket's own reconnect → resyncRequested path, T06 §10).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(realtimeSyncProvider).invalidate(RealtimeCategory.tasks);
      _flushQueued();
    }
  }

  /// Best-effort flush; failures stay queued for the next trigger and the
  /// lists already invalidated above reconcile on read.
  Future<void> _flushQueued() async {
    try {
      await ref.read(pendingWritesProvider.notifier).flushAll();
    } on Exception {
      // Next trigger retries; the queue persists.
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(taskListProvider)
      ..invalidate(dashboardProvider)
      ..invalidate(classificationBoardProvider);
    try {
      await ref.read(taskListProvider.future);
    } on Exception {
      // Error UI renders from the AsyncValue.
    }
    try {
      await ref.read(classificationBoardProvider.future);
    } on Exception {
      // Classification errors render from their own AsyncValue.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(taskListProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final last = ref.watch(lastTasksProvider);
    final auth = ref.watch(authControllerProvider);
    final signedIn = auth is AuthAuthenticated;
    // Status progress is a participant action: interns only (the backend
    // enforces the same rule — this is UX, never the security boundary).
    final canProgress = signedIn && auth.user.mobileRole == UserRole.intern;
    final userId = signedIn ? auth.user.id : null;
    final internshipId = ref.watch(myInternshipIdProvider).valueOrNull;
    final filter = ref.watch(taskFilterProvider);
    final query = ref.watch(taskSearchProvider);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                  start: StegSpacing.md,
                  end: StegSpacing.md,
                  top: StegSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: StegTextField(
                      controller: _search,
                      label: l10n.taskSearchHint,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) => ref
                          .read(taskSearchProvider.notifier)
                          .state = value,
                      suffix: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.taskSearchClear,
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                ref
                                    .read(taskSearchProvider.notifier)
                                    .state = '';
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: StegSpacing.xs),
                  IconButton(
                    tooltip:
                        _boardView ? l10n.taskViewList : l10n.taskViewBoard,
                    onPressed: () =>
                        setState(() => _boardView = !_boardView),
                    icon: Icon(_boardView
                        ? Icons.view_list_outlined
                        : Icons.view_column_outlined),
                  ),
                  IconButton(
                    tooltip: l10n.retry,
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const _FilterBar(),
            if (canProgress) const _ClassificationBar(),
            if (canProgress && internshipId != null)
              JournalGenerationBar(internshipId: internshipId),
            const SizedBox(height: StegSpacing.xs),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: async.when(
                  loading: () => (last != null && !isOnline)
                      ? _OfflineBody(
                          page: last,
                          filter: filter,
                          query: query,
                          boardView: _boardView,
                          canProgress: canProgress,
                          userId: userId,
                        )
                      : const StegLoading(),
                  error: (e, _) {
                    if (e is StateError && e.message == 'no-internship') {
                      return _NoInternship();
                    }
                    if (last != null && !isOnline) {
                      return _OfflineBody(
                        page: last,
                        filter: filter,
                        query: query,
                        boardView: _boardView,
                        canProgress: canProgress,
                        userId: userId,
                      );
                    }
                    return StegErrorView(
                      message: context.userError(e).message,
                      onRetry: () => ref.invalidate(taskListProvider),
                    );
                  },
                  data: (page) {
                    final displayPage = (page.items.isEmpty && last != null && !isOnline)
                        ? last
                        : page;
                    return _TaskBody(
                      page: displayPage,
                      filter: filter,
                      query: query,
                      boardView: _boardView,
                      canProgress: canProgress,
                      userId: userId,
                      showStale: !isOnline,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        if (canProgress && internshipId != null)
          PositionedDirectional(
            end: StegSpacing.md,
            bottom: StegSpacing.md,
            child: Semantics(
              button: true,
              label: l10n.taskNew,
              child: FloatingActionButton(
                tooltip: l10n.taskNew,
                onPressed: () => TaskEditorSheet.show(context,
                    internshipId: internshipId),
                child: const Icon(Icons.add),
              ),
            ),
          ),
      ],
    );
  }
}

/// Server-side status filter (`?status=`) plus "all" for the board. Every chip
/// is wrapped so the query the backend receives is the one asserted in tests.
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
      TaskStatus.awaitingApproval,
      TaskStatus.approved,
      TaskStatus.denied,
      TaskStatus.cancelled,
    ];
    String label(TaskStatus? s) => switch (s) {
          null => l10n.filterAll,
          TaskStatus.todo => l10n.tsTodo,
          TaskStatus.inProgress => l10n.tsInProgress,
          TaskStatus.awaitingApproval => l10n.tsAwaitingApproval,
          TaskStatus.approved => l10n.filterDone,
          TaskStatus.denied => l10n.tsDenied,
          TaskStatus.cancelled => l10n.tsCancelled,
          TaskStatus.unknown => l10n.tsUnknown,
        };
    return Semantics(
      label: l10n.navTasks,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(
            start: StegSpacing.md, end: StegSpacing.md),
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

/// T03 classification dimension (ST-TASK-03/04/05): a secondary filter row
/// — All / Unclassified / one chip per category — plus the Organize and AI
/// actions. Intern-only (categories are private to the student, BR-08).
/// Renders nothing until the board loads; errors never block the status
/// board itself.
class _ClassificationBar extends ConsumerWidget {
  const _ClassificationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final board = ref.watch(classificationBoardProvider);
    final filter = ref.watch(classificationFilterProvider);

    return board.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.categories.isEmpty) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(
                start: StegSpacing.md, end: StegSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.catEmptyHint,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                TextButton.icon(
                  onPressed: () => ClassificationSheet.show(context),
                  icon: const Icon(Icons.folder_outlined),
                  label: Text(l10n.catOrganize),
                ),
              ],
            ),
          );
        }
        return Semantics(
          label: l10n.catTitle,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(
                start: StegSpacing.md, end: StegSpacing.md),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.filterAll),
                  selected: filter.isAll,
                  onSelected: (_) => ref
                      .read(classificationFilterProvider.notifier)
                      .state = const ClassificationFilter.all(),
                ),
                const SizedBox(width: StegSpacing.xs),
                ChoiceChip(
                  avatar: const Icon(Icons.folder_open_outlined, size: 18),
                  label: Text(l10n.catUnclassified),
                  selected: filter.isUnclassified,
                  onSelected: (_) => ref
                      .read(classificationFilterProvider.notifier)
                      .state = const ClassificationFilter.unclassified(),
                ),
                for (final category in data.categories) ...[
                  const SizedBox(width: StegSpacing.xs),
                  ChoiceChip(
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: categoryColor(
                            category.colorToken, Theme.of(context)),
                      ),
                    ),
                    label: Text(category.name),
                    selected: filter == ClassificationFilter.category(category.id),
                    onSelected: (_) => ref
                        .read(classificationFilterProvider.notifier)
                        .state =
                        ClassificationFilter.category(category.id),
                  ),
                ],
                const SizedBox(width: StegSpacing.xs),
                IconButton(
                  tooltip: l10n.catOrganize,
                  icon: const Icon(Icons.folder_outlined),
                  onPressed: () => ClassificationSheet.show(context),
                ),
                IconButton(
                  tooltip: l10n.catSuggest,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  onPressed: () => SuggestSheet.show(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Data body for the online path: board or flat list, search applied.
class _TaskBody extends StatelessWidget {
  const _TaskBody({
    required this.page,
    required this.filter,
    required this.query,
    required this.boardView,
    required this.canProgress,
    required this.userId,
    this.showStale = false,
  });

  final Paged<InternTask> page;
  final TaskStatus? filter;
  final String query;
  final bool boardView;
  final bool canProgress;
  final String? userId;
  final bool showStale;

  @override
  Widget build(BuildContext context) {
    return _TaskSurface(
      page: page,
      filter: filter,
      query: query,
      boardView: boardView,
      canProgress: canProgress,
      userId: userId,
      showStale: showStale,
    );
  }
}

/// Offline path: the last good page stays visible with an honest indicator.
class _OfflineBody extends StatelessWidget {
  const _OfflineBody({
    required this.page,
    required this.filter,
    required this.query,
    required this.boardView,
    required this.canProgress,
    required this.userId,
  });

  final Paged<InternTask> page;
  final TaskStatus? filter;
  final String query;
  final bool boardView;
  final bool canProgress;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return _TaskSurface(
      page: page,
      filter: filter,
      query: query,
      boardView: boardView,
      canProgress: canProgress,
      userId: userId,
      showStale: true,
    );
  }
}

class _TaskSurface extends ConsumerWidget {
  const _TaskSurface({
    required this.page,
    required this.filter,
    required this.query,
    required this.boardView,
    required this.canProgress,
    required this.userId,
    required this.showStale,
  });

  final Paged<InternTask> page;
  final TaskStatus? filter;
  final String query;
  final bool boardView;
  final bool canProgress;
  final String? userId;
  final bool showStale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final searchActive = query.trim().isNotEmpty;
    // T03: the classification filter is client-side over the loaded board
    // (secondary to the server status filter, exactly like search).
    final classification = ref.watch(classificationFilterProvider);
    final board = ref.watch(classificationBoardProvider).valueOrNull ??
        ref.watch(lastClassificationProvider);
    final visible = [
      for (final t in page.items)
        if (classification.matches(board?.categoryOf(t.id))) t,
    ];
    final classificationActive = !classification.isAll;

    if (page.items.isEmpty) {
      // Nothing at all (no filter, no search): the encouraging empty state.
      if (filter == null && !searchActive) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (showStale)
              const Padding(
                padding: EdgeInsetsDirectional.only(bottom: StegSpacing.sm),
                child: StaleNotice(),
              ),
            SizedBox(
              height: 320,
              child: StegEmptyView(
                title: l10n.tasksEmpty,
                hint: l10n.tasksEmptyHint,
                icon: Icons.checklist_outlined,
              ),
            ),
          ],
        );
      }
    }

    final sections = buildTaskBoard(
      visible,
      query: query,
      // A cancelled task only reaches the board when the student explicitly
      // filtered for it; the board hides it by default (T02 edge cases).
      includeCancelled: filter == TaskStatus.cancelled,
    );
    final matching = [
      for (final t in visible)
        if (taskMatchesQuery(t, query)) t,
    ];

    if ((searchActive || classificationActive) && matching.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 280,
            child: StegEmptyView(
              title: l10n.taskNoMatch,
              icon: Icons.search_off_outlined,
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (showStale)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsDirectional.only(bottom: StegSpacing.sm),
              child: StaleNotice(),
            ),
          ),
        if (boardView)
          SliverToBoxAdapter(
            child: TaskBoardView(
              sections: sections,
              now: now,
              editable: canProgress,
              onOpen: (task) => showTaskDetailSheet(
                context,
                task,
                canProgress: canProgress,
                canEdit: studentOwnsTask(task, userId),
              ),
            ),
          )
        else
          _FlatSliver(
            tasks: matching,
            now: now,
            canProgress: canProgress,
            userId: userId,
          ),
        if (page.totalElements > page.items.length)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(StegSpacing.sm),
              child: Center(
                child: Text(
                  l10n.moreItems(page.totalElements - page.items.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FlatSliver extends StatelessWidget {
  const _FlatSliver({
    required this.tasks,
    required this.now,
    required this.canProgress,
    required this.userId,
  });

  final List<InternTask> tasks;
  final DateTime now;
  final bool canProgress;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: StegSpacing.screenPadding,
      sliver: SliverList.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return TaskRow(
            key: ValueKey(task.id),
            task: task,
            now: now,
            editable: canProgress,
            onOpen: () => showTaskDetailSheet(
              context,
              task,
              canProgress: canProgress,
              canEdit: studentOwnsTask(task, userId),
            ),
          );
        },
      ),
    );
  }
}

class _NoInternship extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 320,
          child: StegEmptyView(
            title: l10n.noInternshipTitle,
            hint: l10n.noInternshipHint,
            icon: Icons.school_outlined,
          ),
        ),
      ],
    );
  }
}

/// Detail sheet: the full truth about a task — description, due date, the
/// supervisor's denial reason with its date, the pending-review notice — plus
/// the student's own transitions, server-confirmed and guarded in flight.
/// Approval is never offered here: it belongs to the supervisor (D6/BR-11).
Future<void> showTaskDetailSheet(
  BuildContext context,
  InternTask task, {
  bool canProgress = true,
  bool canEdit = true,
}) {
  return showStegSheet(
    context,
    title: task.title,
    builder: (ctx) => _TaskDetailBody(
        task: task, canProgress: canProgress, canEdit: canEdit),
  );
}

class _TaskDetailBody extends ConsumerStatefulWidget {
  const _TaskDetailBody({
    required this.task,
    required this.canProgress,
    required this.canEdit,
  });

  final InternTask task;
  final bool canProgress;
  final bool canEdit;

  @override
  ConsumerState<_TaskDetailBody> createState() => _TaskDetailBodyState();
}

class _TaskDetailBodyState extends ConsumerState<_TaskDetailBody> {
  bool _busy = false;

  Future<void> _setStatus(TaskStatus status) async {
    // The sheet only ever offers the student's own transitions; the guard is
    // the last line of defence against a fabricated approval (BR-11).
    if (_busy ||
        !widget.canProgress ||
        !widget.task.studentTransitions.contains(status)) {
      return;
    }
    // T06/D12 offline path: queue visibly instead of failing (same rule as
    // the board toggle; the flush applies it exactly once).
    if (!ref.read(isOnlineProvider)) {
      final ok = await ref
          .read(pendingWritesProvider.notifier)
          .enqueueStatus(taskId: widget.task.id, status: status);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(ok ? l10n.offlineQueued : l10n.queueFull),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(internshipRepositoryProvider)
          .updateTaskStatus(widget.task.id, status);
      ref
        ..invalidate(taskListProvider)
        ..invalidate(dashboardProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(taskStatusLabel(status,
                AppLocalizations.of(context))),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        if (e.kind == ApiErrorKind.network) {
          final ok = await ref
              .read(pendingWritesProvider.notifier)
              .enqueueStatus(
                  taskId: widget.task.id, status: status);
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  ok ? l10n.offlineQueued : l10n.queueFull),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.userError(e).message)),
          );
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.userError(e).message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final task = widget.task;
    final now = DateTime.now();
    final transitions = widget.canProgress
        ? task.studentTransitions
        : const <TaskStatus>[];
    // T03: personal classification, independent of the workflow status.
    final board = ref.watch(classificationBoardProvider).valueOrNull ??
        ref.watch(lastClassificationProvider);
    final category = board?.categoryById(board.categoryOf(task.id));

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: StegSpacing.xs,
            runSpacing: StegSpacing.xxs,
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
              if (category != null) CategoryChip(category: category),
            ],
          ),
          if (widget.canProgress && board != null) ...[
            const SizedBox(height: StegSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {
                  final current = board.categoryOf(task.id);
                  showCategoryPicker(
                    context,
                    ref,
                    taskId: task.id,
                    currentCategoryId: current,
                    categories: board.categories,
                  );
                },
                icon: const Icon(Icons.folder_outlined),
                label: Text(category == null
                    ? l10n.catOrganize
                    : '${l10n.catOrganize} • ${category.name}'),
              ),
            ),
          ],
          if (task.status == TaskStatus.awaitingApproval) ...[
            const SizedBox(height: StegSpacing.sm),
            _DetailNotice(
              icon: Icons.hourglass_top_outlined,
              text: l10n.taskWaitingReview,
              kind: StegStatusKind.warning,
            ),
          ],
          if (task.status == TaskStatus.denied) ...[
            const SizedBox(height: StegSpacing.sm),
            _DetailNotice(
              icon: Icons.report_outlined,
              label: l10n.taskDenialReason,
              text: task.denialReason ?? l10n.taskDeniedNoReason,
              caption: task.reviewedAt == null
                  ? null
                  : l10n
                      .taskReviewedOn(formatDay(task.reviewedAt!, locale)),
              kind: StegStatusKind.error,
            ),
          ],
          if (task.status == TaskStatus.approved &&
              task.reviewedAt != null) ...[
            const SizedBox(height: StegSpacing.sm),
            _DetailNotice(
              icon: Icons.verified_outlined,
              text: l10n.taskReviewedOn(
                  formatDay(task.reviewedAt!, locale)),
              kind: StegStatusKind.success,
            ),
          ],
          if (task.description?.isNotEmpty == true) ...[
            const SizedBox(height: StegSpacing.sm),
            Text(task.description!),
          ],
          const SizedBox(height: StegSpacing.md),
          for (final target in transitions) ...[
            StegButton(
              label: taskTransitionLabel(task.status, target, l10n),
              icon: target == TaskStatus.awaitingApproval
                  ? Icons.outbox_outlined
                  : Icons.play_arrow_outlined,
              loading: _busy,
              onPressed: _busy ? null : () => _setStatus(target),
            ),
            const SizedBox(height: StegSpacing.xs),
          ],
          if (transitions.isEmpty && !widget.canProgress) ...[
            Text(
              l10n.taskNoEditSupervisorTask,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: StegSpacing.xs),
          ],
          if (widget.canEdit)
            StegButton(
              label: l10n.taskEdit,
              variant: StegButtonVariant.text,
              icon: Icons.edit_outlined,
              onPressed: _busy
                  ? null
                  : () async {
                      final id =
                          ref.read(myInternshipIdProvider).valueOrNull;
                      if (id == null || !context.mounted) return;
                      Navigator.of(context).pop();
                      await TaskEditorSheet.show(context,
                          internshipId: id, existing: task);
                    },
            )
          else
            // BR-14: supervisor-authored tasks are read-only for the student,
            // with the reason on the control itself (acceptance 5).
            Tooltip(
              message: l10n.taskNoEditSupervisorTask,
              child: StegButton(
                label: l10n.taskEdit,
                variant: StegButtonVariant.text,
                icon: Icons.lock_outline,
                onPressed: null,
                semanticsLabel: l10n.taskNoEditSupervisorTask,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailNotice extends StatelessWidget {
  const _DetailNotice({
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
      StegStatusKind.success => theme.colorScheme.primary,
      _ => theme.colorScheme.tertiary,
    };
    return Container(
      padding: const EdgeInsets.all(StegSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(StegSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: StegSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label == null ? text : '$label : $text',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
