import 'package:flutter/material.dart';

/// Spacing / radius / touch-target scale (UI_UX.md §4–5).
/// Touch targets must be >= 44x44 logical px (we use 48 for comfort).
abstract final class StegSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusFull = 999;

  static const double minTouchTarget = 48;

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
}
