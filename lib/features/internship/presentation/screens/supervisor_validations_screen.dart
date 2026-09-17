import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/repositories/internship_repository.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import 'deliverable_detail_screen.dart';
import 'journal_detail_sheet.dart';
import 'logbook_detail_screen.dart';

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
                  // Journal queue empty — deliverables + logbook sections
                  // below still render (or the combined empty state).
                  return SliverMainAxisGroup(
                    slivers: [
                      _DeliverablesQueueSliver(
                        isOnline: isOnline,
                        journalEmpty: true,
                      ),
                      const _LogbookQueueSliver(journalEmpty: true),
                    ],
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
                    _DeliverablesQueueSliver(
                      isOnline: isOnline,
                      journalEmpty: false,
                    ),
                    const _LogbookQueueSliver(
                      journalEmpty: false,
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

/// Deliverable review queue rendered beneath the journal queue.
/// Shows the combined empty state only when both queues are empty.
class _DeliverablesQueueSliver extends ConsumerWidget {
  const _DeliverablesQueueSliver({
    required this.isOnline,
    required this.journalEmpty,
  });

  final bool isOnline;
  final bool journalEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pendingDeliverableReviewsProvider);
    final logbookEmpty = (ref
            .watch(pendingLogbookReviewsProvider)
            .valueOrNull ??
        const <PendingLogbookReview>[])
        .isEmpty;
    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: StegSpacing.md),
          child: Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: StegSpacing.sm),
          child: Text(
            e is ApiException ? e.message : e.toString(),
            style: TextStyle(
                color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          if (!journalEmpty && !logbookEmpty) {
            return const SliverToBoxAdapter(
                child: SizedBox.shrink());
          }
          if (!logbookEmpty) {
            // Deliverables empty but logbook queue has items; the
            // logbook section renders below instead of the empty view.
            return const SliverToBoxAdapter(
                child: SizedBox.shrink());
          }
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
                    top: StegSpacing.md, bottom: StegSpacing.xs),
                child: Text(l10n.deliverablesTitle,
                    style:
                        Theme.of(context).textTheme.titleMedium),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final p = items[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                          Icons.upload_file_outlined),
                      title: Text(p.deliverable.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${p.internshipReference} • ${l10n.versionLabel(p.deliverable.currentVersion)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: StegStatusChip(
                        label: deliverableStatusLabel(
                            p.deliverable.status, l10n),
                        kind: deliverableStatusKind(
                            p.deliverable.status),
                      ),
                      onTap: () => Navigator.of(ctx).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DeliverableDetailScreen(
                                  deliverableId:
                                      p.deliverable.id),
                        ),
                      ),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Logbook review queue rendered beneath the deliverables queue:
/// SUBMITTED logbooks across supervised internships (server-authoritative
/// status; the backend gatekeepers the transition).
class _LogbookQueueSliver extends ConsumerWidget {
  const _LogbookQueueSliver({required this.journalEmpty});

  final bool journalEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(pendingLogbookReviewsProvider);
    return async.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: StegSpacing.md),
          child: Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: StegSpacing.sm),
          child: Text(
            e is ApiException ? e.message : e.toString(),
            style: TextStyle(
                color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
      data: (items) => items.isEmpty
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: StegSpacing.md, bottom: StegSpacing.xs),
                    child: Text(
                      '${l10n.logbookQueueTitle} (${items.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final p = items[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(p.internshipReference,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: p.logbook.submittedAt == null
                              ? null
                              : Text(formatDay(p.logbook.submittedAt!,
                                  Localizations.localeOf(ctx))),
                          trailing: StegStatusChip(
                            label: logbookStatusLabel(
                                p.logbook.status, l10n),
                            kind: logbookStatusKind(p.logbook.status),
                          ),
                          onTap: () => Navigator.of(ctx).push(
                            MaterialPageRoute(
                              builder: (_) => LogbookDetailScreen(
                                internshipId: p.internshipId,
                                internshipReference:
                                    p.internshipReference,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ],
            ),
    );
  }
}
