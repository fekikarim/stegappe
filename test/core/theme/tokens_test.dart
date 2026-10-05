import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/theme/steg_colors.dart';
import 'package:stegappe/core/theme/steg_theme.dart';

/// T00 · acceptance criterion 4 — the new tokens exist in `core/theme`,
/// stay distinct, and remain tellable apart without colour.
void main() {
  group('calendar period palette (T12)', () {
    test('has at least six colours', () {
      expect(StegColors.calendarPalette.length, greaterThanOrEqualTo(6));
    });

    test('every colour is distinct', () {
      expect(StegColors.calendarPalette.toSet().length,
          StegColors.calendarPalette.length);
    });

    test('the periods are distinguishable in greyscale', () {
      final lums =
          StegColors.calendarPalette.map(StegColors.greyscaleLuminance).toList();
      for (var i = 0; i < lums.length; i++) {
        for (var j = i + 1; j < lums.length; j++) {
          expect((lums[i] - lums[j]).abs(), greaterThanOrEqualTo(15.0),
              reason: 'palette[$i] and palette[$j] are too close in '
                  'greyscale (${lums[i]} vs ${lums[j]})');
        }
      }
    });

    test('calendarColorFor maps, wraps, and never throws', () {
      expect(StegColors.calendarColorFor(0), StegColors.calendarPalette[0]);
      expect(StegColors.calendarColorFor(StegColors.calendarPalette.length),
          StegColors.calendarPalette[0]);
      expect(() => StegColors.calendarColorFor(1 << 20), returnsNormally);
    });

    test('no palette entry collides with a page/surface token', () {
      for (final c in StegColors.calendarPalette) {
        expect(c, isNot(StegColors.lightPage));
        expect(c, isNot(StegColors.lightSurface));
        expect(c, isNot(StegColors.darkSurface));
      }
    });
  });

  group('new semantic tokens (scheduled / awaiting approval / AI / community)',
      () {
    test('all exist and are pairwise distinct (light and dark variants)', () {
      final tokens = <Color>[
        StegColors.scheduledTask,
        StegColors.scheduledTaskDark,
        StegColors.awaitingApproval,
        StegColors.awaitingApprovalDark,
        StegColors.aiAccent,
        StegColors.aiAccentDark,
        StegColors.communityAccent,
        StegColors.communityAccentDark,
      ];
      expect(tokens.toSet().length, tokens.length,
          reason: 'each new token must be a distinct value');
    });

    test('are distinct from the pre-existing semantic tokens', () {
      final existing = <Color>[
        StegColors.info,
        StegColors.success,
        StegColors.warning,
        StegColors.error,
        StegColors.brandPrimary,
        StegColors.brandRed,
        StegColors.brandNavy,
      ];
      for (final token in <Color>[
        StegColors.scheduledTask,
        StegColors.awaitingApproval,
        StegColors.aiAccent,
        StegColors.communityAccent,
      ]) {
        expect(existing.contains(token), isFalse,
            reason: 'a new token must not reuse an existing semantic colour');
      }
    });

    test('the greyscale helper is deterministic and ordered', () {
      expect(
        StegColors.greyscaleLuminance(StegColors.brandNavy),
        lessThan(StegColors.greyscaleLuminance(StegColors.lightSurface)),
      );
      expect(
        StegColors.greyscaleLuminance(StegColors.brandNavy),
        StegColors.greyscaleLuminance(StegColors.brandNavy),
      );
    });
  });

  group('both themes build with the new tokens', () {
    test('light and dark ThemeData construct', () {
      expect(StegTheme.light().brightness, Brightness.light);
      expect(StegTheme.dark().brightness, Brightness.dark);
    });
  });
}
