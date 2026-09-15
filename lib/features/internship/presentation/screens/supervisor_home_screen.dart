import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/intern_card.dart';

/// Supervisor overview: queue totals + interns needing attention.
/// Formal, concise, actionable (UI_UX.md §12.4).
class SupervisorHomeScreen extends ConsumerWidget {
  const SupervisorHomeScreen({super.key, this.onOpenTab});

  final void Function(int tab)? onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(supervisedInternsProvider);
    final validationsAsync = ref.watch(pendingValidationsProvider);
    final delivAsync = ref.watch(pendingDeliverableReviewsProvider);
    final isOnline = ref.watch(isOnlineProvider);

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
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: StegLoading(),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: StegErrorView(
                  message:
                      e is ApiException ? e.message : e.toString(),
                  onRetry: () => refreshSupervisor(ref),
                ),
              ),
              data: (interns) {
                final attention = interns
                    .where((i) => i.needsAttention)
                    .toList();
                final pendingJournal = validationsAsync.valueOrNull
                        ?.length ??
                    0;
                final pendingDeliv =
                    delivAsync.valueOrNull?.length ?? 0;
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
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            label: l10n.supHomeTitle,
                            excludeSemantics: true,
                            child: Text(l10n.supHomeTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall),
                          ),
                          const SizedBox(
                              height: StegSpacing.sm),
                          _QueueRow(
                            pendingJournal: pendingJournal,
                            pendingDeliverables: pendingDeliv,
                            onOpenTab: onOpenTab,
                          ),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: StegSpacing.md,
                            bottom: StegSpacing.xs),
                        child: Text(l10n.needsAttention,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                      ),
                    ),
                    if (attention.isEmpty)
                      SliverToBoxAdapter(
                        child: _Hint(text: l10n.allCaughtUp),
                      )
                    else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) =>
                            InternCard(intern: attention[i]),
                        childCount: attention.length,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: StegSpacing.md,
                            bottom: StegSpacing.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(l10n.myInterns,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                            ),
                            TextButton(
                              onPressed: () =>
                                  onOpenTab?.call(1),
                              child: Text(l10n.viewAll),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) =>
                            InternCard(intern: interns[i]),
                        childCount: interns.length,
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
        borderRadius:
            BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(StegSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: StegSpacing.xs),
              Text('$count',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall),
              Text(label,
                  style:
                      Theme.of(context).textTheme.bodySmall),
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
