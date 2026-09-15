import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/dashboard.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import '../widgets/task_row.dart';
import 'deliverables_screen.dart';
import 'my_evaluations_screen.dart';
import 'timeline_screen.dart';

/// Intern home dashboard — answers:
/// "what should I do?" (today/overdue/week) /
/// "what did I do?" (pending journal, deliverables) /
/// "how am I progressing?" (task + timeline progress, evaluations).
class InternHomeScreen extends ConsumerWidget {
  const InternHomeScreen({super.key, required this.user, this.onOpenTab});

  final AppUser user;
  final void Function(int tab)? onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(dashboardProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final last = ref.watch(lastDashboardProvider);

    return RefreshIndicator(
      onRefresh: () async {
        refreshWorkspace(ref);
        // Wait for the new snapshot (or error) before ending the gesture.
        try {
          await ref.read(dashboardProvider.future);
        } on Exception {
          // Error UI is rendered by the AsyncValue below.
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: StegSpacing.screenPadding,
            sliver: async.when(
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: (last != null && !isOnline)
                    ? _StaleBody(data: last, isOnline: false)
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
                    child: _StaleBody(data: last, isOnline: false),
                  );
                }
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: StegErrorView(
                    message: _messageOf(e),
                    onRetry: () => refreshWorkspace(ref),
                  ),
                );
              },
              data: (data) => _DashboardSliver(
                data: data,
                isOnline: isOnline,
                onOpenTab: onOpenTab,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _messageOf(Object e) =>
      e is ApiException ? e.message : e.toString();
}

class _StaleBody extends StatelessWidget {
  const _StaleBody({required this.data, required this.isOnline});

  final DashboardData data;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StaleNotice(),
        const SizedBox(height: StegSpacing.md),
        _DashboardContent(data: data, isOnline: isOnline),
      ],
    );
  }
}

class _DashboardSliver extends StatelessWidget {
  const _DashboardSliver(
      {required this.data, required this.isOnline, this.onOpenTab});

