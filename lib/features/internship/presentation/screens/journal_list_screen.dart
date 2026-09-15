import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import 'journal_composer_screen.dart';
import 'journal_detail_sheet.dart';

/// Journal tab: what the intern ACTUALLY did (never a substitute for
/// planned tasks). Day navigation filters server-side; status chips
/// refine; FAB opens the composer for the selected day.
class JournalListScreen extends ConsumerWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(journalListProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final auth = ref.watch(authControllerProvider);
    final isIntern = auth is AuthAuthenticated &&
        auth.user.mobileRole == UserRole.intern;
    final internshipId =
        ref.watch(myInternshipIdProvider).valueOrNull;

    return Stack(
      children: [
        RefreshIndicator(
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
              const SliverToBoxAdapter(child: _DayStrip()),
              const SliverToBoxAdapter(child: _StatusFilter()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    StegSpacing.md, 0, StegSpacing.md, StegSpacing.md),
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
                          hint: l10n.journalWhatDid,
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
                              return _EntryCard(entry: j);
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
        ),
        if (isIntern && internshipId != null)
          PositionedDirectional(
            end: StegSpacing.md,
            bottom: StegSpacing.md,
            child: Semantics(
              button: true,
              label: l10n.journalNew,
              child: FloatingActionButton(
                tooltip: l10n.journalNew,
                onPressed: () {
                  final day = ref.read(selectedDayProvider);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JournalComposerScreen(
                        internshipId: internshipId,
                        day: day,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.add),
              ),
            ),
          ),
      ],
    );
  }
}

/// Horizontal 7-day strip around the selected day + week arrows.
/// All paddings directional so Arabic mirrors the strip.
class _DayStrip extends ConsumerWidget {
  const _DayStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final selected = ref.watch(selectedDayProvider);
    final weekStart =
        selected.subtract(Duration(days: selected.weekday - 1));
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    // Directional week navigation: "previous" points to the visual start.
    final rtl =
        StegLocales.isRtl(Localizations.localeOf(context));

    String dayLabel(DateTime d) {
      try {
        return DateFormat.E(locale.languageCode).format(d);
      } on Exception {
        return DateFormat.E().format(d);
      }
    }

    return Semantics(
      label: l10n.todayMark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(StegSpacing.md,
            StegSpacing.md, StegSpacing.md, StegSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '‹',
                  icon: Icon(
                      rtl ? Icons.chevron_right : Icons.chevron_left),
                  onPressed: () => ref
                      .read(selectedDayProvider.notifier)
                      .state =
                      selected.subtract(const Duration(days: 7)),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        _DayCell(
                          date: weekStart.add(Duration(days: i)),
                          selected: _sameDay(
                              weekStart.add(Duration(days: i)),
                              selected),
                          isToday: _sameDay(
                              weekStart.add(Duration(days: i)),
                              todayDay),
                          weekday: dayLabel(
                              weekStart.add(Duration(days: i))),
                          onTap: () => ref
                              .read(selectedDayProvider.notifier)
                              .state =
                              weekStart.add(Duration(days: i)),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '›',
                  icon: Icon(
                      rtl ? Icons.chevron_left : Icons.chevron_right),
                  onPressed: () => ref
                      .read(selectedDayProvider.notifier)
                      .state = selected.add(const Duration(days: 7)),
                ),
              ],
            ),
            if (!_sameDay(selected, todayDay))
              Align(
                alignment: AlignmentDirectional.center,
                child: TextButton.icon(
                  icon: const Icon(Icons.today_outlined, size: 18),
                  label: Text(l10n.backToToday),
                  onPressed: () => ref
                      .read(selectedDayProvider.notifier)
                      .state = todayDay,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.weekday,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final String weekday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '${date.day} $weekday',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(StegSpacing.radiusSm),
          child: Container(
            margin: const EdgeInsets.symmetric(
                horizontal: 2, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : null,
              borderRadius:
                  BorderRadius.circular(StegSpacing.radiusSm),
              border: isToday && !selected
                  ? Border.all(color: scheme.primary)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekday,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${date.day}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilter extends ConsumerWidget {
  const _StatusFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(journalStatusFilterProvider);
    final options = <JournalStatus?>[
      null,
      JournalStatus.draft,
      JournalStatus.submitted,
      JournalStatus.validated,
      JournalStatus.rejected,
    ];
    String label(JournalStatus? s) => s == null
        ? l10n.filterAll
        : journalStatusLabel(s, l10n);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: StegSpacing.md),
      child: Row(
        children: [
          for (final o in options) ...[
            ChoiceChip(
              label: Text(label(o)),
              selected: filter == o,
              onSelected: (_) => ref
                  .read(journalStatusFilterProvider.notifier)
                  .state = o,
            ),
            const SizedBox(width: StegSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.edit_note_outlined),
        title: Text(entry.title.isEmpty ? '—' : entry.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${formatDay(entry.entryDate, locale)}'
          '${entry.description?.isNotEmpty == true ? ' • ${entry.description!}' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: StegStatusChip(
          label: journalStatusLabel(entry.status, l10n),
          kind: journalStatusKind(entry.status),
        ),
        onTap: () => showJournalDetailSheet(context, entry),
      ),
    );
  }
}
