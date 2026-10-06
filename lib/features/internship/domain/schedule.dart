/// T04/D8 scheduling clock (SU-TASK-04, BR-53).
///
/// Business moments are absolute server instants; the picker works in
/// Africa/Tunis wall time. Africa/Tunis is UTC+1 year-round (no daylight
/// saving since 2009), so the offset is a documented constant — not a
/// lookup, and never the device time zone. The backend stores TIMESTAMPTZ
/// and compares against `now()`, which stays correct whatever the phone
/// claims.
library;

/// Fixed offset of Africa/Tunis to UTC (no DST).
const Duration tunisUtcOffset = Duration(hours: 1);

/// Tunis wall time (picked date + hour/minute) → absolute UTC instant for
/// `visibleFrom`. A past result means "immediate" server-side (never an
/// error); the server validates the period, never the client.
DateTime tunisWallToInstant(DateTime day, int hour, int minute) {
  final wall = DateTime.utc(day.year, day.month, day.day, hour, minute);
  return wall.subtract(tunisUtcOffset);
}

/// The Tunis wall time for an absolute instant (schedule display + the
/// edit sheet's initial picker values).
DateTime tunisWallFromInstant(DateTime instant) =>
    instant.toUtc().add(tunisUtcOffset);
