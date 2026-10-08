import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../domain/calendar.dart';
import '../../domain/entities/evaluation.dart';
import '../providers/workspace_providers.dart';
import '../providers/notify_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/intern_card.dart';
import 'supervisor_calendar_screen.dart';

/// Supervisor Interns tab: candidates list (searchable, sortable) and the
/// internship-period calendar (SU-CAL-01/02), both projected from the
/// own-scope `supervisedInternsProvider` (T12/B2 — no conversation-derived
/// discovery anywhere). Tapping any row or lane opens the intern file.
class SupervisedInternsScreen extends ConsumerWidget {
  const SupervisedInternsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(supervisedInternsProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final last = ref.watch(lastSupervisedProvider);
    final view = ref.watch(supervisedViewProvider);

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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(StegSpacing.md,
                  StegSpacing.md, StegSpacing.md, StegSpacing.xs),
              child: _ViewToggle(),
            ),
          ),
          if (view == SupervisedView.list)
            const SliverToBoxAdapter(child: _SearchSortRow()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                StegSpacing.md, 0, StegSpacing.md, StegSpacing.md),
            sliver: async.when(
              loading: () => (last != null && !isOnline)
                  ? _InternsBody(interns: last, showStale: true)
                  : const SliverFillRemaining(
                      hasScrollBody: false,
                      child: StegLoading(),
                    ),
              error: (e, _) {
                if (last != null && !isOnline) {
                  return _InternsBody(interns: last, showStale: true);
                }
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: StegErrorView(
                    message: context.userError(e).message,
                    onRetry: () => refreshSupervisor(ref),
                  ),
                );
              },
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
                return _InternsBody(
                    interns: interns, showStale: !isOnline);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(supervisedViewProvider);
    return Semantics(
      label: '${l10n.supViewList} / ${l10n.supViewCalendar}',
      child: SegmentedButton<SupervisedView>(
        segments: [
          ButtonSegment(
            value: SupervisedView.list,
            label: Text(l10n.supViewList),
            icon: const Icon(Icons.view_list_outlined),
          ),
          ButtonSegment(
            value: SupervisedView.calendar,
            label: Text(l10n.supViewCalendar),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
        selected: {view},
        onSelectionChanged: (s) =>
            ref.read(supervisedViewProvider.notifier).state = s.first,
      ),
    );
  }
}

