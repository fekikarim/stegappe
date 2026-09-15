import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_store.dart';
import 'app_localizations.dart';

/// Persisted locale provider. `null` => follow system, defaulting to French.
final prefsStoreProvider = Provider<PrefsStore>(
    (ref) => throw UnimplementedError('Override in main()'));

final localeProvider =
    StateNotifierProvider<LocaleController, Locale?>((ref) {
  final prefs = ref.watch(prefsStoreProvider);
  return LocaleController(prefs);
});

class LocaleController extends StateNotifier<Locale?> {
  LocaleController(this._prefs)
      : super(_prefs.readLocale() == null
            ? null
            : Locale(_prefs.readLocale()!));

  final PrefsStore _prefs;

  Locale effective() => state ?? StegLocales.french;

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await _prefs.saveLocale(locale?.languageCode ?? 'system');
  }
}

enum StegThemeMode { system, light, dark }

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, StegThemeMode>((ref) {
  final prefs = ref.watch(prefsStoreProvider);
  return ThemeModeController(prefs);
});

class ThemeModeController extends StateNotifier<StegThemeMode> {
  ThemeModeController(this._prefs)
      : super(switch (_prefs.readTheme()) {
          'light' => StegThemeMode.light,
          'dark' => StegThemeMode.dark,
          _ => StegThemeMode.system,
        });

  final PrefsStore _prefs;

  ThemeMode get materialMode => switch (state) {
        StegThemeMode.light => ThemeMode.light,
        StegThemeMode.dark => ThemeMode.dark,
        StegThemeMode.system => ThemeMode.system,
      };

  Future<void> setMode(StegThemeMode mode) async {
    state = mode;
    await _prefs.saveTheme(mode.name);
  }
}
