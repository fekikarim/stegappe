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

/// Full supervised-intern list with pull-to-refresh.
class SupervisedInternsScreen extends ConsumerWidget {
  const SupervisedInternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(supervisedInternsProvider);
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
