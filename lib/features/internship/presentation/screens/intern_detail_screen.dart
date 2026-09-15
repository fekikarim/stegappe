import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import '../widgets/task_row.dart';
import 'deliverable_detail_screen.dart';
import 'evaluation_detail_screen.dart';
import 'evaluation_form_screen.dart';
import 'journal_detail_sheet.dart';

/// Supervisor's intern file: timeline, planned tasks, journals awaiting
/// validation, deliverables, evaluations + recent feedback — each kind
/// kept visually distinct (planned work ≠ recorded work ≠ assessment).
class InternDetailScreen extends ConsumerWidget {
  const InternDetailScreen({super.key, required this.internshipId});

  final String internshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async =
        ref.watch(supervisedInternDetailProvider(internshipId));
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.internDetailTitle)),
      body: async.when(
        loading: () => const StegLoading(),
        error: (e, _) => StegErrorView(
          message: e is ApiException ? e.message : e.toString(),
          onRetry: () => refreshSupervisor(ref, internshipId),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            refreshSupervisor(ref, internshipId);
            try {
              await ref.read(supervisedInternDetailProvider(
                  internshipId).future);
            } on Exception {
              // Error UI renders via the AsyncValue.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: StegSpacing.screenPadding,
            children: [
              // --- Header ---
              Semantics(
                header: true,
                label: d.internship.reference,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      d.internship.candidateFullName?.isNotEmpty ==
                              true
                          ? d.internship.candidateFullName!
                          : d.internship.reference,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall,
                    ),
                    const SizedBox(height: StegSpacing.xs),
                    Wrap(
                      spacing: StegSpacing.xs,
                      runSpacing: StegSpacing.xs,
                      children: [
                        StegStatusChip(
                          label: internshipStatusLabel(
                              d.internship.status, l10n),
                          kind: internshipStatusKind(
                              d.internship.status),
                        ),
                        StegStatusChip(
                          label: internshipTypeLabel(
                              d.internship.type, l10n),
                        ),
                        StegStatusChip(
                            label: d.internship.reference),
                      ],
                    ),
                    if (d.activeAssignment != null) ...[
                      const SizedBox(height: StegSpacing.xs),
                      Text(
                        '${l10n.departmentLabel}: ${d.activeAssignment!.departmentName} • '
                        '${formatDay(d.internship.startDate, locale)} → '
                        '${formatDay(d.internship.endDate, locale)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: StegSpacing.md),
              LabeledProgress(
                label: l10n.tasksProgress,
                fraction: d.tasksTotal == 0
                    ? 0
                    : d.tasksCompletedTotal / d.tasksTotal,
                counter:
                    '${d.tasksCompletedTotal}/${d.tasksTotal}',
              ),
              const SizedBox(height: StegSpacing.md),

              // --- Planned tasks (read-only for supervisor in D4) ---
              DashboardSection(
                title:
                    '${l10n.evalTasksSection} (${d.tasksTotal})',
                child: d.tasks.isEmpty
                    ? Text(l10n.tasksEmpty,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium)
                    : Column(
                        children: [
                          for (final t in d.tasks.take(6))
                            TaskRow(
                                task: t,
                                now: now,
                                editable: false),
                          if (d.tasksTotal > d.tasks.length)
                            Text(
                              l10n.moreItems(d.tasksTotal -
                                  d.tasks.length),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: StegSpacing.md),

              // --- Journals awaiting validation ---
              DashboardSection(
                title:
                    '${l10n.evalPendingJournal} (${d.pendingJournal.length})',
                child: d.pendingJournal.isEmpty
                    ? Text(l10n.allCaughtUp,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium)
                    : Column(
                        children: [
                          for (final j in d.pendingJournal)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons
                                  .pending_actions_outlined),
                              title: Text(
                                  j.title.isEmpty
                                      ? '—'
                                      : j.title,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis),
                              subtitle: Text(formatDay(
                                  j.entryDate, locale)),
                              trailing: StegStatusChip(
                                label: journalStatusLabel(
                                    j.status, l10n),
                                kind: journalStatusKind(
                                    j.status),
                              ),
                              onTap: () =>
                                  showJournalDetailSheet(
                                      context, j),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: StegSpacing.md),

              // --- Deliverables ---
              DashboardSection(
                title: l10n.evalDeliverablesSection,
                child: d.deliverables.isEmpty
                    ? Text(l10n.deliverableChecklistEmpty,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium)
                    : Column(
                        children: [
                          for (final dliv in d.deliverables)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons
                                  .upload_file_outlined),
                              title: Text(dliv.title,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis),
                              subtitle: Text(l10n.versionLabel(
                                  dliv.currentVersion)),
                              trailing: StegStatusChip(
                                label:
                                    deliverableStatusLabel(
                                        dliv.status,
                                        l10n),
                                kind:
                                    deliverableStatusKind(
                                        dliv.status),
                              ),
                              onTap: () =>
                                  Navigator.of(context)
                                      .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DeliverableDetailScreen(
                                          deliverableId:
                                              dliv.id),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: StegSpacing.md),

              // --- Evaluations + new ---
              DashboardSection(
                title: l10n.evalHistorySection,
                action: StegButton(
                  label: l10n.evalNew,
                  variant: StegButtonVariant.secondary,
                  icon: Icons.add_outlined,
                  onPressed: () =>
                      Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          EvaluationFormScreen(
                              internshipId: internshipId),
                    ),
                  ),
                ),
                child: d.evaluations.isEmpty
                    ? Text(l10n.myEvaluationsEmpty,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium)
                    : Column(
                        children: [
                          for (final e in d.evaluations)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                  Icons.star_outline),
                              title: Text(
                                  '${e.type} • ${formatDay(e.evaluationDate, locale)}'),
                              subtitle: e.totalScore ==
                                      null
                                  ? null
                                  : Text(l10n.scoreLabel(e
                                      .totalScore!
                                      .toStringAsFixed(2))),
                              trailing: const Icon(
                                  Icons.chevron_right),
                              onTap: () =>
                                  Navigator.of(context)
                                      .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EvaluationDetailScreen(
                                          evaluationId:
                                              e.id),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
