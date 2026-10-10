import 'package:flutter/material.dart';

import 'steg_colors.dart';
import 'steg_spacing.dart';

/// STEG light/dark themes (UI_UX.md §2–4) — modern 2026 refresh.
///
/// Expressive M3: larger radii, soft layered shadows, filled inputs,
/// gradient-friendly surfaces, pill navigation bar, modern sheets/dialogs.
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
            fontSize: 44, height: 1.2, fontWeight: FontWeight.w800,
            color: primary, fontFamilyFallback: _fontStack, letterSpacing: -0.5),
        headlineLarge: TextStyle(
            fontSize: 30, height: 1.25, fontWeight: FontWeight.w800,
            color: primary, fontFamilyFallback: _fontStack, letterSpacing: -0.3),
        titleLarge: TextStyle(
            fontSize: 24, height: 1.35, fontWeight: FontWeight.w700,
            color: primary, fontFamilyFallback: _fontStack),
        titleMedium: TextStyle(
            fontSize: 18, height: 1.4, fontWeight: FontWeight.w700,
            color: primary, fontFamilyFallback: _fontStack),
        bodyLarge: TextStyle(
            fontSize: 16, height: 1.5, fontWeight: FontWeight.w400,
            color: primary, fontFamilyFallback: _fontStack),
        bodyMedium: TextStyle(
            fontSize: 14, height: 1.5, fontWeight: FontWeight.w400,
            color: primary, fontFamilyFallback: _fontStack),
        labelLarge: TextStyle(
            fontSize: 14, height: 1.4, fontWeight: FontWeight.w700,
            color: primary, fontFamilyFallback: _fontStack),
        bodySmall: TextStyle(
            fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w400,
            color: secondary, fontFamilyFallback: _fontStack),
      );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: StegColors.brandPrimary,
      primary: StegColors.brandPrimary,
      secondary: StegColors.communityAccent,
      tertiary: StegColors.aiAccent,
      error: StegColors.brandRed,
      surface: StegColors.lightSurface,
    );
    final textTheme =
        _textTheme(StegColors.lightTextPrimary, StegColors.lightTextSecondary);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: StegColors.brandPrimary,
        onPrimary: Colors.white,
        secondary: StegColors.communityAccent,
        tertiary: StegColors.aiAccent,
        error: StegColors.brandRed,
        surface: StegColors.lightSurface,
        surfaceContainerHighest: const Color(0xFFEBEFF4),
      ),
      scaffoldBackgroundColor: StegColors.lightPage,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: StegColors.brandNavy,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: StegColors.lightSurface,
        elevation: 2,
        shadowColor: StegColors.shadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          side: const BorderSide(color: StegColors.lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        hintStyle: const TextStyle(color: StegColors.lightTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          borderSide: const BorderSide(color: StegColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          borderSide:
              const BorderSide(color: StegColors.brandPrimary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          borderSide: const BorderSide(color: StegColors.brandRed),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md, vertical: StegSpacing.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StegColors.brandPrimary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: StegColors.brandPrimary.withValues(alpha: 0.4),
          minimumSize:
              const Size(StegSpacing.minTouchTarget, StegSpacing.minTouchTarget),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StegSpacing.radiusMd)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StegColors.brandPrimary,
          minimumSize:
              const Size(StegSpacing.minTouchTarget, StegSpacing.minTouchTarget),
          side: const BorderSide(color: StegColors.lightBorder, width: 1.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StegSpacing.radiusMd)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: StegColors.brandPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StegSpacing.radiusSm)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: StegColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: StegColors.lightSurface,
        indicatorColor:
            StegColors.brandPrimary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: StegColors.lightTextPrimary,
              fontFamilyFallback: _fontStack),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StegSpacing.radiusFull)),
        side: const BorderSide(color: StegColors.lightBorder),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      dividerTheme: const DividerThemeData(
        color: StegColors.lightBorder,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: StegColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: StegColors.lightSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: StegColors.brandNavy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: StegColors.brandPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.white
                : StegColors.lightTextSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? StegColors.brandPrimary
                : const Color(0xFFE2E8F0)),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: StegColors.brandPrimary,
      brightness: Brightness.dark,
      primary: StegColors.primaryBright,
      secondary: StegColors.communityAccentDark,
      tertiary: StegColors.aiAccentDark,
      error: StegColors.brandRed,
      surface: StegColors.darkSurface,
    );
    final textTheme =
        _textTheme(StegColors.darkTextPrimary, StegColors.darkTextSecondary);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: StegColors.primaryBright,
        onPrimary: StegColors.brandNavy,
        secondary: StegColors.communityAccentDark,
        tertiary: StegColors.aiAccentDark,
        error: StegColors.errorDark,
        surface: StegColors.darkSurface,
        surfaceContainerHighest: StegColors.darkElevated,
      ),
      scaffoldBackgroundColor: StegColors.darkPage,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: StegColors.brandNavy,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: StegColors.darkSurface,
        elevation: 0,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          side: const BorderSide(color: StegColors.darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StegColors.darkElevated,
        hintStyle: const TextStyle(color: StegColors.darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          borderSide: const BorderSide(color: StegColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
          borderSide:
              const BorderSide(color: StegColors.primaryBright, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: StegSpacing.md, vertical: StegSpacing.sm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StegColors.primaryBright,
          foregroundColor: StegColors.brandNavy,
          elevation: 4,
          minimumSize:
              const Size(StegSpacing.minTouchTarget, StegSpacing.minTouchTarget),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StegSpacing.radiusMd)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StegColors.darkTextPrimary,
          minimumSize:
              const Size(StegSpacing.minTouchTarget, StegSpacing.minTouchTarget),
          side: const BorderSide(color: StegColors.darkBorder, width: 1.4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StegSpacing.radiusMd)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: StegColors.primaryBright,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(StegSpacing.radiusSm)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: StegColors.primaryBright,
        foregroundColor: StegColors.brandNavy,
        elevation: 6,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: StegColors.darkSurface,
        indicatorColor:
            StegColors.primaryBright.withValues(alpha: 0.22),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: StegColors.darkTextPrimary,
              fontFamilyFallback: _fontStack),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StegSpacing.radiusFull)),
        side: const BorderSide(color: StegColors.darkBorder),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      dividerTheme: const DividerThemeData(
        color: StegColors.darkBorder,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: StegColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: StegColors.darkSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: StegColors.darkElevated,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: StegColors.primaryBright,
      ),
    );
  }
}
