import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/dashboard.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import 'logbook_screen.dart';
import 'assistant_screen.dart';
import 'timeline_screen.dart';

/// Combined progress overview: tasks, journal validation, deliverables,
/// evaluations and timeline — every figure traceable to backend data.
/// Also hosts the advisory logbook entry point (optional AI).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
      body: async.when(
        loading: () => const StegLoading(),
        error: (e, _) => StegErrorView(
          message: e is ApiException ? e.message : e.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            refreshWorkspace(ref);
            try {
              await ref.read(dashboardProvider.future);
            } on Exception {
              // Error UI renders via the AsyncValue.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: StegSpacing.screenPadding,
            children: [
              _ProgressRow(data: d),
              const SizedBox(height: StegSpacing.md),
              DashboardSection(
                title: l10n.timelineTitle,
                actionLabel: l10n.viewTimeline,
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const TimelineScreen()),
                ),
                child: LabeledProgress(
                  label: l10n.timelineProgress,
                  fraction: d.timelineFraction,
                  counter:
                      '${d.internship.elapsedDays(d.now)}/${d.internship.totalDays}',
                ),
              ),
              const SizedBox(height: StegSpacing.md),
              _AiEntryCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.tasksFraction != null)
          LabeledProgress(
            label: l10n.progressTasks,
            fraction: data.tasksFraction!,
            counter: l10n.progressOf(
                data.tasksCompleted, data.tasksTotal),
          ),
        const SizedBox(height: StegSpacing.sm),
        LabeledProgress(
          label: l10n.progressJournal,
          fraction: _journalFraction(data),
          counter: l10n.progressOf(data.journalValidatedTotal,
              data.journalValidatedTotal + data.pendingJournalTotal),
        ),
        Text(
          l10n.progressJournalPending(data.pendingJournalTotal),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: StegSpacing.sm),
        if (data.deliverablesComplete)
          LabeledProgress(
            label: l10n.progressDeliverables,
            fraction: data.deliverablesTotal == 0
                ? 0
                : data.deliverablesValidated /
                    data.deliverablesTotal,
            counter: l10n.progressOf(data.deliverablesValidated,
                data.deliverablesTotal),
          )
        else
          // Windowed fetch: show the exact total without inventing a
          // validated share for unseen items.
          Row(
            children: [
              Expanded(
                child: Text(l10n.progressDeliverables,
                    style:
                        Theme.of(context).textTheme.bodyMedium),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                    l10n.progressOf(data.deliverablesValidated,
                        data.deliverablesTotal),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        const SizedBox(height: StegSpacing.sm),
        LabeledProgress(
          label: l10n.progressEvaluations,
          fraction: data.evaluationsCount > 0 ? 1 : 0,
          counter: l10n
              .progressEvaluationsCount(data.evaluationsCount),
        ),
      ],
    );
  }

  double _journalFraction(DashboardData data) {
    final total =
        data.journalValidatedTotal + data.pendingJournalTotal;
    if (total == 0) return 0;
    return data.journalValidatedTotal / total;
  }
}

/// Advisory-AI entry: clearly labeled, optional, never blocking.
class _AiEntryCard extends StatelessWidget {
  const _AiEntryCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: StegSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: StegSpacing.xs),
                Expanded(
                  child: Text(l10n.aiBadge,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium),
                ),
                StegStatusChip(label: l10n.logbookTitle),
              ],
            ),
            const SizedBox(height: StegSpacing.xs),
            Text(l10n.logbookExplain,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: StegSpacing.xs),
            Text(l10n.aiAdvisoryNote,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: StegSpacing.sm),
            Semantics(
              button: true,
              label: l10n.logbookTitle,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.book_outlined),
                label: Text(l10n.logbookTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const LogbookScreen()),
                ),
              ),
            ),
            const SizedBox(height: StegSpacing.xs),
            Semantics(
              button: true,
              label: l10n.assistantTitle,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.smart_toy_outlined),
                label: Text(l10n.assistantTitle),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AssistantScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
