import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/offline/pending_writes.dart';
import '../../../../core/realtime/realtime_sync.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/work_items.dart';
import '../../domain/schedule.dart';
import '../providers/supervisor_tasks_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import 'bulk_task_sheet.dart';
import 'task_drafts_screen.dart';
import 'task_editor_sheet.dart';

/// T04 supervisor task management (SU-TASK-01/03/04, SU-HOME-01).
///
/// One student's tasks at a time (chosen from the supervisor's own
/// students — the backend enforces the same scope, 404 out of scope):
/// create (FAB), review COMPLETED work (approve / deny with a required
/// reason), edit, delete with confirm, and bulk-add to several students.
/// Scheduled tasks carry a "scheduled" chip throughout (D8); the student's
/// board and the supervisor's review semantics (T02) are untouched.
class SupervisorTasksScreen extends ConsumerStatefulWidget {
  const SupervisorTasksScreen({super.key, this.initialInternshipId});

  final String? initialInternshipId;

  @override
  ConsumerState<SupervisorTasksScreen> createState() =>
      _SupervisorTasksScreenState();
}

class _SupervisorTasksScreenState
    extends ConsumerState<SupervisorTasksScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// T06 §10: resync the supervised lists when the app returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(realtimeSyncProvider).invalidate(RealtimeCategory.tasks);
      _flushQueued();
    }
  }

  /// Best-effort flush; failures stay queued for the next trigger.
  Future<void> _flushQueued() async {
    try {
      await ref.read(pendingWritesProvider.notifier).flushAll();
    } on Exception {
      // Next trigger retries; the queue persists.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final internsAsync = ref.watch(supervisedInternsProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supTasksTitle),
        actions: [
          // T05 entry point: AI draft generation for the selected student.
          _DraftsAction(isOnline: isOnline),
        ],
      ),
      body: internsAsync.when(
        loading: () => const StegLoading(),
        error: (e, _) => StegErrorView(
          message: context.userError(e).message,
          onRetry: () => ref.invalidate(supervisedInternsProvider),
        ),
        data: (interns) {
          if (interns.isEmpty) {
            return StegEmptyView(
              title: l10n.supNoStudents,
              hint: l10n.supNoStudentsHint,
              icon: Icons.school_outlined,
            );
          }
          final watched = ref.watch(selectedSupervisedInternshipProvider);
          String selected = interns.first.internshipId;
          if (watched != null &&
              interns.any((i) => i.internshipId == watched)) {
            selected = watched;
          } else if (widget.initialInternshipId != null &&
              interns.any((i) => i.internshipId == widget.initialInternshipId)) {
            selected = widget.initialInternshipId!;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isOnline)
                const Padding(
                  padding: EdgeInsetsDirectional.only(
                      start: StegSpacing.md,
                      end: StegSpacing.md,
                      top: StegSpacing.sm),
                  child: StaleNotice(),
                ),
              _StudentPicker(
                  interns: interns,
                  selected: selected,
                  onSelect: (id) => ref
                      .read(selectedSupervisedInternshipProvider.notifier)
                      .state = id),
              Expanded(
                child: _SupervisorTaskList(
                    internshipId: selected, isOnline: isOnline),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _SupervisorFab(isOnline: isOnline),
    );
  }
}

/// T05 entry point: opens AI draft generation scoped to the currently
/// selected student (falls back to the first supervised intern).
class _DraftsAction extends ConsumerWidget {
  const _DraftsAction({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.aiDraftTitle,
      icon: const Icon(Icons.auto_awesome_outlined),
      onPressed: !isOnline
          ? null
          : () {
              final interns =
                  ref.read(supervisedInternsProvider).valueOrNull ??
                      const [];
              if (interns.isEmpty) return;
              final watched =
                  ref.read(selectedSupervisedInternshipProvider);
              final id = watched != null &&
                      interns.any((i) => i.internshipId == watched)
                  ? watched
                  : interns.first.internshipId;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      TaskDraftsScreen(referenceInternshipId: id)));
            },
    );
  }
}

class _StudentPicker extends StatelessWidget {
  const _StudentPicker({
    required this.interns,
    required this.selected,
    required this.onSelect,
  });

