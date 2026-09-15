import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import 'journal_detail_sheet.dart';

/// Supervisor queue: SUBMITTED journal entries across supervised
/// internships (discovered via PRIVATE conversations).
///
/// Decisions are strictly server-confirmed: no optimistic state, and
/// while offline the list may render but every decision visibly fails
/// instead of pretending success (D2 §8/§9).
class SupervisorValidationsScreen extends ConsumerWidget {
  const SupervisorValidationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(pendingValidationsProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return RefreshIndicator(
      onRefresh: () async {
        refreshValidations(ref);
        try {
          await ref.read(pendingValidationsProvider.future);
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
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: StegErrorView(
                  message:
                      e is ApiException ? e.message : e.toString(),
                  onRetry: () => refreshValidations(ref),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: StegEmptyView(
                      title: l10n.validationsEmpty,
                      hint: l10n.validationsHint,
                      icon: Icons.fact_check_outlined,
                    ),
                  );
                }
                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            bottom: StegSpacing.sm),
                        child: Text(l10n.validationsHint,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium),
                      ),
                    ),
                    if (!isOnline)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(
                              bottom: StegSpacing.sm),
                          child: StaleNotice(),
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final p = items[i];
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                  Icons.pending_actions_outlined),
                              title: Text(
                                  p.entry.title.isEmpty
                                      ? '—'
                                      : p.entry.title,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis),
                              subtitle: Text(
                                '${p.internshipReference} • ${formatDay(p.entry.entryDate, locale)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: StegStatusChip(
                                label: journalStatusLabel(
                                    p.entry.status, l10n),
                                kind: journalStatusKind(
                                    p.entry.status),
                              ),
                              onTap: () => showJournalDetailSheet(
                                  context, p.entry),
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
