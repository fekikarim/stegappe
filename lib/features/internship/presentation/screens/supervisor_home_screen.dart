import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/calendar.dart';
import '../../domain/entities/evaluation.dart';
import '../providers/notify_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/home_header.dart';
import '../widgets/intern_card.dart';
import 'supervisor_tasks_screen.dart';

/// Supervisor overview (T13): greeting + quick actions, queue totals from
/// the T12 scoped rows (one call feeds the whole home), interns needing
/// attention, then the full list. Formal, concise, actionable.
class SupervisorHomeScreen extends ConsumerWidget {
  const SupervisorHomeScreen({super.key, required this.user, this.onOpenTab});

  final AppUser user;
  final void Function(int tab)? onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(supervisedInternsProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final last = ref.watch(lastSupervisedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        refreshSupervisor(ref);
        try {
          await ref.read(supervisedInternsProvider.future);
        } on Exception {
          // Error UI renders via the AsyncValue.
        }
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: StegSpacing.screenPadding,
            sliver: async.when(
              loading: () => (last != null && !isOnline)
                  ? _HomeBody(
                      interns: last,
                      showStale: true,
                      user: user,
                      onOpenTab: onOpenTab)
                  : const SliverFillRemaining(
                      hasScrollBody: false,
                      child: StegLoading(),
                    ),
              error: (e, _) {
                if (last != null && !isOnline) {
                  return _HomeBody(
                      interns: last,
                      showStale: true,
                      user: user,
                      onOpenTab: onOpenTab);
                }
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: StegErrorView(
                    message: context.userError(e).message,
                    onRetry: () => refreshSupervisor(ref),
                  ),
                );
              },
              data: (interns) {
                if (interns.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: StegEmptyView(
                      title: l10n.noSupervised,
                      hint: l10n.noSupervisedHint,
                      icon: Icons.people_outline,
                    ),
                  );
                }
                return _HomeBody(
                    interns: interns,
                    showStale: !isOnline,
                    user: user,
                    onOpenTab: onOpenTab);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody(
      {required this.interns,
      required this.showStale,
      required this.user,
      this.onOpenTab});

  final List<SupervisedIntern> interns;
  final bool showStale;
  final AppUser user;
  final void Function(int tab)? onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final attention = interns.where((i) => i.needsAttention).toList();
    // Queue tiles read the server counts (T12 rows), not the separate
    // queue providers: one scoped call feeds the whole home.
    final totals = queueTotals(interns);
    final submittedJournal = totals.submittedJournal;
    final submittedDeliverables = totals.submittedDeliverables;
    return SliverMainAxisGroup(
      slivers: [
        if (showStale)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: StegSpacing.sm),
              child: StaleNotice(),
            ),
          ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeHeader(
                displayName: user.email,
                role: user.mobileRole,
              ),
              const SizedBox(height: StegSpacing.md),
              QuickActionsGrid(actions: [
                QuickAction(
                  icon: Icons.checklist_outlined,
                  label: l10n.supManageTasks,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SupervisorTasksScreen()),
                  ),
                ),
                QuickAction(
                  icon: Icons.fact_check_outlined,
                  label: l10n.qaValidations,
                  onTap:
                      onOpenTab == null ? null : () => onOpenTab!(2),
                ),
                QuickAction(
                  icon: Icons.calendar_month_outlined,
                  label: l10n.qaCalendar,
                  onTap: onOpenTab == null
                      ? null
                      : () {
                          ref
                              .read(supervisedViewProvider.notifier)
                              .state = SupervisedView.calendar;
                          onOpenTab!(1);
                        },
                ),
                QuickAction(
                  icon: Icons.people_outline,
                  label: l10n.myInterns,
                  onTap: onOpenTab == null
                      ? null
                      : () {
                          ref
                              .read(supervisedViewProvider.notifier)
                              .state = SupervisedView.list;
                          onOpenTab!(1);
                        },
                ),
                // SU-HOME-02 (T14/D14): "notify for documents preparation".
                // The action opens the scoped Interns list in multi-select
                // mode — the picker *is* the students list, so the target set
                // can never come from anywhere but the server-scoped rows
                // (the endpoint re-checks scope anyway, BR-46/BR-03).
                QuickAction(
                  icon: Icons.campaign_outlined,
                  label: l10n.notifyPrepareAsk,
                  onTap: onOpenTab == null
                      ? null
                      : () {
                          ref
                              .read(supervisedViewProvider.notifier)
                              .state = SupervisedView.list;
                          ref
                              .read(notifySelectModeProvider.notifier)
                              .state = true;
                          onOpenTab!(1);
                        },
                ),
              ]),
              const SizedBox(height: StegSpacing.sm),
              _QueueRow(
                pendingJournal: submittedJournal,
                pendingDeliverables: submittedDeliverables,
                onOpenTab: onOpenTab,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
                top: StegSpacing.md, bottom: StegSpacing.xs),
            child: Text(l10n.needsAttention,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (attention.isEmpty)
          SliverToBoxAdapter(
            child: _Hint(text: l10n.allCaughtUp),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => InternCard(intern: attention[i]),
              childCount: attention.length,
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
                top: StegSpacing.md, bottom: StegSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(l10n.myInterns,
                      style:
                          Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => onOpenTab?.call(1),
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => InternCard(intern: interns[i]),
            childCount: interns.length,
          ),
        ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.pendingJournal,
    required this.pendingDeliverables,
    this.onOpenTab,
  });

  final int pendingJournal;
  final int pendingDeliverables;
  final void Function(int tab)? onOpenTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _QueueCard(
            count: pendingJournal,
            label: l10n.pendingJournalTitle,
            icon: Icons.edit_note_outlined,
            onTap: () => onOpenTab?.call(2),
          ),
        ),
        const SizedBox(width: StegSpacing.sm),
        Expanded(
          child: _QueueCard(
            count: pendingDeliverables,
            label: l10n.deliverablesTitle,
            icon: Icons.upload_file_outlined,
            onTap: () => onOpenTab?.call(2),
          ),
        ),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.count,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final int count;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(StegSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: StegSpacing.xs),
              Text('$count',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
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
      child: Text(text,
          style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
