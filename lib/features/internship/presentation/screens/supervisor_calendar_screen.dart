import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../domain/calendar.dart';
import '../../domain/entities/evaluation.dart';
import '../widgets/status_labels.dart';
import 'intern_detail_screen.dart';

/// Displayed-month cursor (day always the 1st; the day grid is derived).
final calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Distinct lane fills, cycled per internship. Labels always carry the
/// meaning (name + period on the bar, full description in semantics), so
/// colour only assists — safe for both themes and greyscale.
const List<Color> _lanePalette = <Color>[
  Colors.teal,
  Colors.blue,
  Colors.indigo,
  Colors.deepPurple,
  Colors.pink,
  Colors.orange,
  Colors.brown,
  Colors.blueGrey,
];

/// Supervisor period calendar (T12/SU-CAL-01): one lane per supervised
/// internship overlapping the displayed month, stacked so overlapping
/// periods never collide. Pure projection of server dates — no business
/// computation, no mutation; tapping a lane opens the intern file.
class SupervisorCalendar extends ConsumerWidget {
  const SupervisorCalendar({super.key, required this.interns});

  final List<SupervisedIntern> interns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final cursor = ref.watch(calendarMonthProvider);
    final materialFirst =
        MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final firstWeekday = materialFirst == 0 ? DateTime.sunday : materialFirst;
    final weeks = monthWeeks(cursor.year, cursor.month, firstWeekday);
    final visible = [
      for (var i = 0; i < interns.length; i++)
        if (periodOverlapsMonth(
            interns[i].startDate, interns[i].endDate, cursor.year, cursor.month))
          (index: i, intern: interns[i]),
    ];
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthBar(cursor: cursor),
        _WeekdayHeader(firstWeekday: firstWeekday),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: StegSpacing.md),
            child: Text(l10n.supEmptyMonth,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          )
        else
          for (final week in weeks) ...[
            _DayRow(week: week, today: todayDay),
            Builder(builder: (ctx) {
              final anchor = week.firstWhere((d) => d != null,
                  orElse: () => null);
              if (anchor == null) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final lane in visible)
                    _LaneBar(
                      lane: lane,
                      weekStart: anchor,
                      locale: locale,
                    ),
                ],
              );
            }),
            const SizedBox(height: StegSpacing.xs),
          ],
      ],
    );
  }
}

class _MonthBar extends ConsumerWidget {
  const _MonthBar({required this.cursor});

  final DateTime cursor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    String title;
    try {
      title =
          DateFormat.yMMMM(locale.languageCode).format(cursor);
    } on Exception {
      title = DateFormat.yMMMM().format(cursor);
    }
    final rtl = StegLocales.isRtl(locale);
    return Row(
      children: [
        IconButton(
          tooltip: l10n.supPrevMonth,
          icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
          onPressed: () => ref.read(calendarMonthProvider.notifier).state =
              DateTime(cursor.year, cursor.month - 1, 1),
        ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        // T15: the two nav IconButtons plus an unbounded "today" label
        // overflowed the bar by 21 px at 2.0× (measured). The action is
        // bounded and ellipsizes; the full label stays in its tooltip.
        ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.28),
          child: Tooltip(
            message: l10n.backToToday,
            child: TextButton(
              onPressed: () {
                final now = DateTime.now();
                ref.read(calendarMonthProvider.notifier).state =
                    DateTime(now.year, now.month, 1);
              },
              child: Text(l10n.backToToday,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.supNextMonth,
          icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
          onPressed: () => ref.read(calendarMonthProvider.notifier).state =
              DateTime(cursor.year, cursor.month + 1, 1),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.firstWeekday});

  final int firstWeekday;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    // 2024-01-01 was a Monday; Jan 1..7 cover Mon..Sun without any clock.
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (ctx) {
              final weekday = (firstWeekday - 1 + i) % 7 + 1;
              String label;
              try {
                // 2024-01-01 was a Monday: Jan 1..7 cover Mon..Sun.
                label = DateFormat.E(locale.languageCode)
                    .format(DateTime(2024, 1, weekday));
              } on Exception {
                label =
                    DateFormat.E().format(DateTime(2024, 1, weekday));
              }
              return Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.bodySmall);
            }),
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.week, required this.today});

  final List<DateTime?> week;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final day in week)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(1),
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: day != null && isSameDay(day, today)
                  ? BoxDecoration(
                      border: Border.all(color: scheme.primary),
                      borderRadius:
                          BorderRadius.circular(StegSpacing.radiusSm),
                    )
                  : null,
              child: Text(
                day == null ? '' : '${day.day}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: day == null
                          ? scheme.outline
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LaneBar extends StatelessWidget {
  const _LaneBar({
    required this.lane,
    required this.weekStart,
    required this.locale,
  });

  final ({int index, SupervisedIntern intern}) lane;
  final DateTime weekStart;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final segment = weekSegment(
        lane.intern.startDate, lane.intern.endDate, weekStart);
    if (segment == null) return const SizedBox.shrink();
    final color = _lanePalette[lane.index % _lanePalette.length];
    final scheme = Theme.of(context).colorScheme;
    final description =
        '${lane.intern.internName}, ${formatDay(lane.intern.startDate, locale)} → '
        '${formatDay(lane.intern.endDate, locale)}, '
        '${internshipStatusLabel(lane.intern.status, l10n)}';
    // T15: the lane is the tap target (it opens the intern file) and measured
    // 26 px tall — below the 48 dp minimum. The visual bar keeps its height
    // while the interactive box grows to a real target.
    return SizedBox(
      height: StegSpacing.minTouchTarget,
      child: Semantics(
        button: true,
        label: description,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InternDetailScreen(
                  internshipId: lane.intern.internshipId),
            ),
          ),
          borderRadius: BorderRadius.circular(StegSpacing.radiusSm),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                if (i < segment.offset ||
                    i >= segment.offset + segment.length)
                  const Expanded(child: SizedBox(height: 26))
                else
                  Expanded(
                    child: Container(
                      height: 26,
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.22),
                        border: Border(
                          left: i == segment.offset
                              ? BorderSide(color: color, width: 3)
                              : BorderSide.none,
                        ),
                        borderRadius:
                            BorderRadius.circular(StegSpacing.radiusSm),
                      ),
                      child: i == segment.offset
                          ? Text(
                              lane.intern.internName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            )
                          : null,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
