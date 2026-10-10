import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_motion.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../providers/journal_calendar_providers.dart';

/// Modern month calendar for the journal (STEG-JRN).
///
/// Design contract:
/// - the **internship period** is a clearly visible band on every in-period
///   day, coloured with the student's chosen [JournalAccent] — that band is
///   what makes the journal read as "my stage", not a generic month;
/// - a day that already carries work shows a mark, so the student can see
///   his accomplishment at a glance before opening anything;
/// - today is ringed, the selected day is filled, and days outside the period
///   or in the future recede — the calendar is scannable, not decorative;
/// - every cell is a real 48 dp touch target with its own semantics label.
///
/// Layout is dense by nature (7 columns), so labels scale down with
/// `FittedBox` instead of clipping — the user's text scale is never ignored
/// and the grid never overflows.
class JournalMonthCalendar extends StatelessWidget {
  const JournalMonthCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.onSelect,
    required this.onMonthChanged,
    required this.start,
    required this.end,
    this.markedDays = const {},
    this.today,
    required this.accent,
  });

  /// Any day inside the displayed month.
  final DateTime month;

  /// Currently selected day (drives the day's entry list).
  final DateTime selected;
  final void Function(DateTime day) onSelect;
  final void Function(DateTime month) onMonthChanged;

  /// Internship period (inclusive, date-only).
  final DateTime start;
  final DateTime end;

  /// Days that already carry at least one journal entry.
  final Set<DateTime> markedDays;

  final DateTime? today;

  /// The student's chosen period colour (persisted preference).
  final JournalAccent accent;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final palette = JournalPalette.of(accent, Theme.of(context).brightness);
    final todayDay = _day(today ?? DateTime.now());
    final startDay = _day(start);
    final endDay = _day(end);

    // Monday-first grid (the app's day convention everywhere else).
    final cells = _cells(month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final visible = cells.where((c) => c != null).length;
    // Trailing days of the next month fill the last week for a stable height.
    final rows = (visible / 7).ceil().clamp(5, 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthHeader(
          month: month,
          // Publish the shifted month — computing it without calling back
          // would leave the arrows inert.
          onPrevious: () => onMonthChanged(_shift(month, -1)),
          onNext: () => onMonthChanged(_shift(month, 1)),
          onToday: () {
            onMonthChanged(DateTime(todayDay.year, todayDay.month));
            onSelect(todayDay);
          },
        ),
        const SizedBox(height: StegSpacing.xs),
        _WeekdayHeader(firstWeekday: DateTime.monday),
        const SizedBox(height: StegSpacing.xxs),
        // Fixed-height rows keep the calendar from jumping between months.
        // The extent is explicit (never an aspect ratio) so the spacing can
        // never eat into the 48 dp touch target.
        SizedBox(
          height: rows * _cellHeight(context) +
              (rows - 1) * _cellSpacing,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: _cellHeight(context),
              mainAxisSpacing: _cellSpacing,
              crossAxisSpacing: _cellSpacing,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, i) {
              final date = DateTime(month.year, month.month, i + 1);
              final inPeriod = !date.isBefore(startDay) &&
                  !date.isAfter(endDay);
              return _DayCell(
                date: date,
                selected: _day(selected) == date,
                isToday: todayDay == date,
                inPeriod: inPeriod,
                hasEntry: markedDays.contains(date),
                isFuture: date.isAfter(todayDay),
                palette: palette,
                onTap: () => onSelect(date),
              );
            },
          ),
        ),
        const SizedBox(height: StegSpacing.xs),
        _Legend(palette: palette),
      ],
    );
  }

  /// 48 dp minimum, grown with the user's text scale so a 2× setting keeps
  /// every day tappable instead of shrinking the target.
  static const double _cellSpacing = 2;

  static double _cellHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final scaled = scaler.scale(13);
    return StegSpacing.minTouchTarget + (scaled - 13) * 0.6;
  }

  DateTime _shift(DateTime month, int delta) {
    final m = DateTime(month.year, month.month + delta);
    return DateTime(m.year, m.month);
  }

  List<DateTime?> _cells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    var leading = (first.weekday - DateTime.monday) % 7;
    if (leading < 0) leading += 7;
    return [
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= DateTime(month.year, month.month + 1, 0).day; d++)
        DateTime(month.year, month.month, d),
    ];
  }

  static String shortWeekday(Locale locale, DateTime date) {
    try {
      return DateFormat.E(locale.languageCode).format(date);
    } on Exception {
      return DateFormat.E().format(date);
    }
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final rtl = StegLocales.isRtl(locale);
    String label;
    try {
      label = DateFormat.yMMMM(locale.languageCode).format(month);
    } on Exception {
      label = DateFormat.yMMMM().format(month);
    }
    return Row(
      children: [
        _RoundIconButton(
          tooltip: l10n.journalPrevMonth,
          icon: rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Semantics(
            header: true,
            label: label,
            excludeSemantics: true,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(letterSpacing: -0.1),
            ),
          ),
        ),
        _RoundIconButton(
          tooltip: l10n.backToToday,
          icon: Icons.today_outlined,
          onPressed: onToday,
        ),
        _RoundIconButton(
          tooltip: l10n.journalNextMonth,
          icon: rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: SizedBox(
        width: StegSpacing.minTouchTarget,
        height: StegSpacing.minTouchTarget,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainerHighest
                .withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.firstWeekday});

  final int firstWeekday;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    // Monday = 1 … Sunday = 7 (DateTime.weekday convention).
    final base = firstWeekday - 1;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  JournalMonthCalendar.shortWeekday(
                    locale,
                    DateTime(2024, 1, 1 + base + i),
                  ),
                  maxLines: 1,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One day. The whole cell is the touch target; the state is carried by the
/// fill, the ring and the mark dot — always next to the day number itself, so
/// the meaning never depends on colour alone.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.inPeriod,
    required this.hasEntry,
    required this.isFuture,
    required this.palette,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final bool inPeriod;
  final bool hasEntry;
  final bool isFuture;
  final JournalPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dimmed = !inPeriod || isFuture;

    final Color fill;
    if (selected) {
      fill = palette.seed;
    } else if (inPeriod) {
      fill = palette.dayFill;
    } else {
      fill = palette.outsideFill;
    }

    final fg = selected
        ? Colors.white
        : dimmed
            ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
            : scheme.onSurface;

    final dayLabel = MaterialLocalizations.of(context).formatFullDate(date);

    return Semantics(
      button: true,
      selected: selected,
      label: '$dayLabel'
          '${inPeriod ? ', ${l10n.journalInPeriod}' : ''}'
          '${hasEntry ? ', ${l10n.journalHasEntry}' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: StegMotion.fast,
            curve: StegMotion.standard,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday && !selected
                    ? palette.seed
                    : (selected
                        ? Colors.transparent
                        : (inPeriod
                            ? palette.dayBorder
                            : Colors.transparent)),
                width: isToday || selected ? 1.6 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Day number scales down instead of clipping, so the grid
                // survives a 2× text setting.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${date.day}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: fg,
                              fontWeight: hasEntry || selected
                                  ? FontWeight.w800
                                  : FontWeight.w600),
                    ),
                  ),
                ),
                if (hasEntry)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : palette.seed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legend: explains the band and the mark, so the calendar teaches itself.
class _Legend extends StatelessWidget {
  const _Legend({required this.palette});

  final JournalPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Full-width rows (not a Wrap): at 2x the labels wrap instead of
    // overflowing the card horizontally.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendItem(
          gradient: palette.legendGradient,
          label: l10n.journalInPeriod,
        ),
        const SizedBox(height: StegSpacing.xxs),
        _LegendChipDot(color: palette.seed, label: l10n.journalHasEntry),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.gradient, required this.label});

  final List<Color> gradient;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _LegendChipDot extends StatelessWidget {
  const _LegendChipDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}