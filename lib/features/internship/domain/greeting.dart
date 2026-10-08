/// Time-of-day greeting bands (T13 ST-HOME-03/SU-HOME-04).
///
/// Pure display concern (BR-53): the device clock may choose the greeting
/// but must never drive a business decision. Bands are fixed and
/// boundary-deterministic (unit-tested on an injected clock):
/// 05:00–12:00 morning, 12:00–18:00 afternoon, 18:00–23:00 evening,
/// otherwise night.
enum DayBand { morning, afternoon, evening, night }

DayBand greetingBand(DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  if (minutes >= 5 * 60 && minutes < 12 * 60) return DayBand.morning;
  if (minutes >= 12 * 60 && minutes < 18 * 60) return DayBand.afternoon;
  if (minutes >= 18 * 60 && minutes < 23 * 60) return DayBand.evening;
  return DayBand.night;
}
