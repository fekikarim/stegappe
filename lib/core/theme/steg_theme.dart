import 'package:flutter/material.dart';

import 'steg_colors.dart';
import 'steg_spacing.dart';

/// STEG light/dark themes (UI_UX.md §2–4).
/// Font stack keeps system fonts with broad Arabic coverage; no thin
/// weights; line heights >= 1.4 for Arabic readability.
abstract final class StegTheme {
  static const _fontStack = <String>[
    'Segoe UI',
    'Noto Sans Arabic',
    'Roboto',
    '.SF UI Text',
    'sans-serif',
  ];

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: TextStyle(
            fontSize: 44, height: 1.2, fontWeight: FontWeight.w700,
            color: primary, fontFamilyFallback: _fontStack),
        headlineLarge: TextStyle(
            fontSize: 30, height: 1.25, fontWeight: FontWeight.w700,
            color: primary, fontFamilyFallback: _fontStack),
        titleLarge: TextStyle(
            fontSize: 24, height: 1.35, fontWeight: FontWeight.w700,
            color: primary, fontFamilyFallback: _fontStack),
        titleMedium: TextStyle(
            fontSize: 18, height: 1.4, fontWeight: FontWeight.w600,
            color: primary, fontFamilyFallback: _fontStack),
        bodyLarge: TextStyle(
            fontSize: 16, height: 1.5, fontWeight: FontWeight.w400,
            color: primary, fontFamilyFallback: _fontStack),
        bodyMedium: TextStyle(
            fontSize: 14, height: 1.5, fontWeight: FontWeight.w400,
            color: primary, fontFamilyFallback: _fontStack),
        labelLarge: TextStyle(
            fontSize: 14, height: 1.4, fontWeight: FontWeight.w600,
            color: primary, fontFamilyFallback: _fontStack),
        bodySmall: TextStyle(
            fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w400,
            color: secondary, fontFamilyFallback: _fontStack),
      );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: StegColors.brandPrimary,
      primary: StegColors.brandPrimary,
      error: StegColors.brandRed,
      surface: StegColors.lightSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: StegColors.brandPrimary,
        onPrimary: Colors.white,
        error: StegColors.brandRed,
        surface: StegColors.lightSurface,
      ),
      scaffoldBackgroundColor: StegColors.lightPage,
      textTheme: _textTheme(
          StegColors.lightTextPrimary, StegColors.lightTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: StegColors.brandNavy,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: StegColors.lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          side: const BorderSide(color: StegColors.lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(StegSpacing.radiusSm)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md, vertical: StegSpacing.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StegColors.brandPrimary,
          foregroundColor: Colors.white,
          minimumSize:
              const Size(StegSpacing.minTouchTarget, StegSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StegSpacing.radiusSm)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: StegColors.brandPrimary,
      brightness: Brightness.dark,
      primary: StegColors.primaryBright,
      error: StegColors.brandRed,
      surface: StegColors.darkSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: StegColors.primaryBright,
        error: const Color(0xFFE56A6C),
        surface: StegColors.darkSurface,
      ),
      scaffoldBackgroundColor: StegColors.darkPage,
      textTheme: _textTheme(
          StegColors.darkTextPrimary, StegColors.darkTextSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: StegColors.brandNavy,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: StegColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          side: const BorderSide(color: StegColors.darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(StegSpacing.radiusSm)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md, vertical: StegSpacing.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StegColors.primaryBright,
          foregroundColor: StegColors.brandNavy,
          minimumSize:
              const Size(StegSpacing.minTouchTarget, StegSpacing.minTouchTarget),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StegSpacing.radiusSm)),
        ),
      ),
    );
  }
}
