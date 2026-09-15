import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../domain/entities/evaluation.dart';
import '../providers/workspace_providers.dart';
import '../widgets/status_labels.dart';
import 'evaluation_detail_screen.dart';

/// Intern's evaluations, strictly read-only: authoritative totals,
/// per-criterion scores and advice. No form, no actions (task 8).
class MyEvaluationsScreen extends ConsumerWidget {
  const MyEvaluationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(myEvaluationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myEvaluations)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myEvaluationsProvider);
          try {
            await ref.read(myEvaluationsProvider.future);
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
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: StegLoading(),
                ),
                error: (e, _) {
                  if (e is StateError &&
                      e.message == 'no-internship') {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: StegEmptyView(
                        title: l10n.noInternshipTitle,
                        hint: l10n.noInternshipHint,
                        icon: Icons.school_outlined,
                      ),
                    );
                  }
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: StegErrorView(
                      message: e is ApiException
                          ? e.message
                          : e.toString(),
                      onRetry: () =>
                          ref.invalidate(myEvaluationsProvider),
                    ),
                  );
                },
                data: (page) {
                  if (page.items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: StegEmptyView(
                        title: l10n.myEvaluationsEmpty,
                        icon: Icons.star_outline,
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final e = page.items[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                                Icons.star_outline),
                            title: Text(
                                '${evaluationKindLabel(evaluationKindFrom(e.type), l10n)} • ${formatDay(e.evaluationDate, locale)}'),
                            subtitle: e.totalScore == null
                                ? null
                                : Text(l10n.scoreLabel(e
                                    .totalScore!
                                    .toStringAsFixed(2))),
                            trailing: const Icon(
                                Icons.chevron_right),
                            onTap: () =>
                                Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EvaluationDetailScreen(
                                        evaluationId: e.id),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: page.items.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