class _SearchSortRow extends ConsumerWidget {
  const _SearchSortRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sort = ref.watch(supervisedSortProvider);
    final selectMode = ref.watch(notifySelectModeProvider);
    String sortLabel(SupervisedSort s) => switch (s) {
          SupervisedSort.name => l10n.supSortName,
          SupervisedSort.endDate => l10n.supSortEndDate,
          SupervisedSort.status => l10n.supSortStatus,
        };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: StegSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.supSearchHint,
                prefixIcon: const Icon(Icons.search_outlined),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: (v) => ref
                  .read(supervisedSearchProvider.notifier)
                  .state = v,
            ),
          ),
          const SizedBox(width: StegSpacing.xs),
          Semantics(
            button: true,
            label: sortLabel(sort),
            child: PopupMenuButton<SupervisedSort>(
              tooltip: sortLabel(sort),
              icon: const Icon(Icons.sort_outlined),
              initialValue: sort,
              onSelected: (s) => ref
                  .read(supervisedSortProvider.notifier)
                  .state = s,
              itemBuilder: (ctx) => [
                for (final s in SupervisedSort.values)
                  PopupMenuItem(
                    value: s,
                    child: Text(sortLabel(s)),
                  ),
              ],
            ),
          ),
          // T14 multi-select toggle: checkboxes replace navigation while
          // active; exiting clears the selection (no stale rows).
          Semantics(
            button: true,
            label: l10n.notifyPrepareAsk,
            child: IconButton(
              tooltip: l10n.notifyPrepareAsk,
              icon: Icon(selectMode
                  ? Icons.checklist_outlined
                  : Icons.playlist_add_check_outlined),
              color: selectMode
                  ? Theme.of(context).colorScheme.primary
                  : null,
              onPressed: () {
                if (selectMode) {
                  ref
                      .read(notifyPreparationProvider.notifier)
                      .clearSelection();
                }
                ref.read(notifySelectModeProvider.notifier).state =
                    !selectMode;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// List or calendar body with explicit stale labeling (offline audit).
/// Search/sort apply to the list view only; the calendar always shows
/// every supervised period (a filtered-out period must never vanish
/// silently from the supervisor's overview).
class _InternsBody extends ConsumerWidget {
  const _InternsBody({required this.interns, required this.showStale});

  final List<SupervisedIntern> interns;
  final bool showStale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(supervisedViewProvider);
    if (view == SupervisedView.calendar) {
      return SliverMainAxisGroup(
        slivers: [
          if (showStale)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: StegSpacing.sm),
                child: StaleNotice(),
              ),
            ),
          SliverToBoxAdapter(
            child: SupervisorCalendar(interns: interns),
          ),
        ],
      );
    }
    final query = ref.watch(supervisedSearchProvider);
    final sort = ref.watch(supervisedSortProvider);
    final rows = sortSupervised(filterSupervised(interns, query), sort);
    if (rows.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: StegEmptyView(
          title: AppLocalizations.of(context).noSupervised,
          hint: AppLocalizations.of(context).noSupervisedHint,
          icon: Icons.search_off_outlined,
        ),
      );
    }
    final selectMode = ref.watch(notifySelectModeProvider);
    final selected =
        ref.watch(notifyPreparationProvider.select((s) => s.selected));
    return SliverMainAxisGroup(
      slivers: [
        if (showStale)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: StegSpacing.sm),
              child: StaleNotice(),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final intern = rows[i];
              // Tapping any row opens the intern file (shared card), or
              // toggles selection while the notify mode is active.
              return InternCard(
                intern: intern,
                selected: selected.contains(intern.internshipId),
                onSelectionChanged: selectMode
                    ? (_) => ref
                        .read(notifyPreparationProvider.notifier)
                        .toggle(intern.internshipId)
                    : null,
              );
            },
            childCount: rows.length,
          ),
        ),
        if (selectMode) const SliverToBoxAdapter(child: _NotifyBar()),
      ],
    );
  }
}

/// T14 multi-select send bar: count, empty hint, send (disabled without
/// selection, offline or in flight) and result/error feedback. The UI
/// waits only for server acceptance, never for recipient delivery.
class _NotifyBar extends ConsumerWidget {
  const _NotifyBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(notifyPreparationProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final canSend =
        state.selected.isNotEmpty && !state.sending && isOnline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.selected.isEmpty
                  ? l10n.notifyEmptyHint
                  : l10n.notifySelected(state.selected.length),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!isOnline) ...[
              const SizedBox(height: StegSpacing.xs),
              Text(
                l10n.notifyNeedsConnection,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: StegSpacing.xs),
              Semantics(
                liveRegion: true,
                label: context.userError(state.error!).message,
                excludeSemantics: true,
                child: Text(
                  !isOnline
                      ? l10n.notifyNeedsConnection
                      : context.userError(state.error!).message,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (state.lastNotified != null) ...[
              const SizedBox(height: StegSpacing.xs),
              Semantics(
                liveRegion: true,
                label: l10n.notifySuccess(state.lastNotified!),
                excludeSemantics: true,
                child: Text(
                  l10n.notifySuccess(state.lastNotified!),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
            const SizedBox(height: StegSpacing.xs),
            StegButton(
              label: l10n.notifyPrepareAsk,
              icon: Icons.send_outlined,
              loading: state.sending,
              onPressed: !canSend ? null : () => _send(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    await ref.read(notifyPreparationProvider.notifier).send();
    if (!context.mounted) return;
    final after = ref.read(notifyPreparationProvider);
    if (after.error == null && after.lastNotified != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)
              .notifySuccess(after.lastNotified!)),
        ),
      );
    }
  }
}
