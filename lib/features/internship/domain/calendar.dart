import 'entities/evaluation.dart';

/// Pure month-grid math for the supervisor period calendar (T12/SU-CAL-01).
///
/// Periods are server `LocalDate`s with all-day semantics: no timezone
/// conversion happens here (and none is needed — unlike `visibleFrom`
/// instants in `schedule.dart`, a date is not an instant). The backend is
/// the only authority on which internships exist; these helpers only
/// project them onto a grid.

/// First cell weekday convention follows `DateTime.weekday`
/// (Monday = 1 … Sunday = 7).
List<DateTime?> monthCells(int year, int month, int firstWeekday) {
  final first = DateTime(year, month, 1);
  var leading = (first.weekday - firstWeekday) % 7;
  if (leading < 0) leading += 7;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final cells = <DateTime?>[
    for (var i = 0; i < leading; i++) null,
    for (var d = 1; d <= daysInMonth; d++) DateTime(year, month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

/// Monday-based week rows covering the month (each exactly 7 cells).
List<List<DateTime?>> monthWeeks(int year, int month, int firstWeekday) {
  final cells = monthCells(year, month, firstWeekday);
  return [
    for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
  ];
}

/// True when the internship period touches the displayed month at all.
bool periodOverlapsMonth(DateTime start, DateTime end, int year, int month) {
  final monthStart = DateTime(year, month, 1);
  final monthEnd = DateTime(year, month + 1, 0);
  return !end.isBefore(monthStart) && !start.isAfter(monthEnd);
}

/// Segment of a period inside one 7-day week starting [weekStart].
/// Returns `null` when the period does not touch the week; otherwise the
/// 0-based cell offset and the covered cell count (both clamped to 0..6).
({int offset, int length})? weekSegment(
    DateTime start, DateTime end, DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  if (end.isBefore(weekStart) || start.isAfter(weekEnd)) return null;
  final from = start.isBefore(weekStart) ? weekStart : start;
  final to = end.isAfter(weekEnd) ? weekEnd : end;
  final offset = from.difference(weekStart).inDays.clamp(0, 6);
  final last = to.difference(weekStart).inDays.clamp(0, 6);
  if (last < offset) return null;
  return (offset: offset, length: last - offset + 1);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Home queue-tile totals across the supervised rows (T13): SUBMITTED-only
/// journal entries (the review queue) and SUBMITTED deliverables. Pure so
/// the tile semantics stay pinned by unit test, not by widget inspection.
({int submittedJournal, int submittedDeliverables}) queueTotals(
        List<SupervisedIntern> interns) =>
    (
      submittedJournal:
          interns.fold(0, (sum, i) => sum + i.submittedJournal),
      submittedDeliverables:
          interns.fold(0, (sum, i) => sum + i.pendingDeliverables),
    );

/// Case-insensitive name/reference filter for the candidates list.
List<SupervisedIntern> filterSupervised(
    List<SupervisedIntern> interns, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return interns;
  return [
    for (final s in interns)
      if (s.internName.toLowerCase().contains(q) ||
          s.reference.toLowerCase().contains(q))
        s,
  ];
}

/// Candidates-list sort orders (SU-CAL-02).
enum SupervisedSort { name, endDate, status }

/// Stable sort: ties keep the server order.
List<SupervisedIntern> sortSupervised(
    List<SupervisedIntern> interns, SupervisedSort sort) {
  final out = List.of(interns);
  switch (sort) {
    case SupervisedSort.name:
      out.sort((a, b) => a.internName
          .toLowerCase()
          .compareTo(b.internName.toLowerCase()));
    case SupervisedSort.endDate:
      out.sort((a, b) => a.endDate.compareTo(b.endDate));
    case SupervisedSort.status:
      out.sort((a, b) => a.status.index.compareTo(b.status.index));
  }
  return out;
}
