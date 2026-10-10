import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/settings_providers.dart';
import '../../../../core/storage/prefs_store.dart';
import '../../../../core/theme/steg_colors.dart';

/// The internship period highlight on the journal calendar (STEG-JRN).
///
/// The period is the spine of the journal experience: every day the student
/// was on site is the frame around his work. It is therefore rendered as a
/// clearly visible band rather than a hairline, and the accent is a **stored
/// preference** so the student can make the calendar feel like his own.
///
/// This enum is the single source of truth for the palette: [accent] is the
/// only place a color is resolved, so adding a theme later (or letting the
/// student pick more colours) never touches the calendar widget.
enum JournalAccent { brand, violet, teal, amber, emerald }

extension JournalAccentColors on JournalAccent {
  /// Base colour of the period band.
  Color get seed => switch (this) {
        JournalAccent.brand => StegColors.brandPrimary,
        JournalAccent.violet => const Color(0xFF7C3AED),
        JournalAccent.teal => const Color(0xFF0E7490),
        JournalAccent.amber => const Color(0xFFC77700),
        JournalAccent.emerald => const Color(0xFF1B7A3D),
      };

  /// Lighter partner used for the band's gradient.
  Color get tint => switch (this) {
        JournalAccent.brand => StegColors.primaryBright,
        JournalAccent.violet => const Color(0xFFA78BFA),
        JournalAccent.teal => const Color(0xFF4FB3C9),
        JournalAccent.amber => const Color(0xFFFFB74D),
        JournalAccent.emerald => const Color(0xFF4CC46E),
      };

  String get storageKey => name;

  static JournalAccent fromKey(String? key) => JournalAccent.values
      .firstWhere((a) => a.name == key, orElse: () => JournalAccent.brand);
}

const String kJournalAccentPrefsKey = 'steg.journal.accent.v1';

/// Persisted personalisation of the journal calendar (device-local: it is a
/// display preference, never account data).
final journalAccentProvider =
    StateNotifierProvider<JournalAccentController, JournalAccent>((ref) {
  // The prefs store is a device preference service that is only installed
  // once the app boots. A missing store degrades to an in-memory choice
  // instead of taking the journal screen down with it.
  PrefsStore? prefs;
  try {
    prefs = ref.watch(prefsStoreProvider);
  } on UnimplementedError {
    prefs = null;
  }
  return JournalAccentController(prefs);
});

class JournalAccentController extends StateNotifier<JournalAccent> {
  JournalAccentController(this._prefs)
      : super(JournalAccentColors.fromKey(_prefs?.readRaw(kJournalAccentPrefsKey)));

  final PrefsStore? _prefs;

  Future<void> set(JournalAccent accent) async {
    if (accent == state) return;
    state = accent;
    await _prefs?.writeRaw(kJournalAccentPrefsKey, accent.storageKey);
  }
}

/// Resolved palette for one accent in the current theme.
@immutable
class JournalPalette {
  const JournalPalette({
    required this.seed,
    required this.tint,
    required this.isDark,
  });

  factory JournalPalette.of(JournalAccent accent, Brightness brightness) =>
      JournalPalette(
        seed: accent.seed,
        tint: accent.tint,
        isDark: brightness == Brightness.dark,
      );

  final Color seed;
  final Color tint;
  final bool isDark;

  /// Day fill inside the period. Strong enough to be noticed at a glance in
  /// both themes, never so strong that the day number loses contrast — the
  /// label always carries the meaning, the colour only supports it (§2.3).
  Color get dayFill => isDark
      ? Color.alphaBlend(seed.withValues(alpha: 0.26), const Color(0xFF10293F))
      : Color.alphaBlend(seed.withValues(alpha: 0.13), Colors.white);

  Color get dayBorder => seed.withValues(alpha: isDark ? 0.45 : 0.28);

  /// Days outside the period recede but stay readable.
  Color get outsideFill => isDark
      ? const Color(0xFF0E2233).withValues(alpha: 0.55)
      : const Color(0xFFEDF1F5);

  List<Color> get legendGradient => [seed, tint];
}