  final List<SupervisedIntern> interns;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.only(
          start: StegSpacing.md,
          end: StegSpacing.md,
          top: StegSpacing.sm),
      child: Row(
        children: [
          for (final intern in interns) ...[
            ChoiceChip(
              label: Text(intern.internName),
              selected: intern.internshipId == selected,
              onSelected: (_) => onSelect(intern.internshipId),
            ),
            const SizedBox(width: StegSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _SupervisorFab extends ConsumerWidget {
  const _SupervisorFab({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final interns = ref.watch(supervisedInternsProvider).valueOrNull;
    if (interns == null || interns.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(selectedSupervisedInternshipProvider) ??
        interns.first.internshipId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'sup-bulk',
          tooltip: l10n.supBulkTitle,
          onPressed: !isOnline
              ? null
              : () => BulkTaskSheet.show(context),
          icon: const Icon(Icons.group_add_outlined),
          label: Text(l10n.supBulkTitle),
        ),
        const SizedBox(width: StegSpacing.sm),
        FloatingActionButton(
          heroTag: 'sup-add',
          tooltip: l10n.supTaskNew,
          onPressed: !isOnline
              ? null
              : () => TaskEditorSheet.show(context,
                  internshipId: selected, staffMode: true),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _SupervisorTaskList extends ConsumerWidget {
  const _SupervisorTaskList(
      {required this.internshipId, required this.isOnline});

  final String internshipId;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(supervisorTasksProvider);
    final last = ref.watch(lastSupervisorTasksProvider);
    final controller = ref.watch(supervisorTaskControllerProvider);

    if (controller.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text(context.userError(controller.error!).message)));
          ref.read(supervisorTaskControllerProvider.notifier).clearError();
        }
      });
    }

    return async.when(
      loading: () => (last != null && !isOnline)
          ? _Rows(
              tasks: last.items,
              internshipId: internshipId,
              isOnline: isOnline,
              stale: true)
          : const StegLoading(),
      error: (e, _) {
        if (e is StateError && e.message == 'no-internship') {
          return StegEmptyView(
              title: l10n.supNoStudents, hint: l10n.supNoStudentsHint);
        }
        if (last != null && !isOnline) {
          return _Rows(
              tasks: last.items,
              internshipId: internshipId,
              isOnline: isOnline,
              stale: true);
        }
        return StegErrorView(
          message: context.userError(e).message,
          onRetry: () => ref.invalidate(supervisorTasksProvider),
        );
      },
      data: (page) {
        if (page.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(supervisorTasksProvider);
              try {
                await ref.read(supervisorTasksProvider.future);
              } on Exception {
                // Error UI renders from the AsyncValue.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 280,
                  child: StegEmptyView(
                    title: l10n.tasksEmpty,
                    hint: l10n.tasksEmptyHint,
                    icon: Icons.checklist_outlined,
                    actionLabel:
                        isOnline ? l10n.supTaskNew : null,
                    onAction: isOnline
                        ? () => TaskEditorSheet.show(context,
                            internshipId: internshipId,
                            staffMode: true)
                        : null,
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(supervisorTasksProvider);
            try {
              await ref.read(supervisorTasksProvider.future);
            } on Exception {
              // Error UI renders from the AsyncValue.
            }
          },
          child: _Rows(
              tasks: page.items,
              internshipId: internshipId,
              isOnline: isOnline),
        );
      },
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({
    required this.tasks,
    required this.internshipId,
    required this.isOnline,
    this.stale = false,
  });

  final List<InternTask> tasks;
  final String internshipId;
  final bool isOnline;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Needs-review first: the supervisor's primary job is the review queue.
    final ordered = [...tasks]
      ..sort((a, b) {
        int rank(InternTask t) => switch (t.status) {
              TaskStatus.awaitingApproval => 0,
              TaskStatus.denied => 1,
              TaskStatus.todo => 2,
              TaskStatus.inProgress => 3,
              _ => 4,
            };
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.title.compareTo(b.title);
      });
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: StegSpacing.screenPadding,
      itemCount: ordered.length + (stale ? 1 : 0),
      itemBuilder: (context, index) {
        if (stale && index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: StegSpacing.sm),
            child: StaleNotice(),
          );
        }
        final task = ordered[stale ? index - 1 : index];
        return _SupervisorTaskCard(
            task: task,
            now: now,
            internshipId: internshipId,
            isOnline: isOnline);
      },
    );
  }
}

class _SupervisorTaskCard extends ConsumerWidget {
  const _SupervisorTaskCard({
    required this.task,
    required this.now,
    required this.internshipId,
    required this.isOnline,
  });

  final InternTask task;
  final DateTime now;
  final String internshipId;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(supervisorTaskControllerProvider).busy;
    final scheduled = task.isScheduled(now);
    return Semantics(
      label: '${task.title}, ${taskStatusLabel(task.status, l10n)}',
      child: Card(
        margin:
            const EdgeInsetsDirectional.only(bottom: StegSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.all(StegSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text(task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge),
                        if (task.dueDate != null)
                          Text(
                            '${l10n.taskDueLabel} : ${formatDay(task.dueDate!, Localizations.localeOf(context))}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: StegSpacing.xs),
                  StegStatusChip(
                    label: taskStatusLabel(task.status, l10n),
                    kind: taskStatusKind(task.status,
                        overdue: task.isOverdue(now)),
                  ),
                ],
              ),
              const SizedBox(height: StegSpacing.xxs),
              Wrap(
                spacing: StegSpacing.xs,
                runSpacing: StegSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (task.awaitsReview)
                    StegStatusChip(
                        label: l10n.supNeedsReview,
                        kind: StegStatusKind.warning),
                  if (scheduled)
                    StegStatusChip(
                        label:
                            '${l10n.supScheduled} • ${l10n.supAppearsOn(_formatAppears(task.visibleFrom!, Localizations.localeOf(context)))}',
                        kind: StegStatusKind.info),
                  const SizedBox(width: StegSpacing.xs),
                  if (task.awaitsReview) ...[
                    StegButton(
                      label: l10n.supReviewApprove,
                      icon: Icons.check,
                      loading: busy,
                      onPressed: !isOnline || busy
                          ? null
                          : () => _review(context, ref, true),
                    ),
                    StegButton(
                      label: l10n.supReviewDeny,
                      variant: StegButtonVariant.secondary,
                      icon: Icons.close,
                      loading: busy,
                      onPressed: !isOnline || busy
                          ? null
                          : () => _review(context, ref, false),
                    ),
                  ],
                  StegButton(
                    label: l10n.supTaskEdit,
                    variant: StegButtonVariant.text,
                    icon: Icons.edit_outlined,
                    onPressed: !isOnline || busy
                        ? null
                        : () => TaskEditorSheet.show(context,
                            internshipId: internshipId,
                            existing: task,
                            staffMode: true),
                  ),
                  StegButton(
                    label: l10n.supTaskDelete,
                    variant: StegButtonVariant.text,
                    icon: Icons.delete_outline,
                    onPressed: !isOnline || busy
                        ? null
                        : () => _delete(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _review(
      BuildContext context, WidgetRef ref, bool approve) async {
    final l10n = AppLocalizations.of(context);
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          String? error;
          return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              title: Text(l10n.supReviewTitle),
              content: StegTextField(
                controller: controller,
                label: l10n.supDenyReasonLabel,
                hint: l10n.supDenyReasonHint,
                error: error,
                textInputAction: TextInputAction.done,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.cancelAction),
                ),
                StegButton(
                  label: l10n.supReviewDeny,
                  variant: StegButtonVariant.destructive,
                  onPressed: () {
                    if (controller.text.trim().isEmpty) {
                      setState(
                          () => error = l10n.errReviewReason);
                      return;
                    }
                    Navigator.of(ctx).pop(controller.text.trim());
                  },
                ),
              ],
            ),
          );
        },
      );
      if (reason == null || !context.mounted) return;
    }
    final decided =
        await ref.read(supervisorTaskControllerProvider.notifier).reviewTask(
              task.id,
              internshipId,
              approve: approve,
              comment: reason,
            );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(decided == null
              ? context
                  .userError(ref
                      .read(supervisorTaskControllerProvider)
                      .error ??
                      Exception('review-failed'))
                  .message
              : (approve ? l10n.supReviewApproved : l10n.supReviewDenied))));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final interns =
        ref.read(supervisedInternsProvider).valueOrNull ?? const [];
    String student = internshipId;
    for (final i in interns) {
      if (i.internshipId == internshipId) student = i.internName;
    }
    final confirmed = await showStegConfirmDialog(
      context,
      title: l10n.supTaskDeleteTitle,
      message: l10n.supTaskDeleteConfirm(task.title, student),
      confirmLabel: l10n.supTaskDelete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref
        .read(supervisorTaskControllerProvider.notifier)
        .deleteTask(task.id, internshipId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? l10n.supTaskDeleted
              : context
                  .userError(ref
                          .read(supervisorTaskControllerProvider)
                          .error ??
                      Exception('delete-failed'))
                  .message)));
    }
  }
}

String _formatAppears(DateTime instant, Locale locale) {
  final wall = tunisWallFromInstant(instant);
  final tag = locale.toString();
  return '${formatDay(wall, locale)} ${DateFormat.Hm(tag).format(wall)}';
}