  final DashboardData data;
  final bool isOnline;
  final void Function(int tab)? onOpenTab;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isOnline) ...[
            const StaleNotice(),
            const SizedBox(height: StegSpacing.md),
          ],
          _DashboardContent(
              data: data, isOnline: isOnline, onOpenTab: onOpenTab),
        ],
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent(
      {required this.data, required this.isOnline, this.onOpenTab});

  final DashboardData data;
  final bool isOnline;
  final void Function(int tab)? onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final internship = data.internship;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Identity header ---
        Semantics(
          header: true,
          label: internship.reference,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                data.internship.candidateFullName?.isNotEmpty == true
                    ? data.internship.candidateFullName!
                    : l10n.dashboard,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: StegSpacing.xs),
              Wrap(
                spacing: StegSpacing.xs,
                runSpacing: StegSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StegStatusChip(
                    label: internshipStatusLabel(
                        internship.status, l10n),
                    kind: internshipStatusKind(internship.status),
                  ),
                  StegStatusChip(
                    label: internshipTypeLabel(internship.type, l10n),
                  ),
                  StegStatusChip(label: internship.reference),
                ],
              ),
              if (data.activeAssignment != null) ...[
                const SizedBox(height: StegSpacing.xs),
                Text(
                  '${l10n.departmentLabel}: ${data.activeAssignment!.departmentName} • '
                  '${l10n.supervisorLabel}: ${data.activeAssignment!.supervisorName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: StegSpacing.md),

        // --- Progress ---
        DashboardSection(
          title: l10n.myProgress,
          actionLabel: l10n.viewTimeline,
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TimelineScreen()),
          ),
          child: Column(
            children: [
              if (data.tasksFraction != null)
                LabeledProgress(
                  label: l10n.tasksProgress,
                  fraction: data.tasksFraction!,
                  counter: '${data.tasksCompleted}/${data.tasksTotal}',
                ),
              if (data.tasksFraction != null)
                const SizedBox(height: StegSpacing.sm),
              LabeledProgress(
                label: l10n.timelineProgress,
                fraction: data.timelineFraction,
                counter:
                    '${formatDay(internship.startDate, locale)} → ${formatDay(internship.endDate, locale)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: StegSpacing.md),

        // --- Today / overdue ---
        DashboardSection(
          title: l10n.todayTitle,
          actionLabel: l10n.viewAll,
          onAction: () => onOpenTab?.call(1),
          child: _TaskPreviewList(
            tasks: [...data.overdueTasks, ...data.todayTasks].take(5).toList(),
            emptyHint: l10n.tasksEmpty,
            now: data.now,
          ),
        ),
        const SizedBox(height: StegSpacing.md),

        if (data.weekTasks.isNotEmpty) ...[
          DashboardSection(
            title: l10n.thisWeek,
            actionLabel: l10n.viewAll,
            onAction: () => onOpenTab?.call(1),
            child: _TaskPreviewList(
              tasks: data.weekTasks.take(4).toList(),
              emptyHint: l10n.tasksEmpty,
              now: data.now,
            ),
          ),
          const SizedBox(height: StegSpacing.md),
        ],

        // --- Pending journal ---
        DashboardSection(
          title:
              '${l10n.pendingJournalTitle} (${data.pendingJournalTotal})',
          actionLabel: l10n.viewAll,
          onAction: () => onOpenTab?.call(2),
          child: data.pendingJournal.isEmpty
              ? _Hint(text: l10n.journalEmpty)
              : Column(
                  children: [
                    for (final j in data.pendingJournal.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_note_outlined),
                        title: Text(j.title.isEmpty ? '—' : j.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatDay(j.entryDate, locale)),
                        trailing: StegStatusChip(
                          label: journalStatusLabel(j.status, l10n),
                          kind: journalStatusKind(j.status),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: StegSpacing.md),

        // --- Deliverables ---
        DashboardSection(
          title: l10n.deliverablesTitle,
          actionLabel: l10n.viewAll,
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const DeliverablesScreen()),
          ),
          child: data.openDeliverables.isEmpty
              ? _Hint(text: l10n.journalEmpty)
              : Column(
                  children: [
                    for (final d in data.openDeliverables)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.upload_file_outlined),
                        title: Text(d.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(l10n.versionLabel(d.currentVersion)),
                        trailing: StegStatusChip(
                          label: deliverableStatusLabel(d.status, l10n),
                          kind: deliverableStatusKind(d.status),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: StegSpacing.md),

        // --- Latest evaluation ---
        if (data.latestEvaluation != null) ...[
          DashboardSection(
            title: l10n.evaluationsTitle,
            actionLabel: l10n.viewAll,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const MyEvaluationsScreen()),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline),
              title: Text(
                  '${data.latestEvaluation!.type} • ${formatDay(data.latestEvaluation!.evaluationDate, locale)}'),
              subtitle: data.latestEvaluation!.totalScore == null
                  ? null
                  : Text(l10n.scoreLabel(
                      data.latestEvaluation!.totalScore!
                          .toStringAsFixed(2))),
            ),
          ),
          const SizedBox(height: StegSpacing.md),
        ],

        // --- Notifications ---
        _NotificationsCard(data: data),
      ],
    );
  }
}

class _TaskPreviewList extends StatelessWidget {
  const _TaskPreviewList(
      {required this.tasks, required this.emptyHint, required this.now});

  final List<InternTask> tasks;
  final String emptyHint;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return _Hint(text: emptyHint);
    return Column(
      children: [for (final t in tasks) TaskRow(task: t, now: now)],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return DashboardSection(
      title: '${l10n.notificationsTitle} (${data.unreadNotifications})',
      action: TextButton(
        onPressed: () async {
          try {
            await ref
                .read(internshipRepositoryProvider)
                .markAllNotificationsRead();
            ref.invalidate(dashboardProvider);
          } on Exception catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          }
        },
        child: Text(l10n.markAllRead),
      ),
      child: data.recentNotifications.isEmpty
          ? _Hint(text: l10n.notificationsEmpty)
          : Column(
              children: [
                for (final n in data.recentNotifications)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      n.isRead
                          ? Icons.notifications_outlined
                          : Icons.notifications_active_outlined,
                    ),
                    title: Text(n.title.isEmpty ? '—' : n.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${formatDay(n.createdAt, locale)} • ${priorityLabel(n.priority, l10n)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
    );
  }
}
