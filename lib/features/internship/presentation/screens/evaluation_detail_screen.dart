import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../domain/entities/evaluation.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';

/// Evaluation detail: authoritative server total, per-criterion scores,
/// linked task reviews, assessment advice and comments. Read-only for
/// everyone (interns see their completed evaluations here).
class EvaluationDetailScreen extends ConsumerWidget {
  const EvaluationDetailScreen({
    super.key,
    required this.evaluationId,
    this.created = false,
  });

  final String evaluationId;
  final bool created;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async =
        ref.watch(evaluationFullProvider(evaluationId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.evalHistorySection)),
      body: async.when(
        loading: () => const StegLoading(),
        error: (e, _) => StegErrorView(
          message: e is ApiException ? e.message : e.toString(),
          onRetry: () => ref
              .invalidate(evaluationFullProvider(evaluationId)),
        ),
        data: (full) {
          final d = full.detail;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                  evaluationFullProvider(evaluationId));
              try {
                await ref.read(evaluationFullProvider(
                    evaluationId).future);
              } on Exception {
                // Error UI renders via the AsyncValue.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: StegSpacing.screenPadding,
              children: [
                // --- Authoritative total (server-computed) ---
                Semantics(
                  header: true,
                  label: d.totalScore == null
                      ? l10n.evalHistorySection
                      : l10n.evalOfficialTotal(d.totalScore!
                          .toStringAsFixed(2)),
                  excludeSemantics: true,
                  child: Card(
                    child: Padding(
                      padding: StegSpacing.cardPadding,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${evaluationKindLabel(evaluationKindFrom(d.type), l10n)} • ${formatDay(d.evaluationDate, locale)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                          const SizedBox(
                              height: StegSpacing.xs),
                          Text(
                            d.totalScore == null
                                ? '—'
                                : l10n.evalOfficialTotal(
                                    d.totalScore!
                                        .toStringAsFixed(2)),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: StegSpacing.md),

                // --- Per-criterion scores ---
                DashboardSection(
                  title: l10n.evalScoresSection,
                  child: full.scores.isEmpty
                      ? Text(l10n.journalNoComments,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall)
                      : Column(
                          children: [
                            for (final s in full.scores)
                              ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                dense: true,
                                title: Text(s.criterionName,
                                    maxLines: 2,
                                    overflow:
                                        TextOverflow.ellipsis),
                                subtitle: s.comment?.isNotEmpty ==
                                        true
                                    ? Text(s.comment!,
                                        maxLines: 2,
                                        overflow: TextOverflow
                                            .ellipsis)
                                    : null,
                                trailing: Text(
                                  '${s.score.toStringAsFixed(1)}/${s.maxScore.toStringAsFixed(0)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: StegSpacing.md),

                // --- Linked task reviews ---
                if (full.taskReviews.isNotEmpty) ...[
                  DashboardSection(
                    title: l10n.evalReviewsSection,
                    child: Column(
                      children: [
                        for (final r in full.taskReviews)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(
                              r.completed
                                  ? Icons.check_circle_outline
                                  : Icons
                                      .radio_button_unchecked_outlined,
                            ),
                            title: Text(r.taskTitle,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                r.completed
                                    ? l10n.evalTaskDone
                                    : l10n.evalTaskNotDone,
                                if (r.score != null)
                                  l10n.scoreLabel(r.score!
                                      .toStringAsFixed(1)),
                                if (r.comment?.isNotEmpty ==
                                    true)
                                  r.comment!,
                              ].join(' • '),
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: StegSpacing.md),
                ],

                // --- Assessment advice (separate from journal) ---
                if (d.feedback?.isNotEmpty == true) ...[
                  DashboardSection(
                    title: l10n.evalAdviceSection,
                    child: Text(d.feedback!),
                  ),
                  const SizedBox(height: StegSpacing.md),
                ],

                // --- Discussion comments ---
                DashboardSection(
                  title: l10n.journalComments,
                  child: full.comments.isEmpty
                      ? Text(l10n.journalNoComments,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall)
                      : Column(
                          children: [
                            for (final c in full.comments)
                              ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                dense: true,
                                leading: const Icon(
                                    Icons.comment_outlined,
                                    size: 20),
                                title: Text(c.content),
                                subtitle: Text(
                                    '${c.authorEmail} • ${formatDay(c.createdAt, locale)}',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
