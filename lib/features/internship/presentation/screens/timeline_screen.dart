import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/dashboard.dart';
import '../../domain/entities/internship.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';

/// Full internship timeline: start/end dates, current phase, and
/// milestones sourced from backend data (assignments, evaluations).
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.timelineTitle)),
      body: async.when(
        loading: () => const StegLoading(),
        error: (e, _) => StegErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) => RefreshIndicator(
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
              _PhaseHeader(data: data),
              const SizedBox(height: StegSpacing.md),
              LabeledProgress(
                label: l10n.timelineProgress,
                fraction: data.timelineFraction,
                counter:
                    '${data.internship.elapsedDays(data.now)}/${data.internship.totalDays}',
              ),
              const SizedBox(height: StegSpacing.lg),
              for (final m
                  in _milestones(context, data)) ...[
                _MilestoneTile(milestone: m),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final internship = data.internship;
    final String phase = internship.status == InternshipStatus.completed ||
            internship.status == InternshipStatus.archived
        ? l10n.phaseFinished
        : data.now.isBefore(internship.startDate)
            ? l10n.phaseNotStarted
            : l10n.phaseInProgress;
    return Semantics(
      header: true,
      label: phase,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(phase, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StegSpacing.xs),
          Wrap(
            spacing: StegSpacing.xs,
            children: [
              StegStatusChip(
                label: internshipStatusLabel(internship.status, l10n),
                kind: internshipStatusKind(internship.status),
              ),
              StegStatusChip(
                label: internshipTypeLabel(internship.type, l10n),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Milestone {
  const _Milestone({
    required this.date,
    required this.title,
    this.subtitle,
    required this.done,
    required this.icon,
  });

  final DateTime date;
  final String title;
  final String? subtitle;
  final bool done;
  final IconData icon;
}

/// Milestones strictly from backend data: period bounds, assignment
/// history, received evaluations. Never synthesized.
List<_Milestone> _milestones(BuildContext context, DashboardData data) {
  final l10n = AppLocalizations.of(context);
  final internship = data.internship;
  final now = data.now;
  final out = <_Milestone>[
    _Milestone(
      date: internship.startDate,
      title: l10n.msStart,
      subtitle:
          '${l10n.startLabel} • ${internship.reference}',
      done: !now.isBefore(internship.startDate),
      icon: Icons.play_circle_outline,
    ),
  ];
  for (final a in data.assignments) {
    final start = a.startDate;
    if (start == null) continue;
    out.add(_Milestone(
      date: start,
      title: '${l10n.departmentLabel}: ${a.departmentName}',
      subtitle: '${l10n.supervisorLabel}: ${a.supervisorName}',
      done: !now.isBefore(start),
      icon: a.isActive
          ? Icons.person_pin_circle_outlined
          : Icons.person_outline,
    ));
  }
  final evals = data.latestEvaluation == null
      ? const <EvaluationSummary>[]
      : [data.latestEvaluation!];
  for (final e in evals) {
    out.add(_Milestone(
      date: e.evaluationDate,
      title: '${l10n.msEvaluation} (${e.type})',
      subtitle: e.totalScore == null
          ? null
          : l10n.scoreLabel(e.totalScore!.toStringAsFixed(2)),
      done: true,
      icon: Icons.star_outline,
    ));
  }
  out.add(_Milestone(
    date: internship.endDate,
    title: l10n.msEnd,
    subtitle: l10n.endLabel,
    done: !now.isBefore(internship.endDate),
    icon: Icons.flag_outlined,
  ));
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone});

  final _Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Semantics(
      label:
          '${milestone.title}, ${formatDay(milestone.date, locale)}',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: milestone.done
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                      : Theme.of(context).disabledColor.withValues(alpha: 0.2),
                  child: Icon(
                    milestone.done ? Icons.check : milestone.icon,
                    size: 16,
                    color: milestone.done
                        ? Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                        : Theme.of(context).disabledColor,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: StegSpacing.sm),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(bottom: StegSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(milestone.title,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (milestone.subtitle != null)
                      Text(milestone.subtitle!,
                          style:
                              Theme.of(context).textTheme.bodySmall),
                    Text(formatDay(milestone.date, locale),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
