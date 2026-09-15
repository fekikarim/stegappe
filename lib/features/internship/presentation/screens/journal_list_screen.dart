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

/// Read-only journal list (D1): what the intern actually recorded, with
/// backend-owned validation states. Creation/submission flows land in D2.
class JournalListScreen extends ConsumerWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final async = ref.watch(journalListProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(journalListProvider);
        try {
          await ref.read(journalListProvider.future);
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
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: StegErrorView(
                    message:
                        e is ApiException ? e.message : e.toString(),
                    onRetry: () =>
                        ref.invalidate(journalListProvider),
                  ),
                );
              },
              data: (page) {
                if (page.items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: StegEmptyView(
                      title: l10n.journalEmpty,
                      icon: Icons.book_outlined,
                    ),
                  );
                }
                return SliverMainAxisGroup(
                  slivers: [
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
                          final j = page.items[i];
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                  Icons.edit_note_outlined),
                              title: Text(
                                  j.title.isEmpty ? '—' : j.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${formatDay(j.entryDate, locale)}'
                                '${j.description?.isNotEmpty == true ? ' • ${j.description!}' : ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: StegStatusChip(
                                label: journalStatusLabel(
                                    j.status, l10n),
                                kind:
                                    journalStatusKind(j.status),
                              ),
                            ),
                          );
                        },
                        childCount: page.items.length,
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
