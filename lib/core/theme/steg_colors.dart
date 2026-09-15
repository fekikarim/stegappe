import 'package:flutter/material.dart';

/// STEG brand + semantic color tokens (UI_UX.md §2).
/// Never use raw hex in widgets — import these tokens.
abstract final class StegColors {
  static const Color brandPrimary = Color(0xFF0B61A0);
  static const Color brandPrimaryDark = Color(0xFF084E82);
  static const Color brandRed = Color(0xFFD32325);
  static const Color brandRedDark = Color(0xFFB02927);
  static const Color brandNavy = Color(0xFF042843);

  // Semantic status colors (always paired with text/icon, never color-only).
  static const Color info = Color(0xFF0B61A0);
  static const Color success = Color(0xFF1B7A3D);
  static const Color warning = Color(0xFF9A6200);
  static const Color error = Color(0xFFD32325);

  // Light surfaces
  static const Color lightPage = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F2437);
  static const Color lightTextSecondary = Color(0xFF47617A);

  // Dark surfaces — deep navy, never pure black (UI_UX.md §3.2).
  static const Color darkPage = Color(0xFF0A1B2A);
  static const Color darkSurface = Color(0xFF10293F);
  static const Color darkElevated = Color(0xFF16334C);
  static const Color darkBorder = Color(0xFF26465F);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFB7C9D8);

  static const Color primaryBright = Color(0xFF3E9BDC);
}
