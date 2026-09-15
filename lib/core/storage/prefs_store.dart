import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive UI preferences ONLY (locale, theme).
/// Tokens must never pass through here — see [TokenStorage].
class PrefsStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static const kLocale = 'steg.locale.v1'; // 'fr' | 'en' | 'ar' | 'system'
  static const kTheme = 'steg.theme.v1'; // 'light' | 'dark' | 'system'

  static Future<PrefsStore> load() async =>
      PrefsStore(await SharedPreferences.getInstance());

  String? readLocale() => _prefs.getString(kLocale);
  Future<void> saveLocale(String value) => _prefs.setString(kLocale, value);

  String? readTheme() => _prefs.getString(kTheme);
  Future<void> saveTheme(String value) => _prefs.setString(kTheme, value);
}
