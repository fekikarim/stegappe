// E0.6 — single date/time + currency formatting helper (Mobile).
// Backend stores UTC ISO 8601; UI renders in Africa/Tunis.
// Arabic locale uses Western digits (Latn) consistently across all clients.
import 'package:intl/intl.dart';

/// IANA zone for display. Dart [DateTime] parses ISO 8601 as UTC when suffixed
/// with Z; formatting uses the device zone — schedule/journal screens must pass
/// Tunis-shifted values or rely on server-rendered strings. This constant
/// documents the contract; conversion happens via [toTunis].
class StegFormat {
  const StegFormat._();

  static const String appTimeZone = 'Africa/Tunis';
  static const String currencyCode = 'TND';

  /// Format ISO 8601 date in Africa/Tunis for [locale] (fr/en/ar).
  static String formatDate(String? iso, String locale) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return iso ?? '—';
    return DateFormat.yMMMd(_intlLocale(locale)).format(toTunis(d));
  }

  /// Format ISO 8601 date+time in Africa/Tunis for [locale].
  static String formatDateTime(String? iso, String locale) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return iso ?? '—';
    return DateFormat.yMMMd(_intlLocale(locale)).add_Hm().format(toTunis(d));
  }

  /// Single currency helper — never concatenate amounts manually.
  static String formatTND(num? amount, String locale) {
    if (amount == null) return '—';
    final fmt = NumberFormat.currency(
      locale: _intlLocale(locale),
      name: currencyCode,
      symbol: '$currencyCode ',
      decimalDigits: 2,
    );
    return fmt.format(amount);
  }

  /// Shift a UTC instant to Africa/Tunis wall-clock (UTC+1, no DST since 2009).
  static DateTime toTunis(DateTime d) => d.toUtc().add(const Duration(hours: 1));

  /// intl locale name; Arabic keeps Western digits (Latn) per E0.6 decision.
  static String _intlLocale(String locale) {
    final base = locale.toLowerCase().startsWith('ar')
        ? 'ar'
        : locale.toLowerCase().startsWith('en')
            ? 'en'
            : 'fr';
    return base;
  }
}
