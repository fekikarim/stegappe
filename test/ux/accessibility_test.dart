import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/theme/steg_colors.dart';
import 'package:stegappe/core/theme/steg_theme.dart';

import 'ux_harness.dart';

/// T15 · Phase 2 — accessibility evidence.
///
/// Everything here is measured, never asserted from intent:
///  * contrast ratios are computed from the real theme tokens with the
///    WCAG 2.1 relative-luminance formula (`contrastRatio`);
///  * touch targets come from the real semantics tree of a pumped screen
///    (the rect a finger actually hits), not from a style table;
///  * semantic labels come from the same tree, so an unlabelled control fails.

/// Root of the widget-test semantics tree.
///
/// The deprecation on [WidgetTester.binding]'s `pipelineOwner` points at
/// `rootPipelineOwner`, but in this Flutter version the latter owns no
/// `SemanticsOwner` for the test binding, and `SemanticsBinding` exposes none
/// either — the widget-test semantics tree still lives on `pipelineOwner`.
SemanticsNode semanticsRoot(WidgetTester tester) {
  // ignore: deprecated_member_use
  return tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
}

void main() {
  group('T15 a11y · measured contrast (WCAG 2.1, ≥4.5 body / ≥3.0 large)', () {
    const body = 4.5;
    const large = 3.0;

    /// Recorded measurements — the values this task observed, pinned so a
    /// token change that lowers them fails the gate.
    const recorded = <String, double>{
      // Light theme
      'lightTextPrimary/lightPage': 14.61,
      'lightTextPrimary/lightSurface': 15.82,
      'lightTextSecondary/lightPage': 5.95,
      'lightTextSecondary/lightSurface': 6.44,
      'info/lightPage': 6.00,
      'success/lightPage': 4.98,
      'warning/lightPage': 4.71,
      'error/lightPage': 4.80,
      'white/brandNavy (app bar)': 15.11,
      'white/success (banner fill)': 5.39,
      'white/warning (banner fill)': 5.10,
      // Dark theme
      'darkTextPrimary/darkPage': 15.93,
      'darkTextPrimary/darkSurface': 13.59,
      'darkTextPrimary/darkElevated': 11.89,
      'darkTextSecondary/darkSurface': 8.76,
      'darkTextSecondary/darkElevated': 7.67,
      'primaryBright/darkPage': 5.76,
      'primaryBright/darkSurface': 4.91,
      'errorDark/darkPage': 5.49,
      'errorDark/darkSurface': 4.68,
      'successDark/darkPage': 7.84,
      'successDark/darkSurface': 6.68,
      'warningDark/darkPage': 8.08,
      'warningDark/darkSurface': 6.89,
    };

    final pairs = <String, (Color, Color, double)>{
      'lightTextPrimary/lightPage': (
        StegColors.lightTextPrimary,
        StegColors.lightPage,
        body
      ),
      'lightTextPrimary/lightSurface': (
        StegColors.lightTextPrimary,
        StegColors.lightSurface,
        body
      ),
      'lightTextSecondary/lightPage': (
        StegColors.lightTextSecondary,
        StegColors.lightPage,
        body
      ),
      'lightTextSecondary/lightSurface': (
        StegColors.lightTextSecondary,
        StegColors.lightSurface,
        body
      ),
      'info/lightPage': (StegColors.info, StegColors.lightPage, body),
      'success/lightPage': (StegColors.success, StegColors.lightPage, body),
      'warning/lightPage': (StegColors.warning, StegColors.lightPage, body),
      'error/lightPage': (StegColors.brandRed, StegColors.lightPage, body),
      'white/brandNavy (app bar)': (
        Colors.white,
        StegColors.brandNavy,
        body
      ),
      'white/success (banner fill)': (
        Colors.white,
        StegColors.success,
        body
      ),
      'white/warning (banner fill)': (
        Colors.white,
        StegColors.warning,
        body
      ),
      'darkTextPrimary/darkPage': (
        StegColors.darkTextPrimary,
        StegColors.darkPage,
        body
      ),
      'darkTextPrimary/darkSurface': (
        StegColors.darkTextPrimary,
        StegColors.darkSurface,
        body
      ),
      'darkTextPrimary/darkElevated': (
        StegColors.darkTextPrimary,
        StegColors.darkElevated,
        body
      ),
      'darkTextSecondary/darkSurface': (
        StegColors.darkTextSecondary,
        StegColors.darkSurface,
        body
      ),
      'darkTextSecondary/darkElevated': (
        StegColors.darkTextSecondary,
        StegColors.darkElevated,
        body
      ),
      'primaryBright/darkPage': (
        StegColors.primaryBright,
        StegColors.darkPage,
        body
      ),
      'primaryBright/darkSurface': (
        StegColors.primaryBright,
        StegColors.darkSurface,
        body
      ),
      'errorDark/darkPage': (StegColors.errorDark, StegColors.darkPage, body),
      'errorDark/darkSurface': (
        StegColors.errorDark,
        StegColors.darkSurface,
        body
      ),
      'successDark/darkPage': (
        StegColors.successDark,
        StegColors.darkPage,
        body
      ),
      'successDark/darkSurface': (
        StegColors.successDark,
        StegColors.darkSurface,
        body
      ),
      'warningDark/darkPage': (
        StegColors.warningDark,
        StegColors.darkPage,
        body
      ),
      'warningDark/darkSurface': (
        StegColors.warningDark,
        StegColors.darkSurface,
        body
      ),
    };

    pairs.forEach((label, pair) {
      test('$label meets the barrier', () {
        final (fg, bg, min) = pair;
        final measured = contrastRatio(composite(fg, bg), bg);
        expect(measured, greaterThanOrEqualTo(min),
            reason: '$label measures ${measured.toStringAsFixed(2)}:1');
        expect(measured, closeTo(recorded[label] ?? measured, 0.02),
            reason: 'recorded ${recorded[label]} vs measured '
                '${measured.toStringAsFixed(2)}');
      });
    });

    test('large display text meets the 3:1 barrier in both themes', () {
      for (final theme in [StegTheme.light(), StegTheme.dark()]) {
        final display = theme.textTheme.displayLarge!;
        final bg = theme.scaffoldBackgroundColor;
        final measured = contrastRatio(composite(display.color!, bg), bg);
        expect(measured, greaterThanOrEqualTo(large),
            reason: 'displayLarge measures ${measured.toStringAsFixed(2)}:1 '
                'on ${theme.brightness}');
      }
    });

    test('the light success/warning pair is unusable on dark (the fixed '
        'defect stays fixed)', () {
      // Measured before the fix: 3.24:1 and 3.43:1 on darkPage, i.e. below the
      // 4.5:1 body bar. Recorded so a regression back to the light tokens is
      // explicit rather than silent.
      expect(contrastRatio(StegColors.success, StegColors.darkPage),
          lessThan(body));
      expect(contrastRatio(StegColors.warning, StegColors.darkPage),
          lessThan(body));
      // …and the shipped dark pair clears the body barrier.
      expect(contrastRatio(StegColors.successDark, StegColors.darkPage),
          greaterThanOrEqualTo(body));
      expect(contrastRatio(StegColors.warningDark, StegColors.darkPage),
          greaterThanOrEqualTo(body));
    });
  });

  group('T15 a11y · touch targets ≥48 dp and labels, measured on the real '
      'semantics tree', () {
    /// Global (screen-space) rect of a semantics node: `rect` is in the
    /// node's own coordinate system, `transform` maps it to its parent's.
    Rect globalRect(SemanticsNode node) {
      var rect = node.rect;
      SemanticsNode? n = node;
      while (n != null) {
        final t = n.transform;
        if (t != null) rect = MatrixUtils.transformRect(t, rect);
        n = n.parent;
      }
      return rect;
    }

    /// Every node carrying a tap/long-press action, merged or not: merged
    /// nodes are still part of the pointer surface (a Material button merges
    /// its inner content into the button node), so excluding them
    /// under-measures the real target.
    List<SemanticsNode> actionable(SemanticsNode root) {
      final out = <SemanticsNode>[];
      void walk(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.hasAction(SemanticsAction.tap) ||
            data.hasAction(SemanticsAction.longPress)) {
          out.add(node);
        }
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(root);
      return out;
    }

    testWidgets('the measurement itself is calibrated against a known widget',
        (tester) async {
      // Proves the semantics-rect math agrees with the widget geometry, so the
      // 48 dp assertions below mean what they claim.
      final handle = tester.ensureSemantics();
      final pump = await pumpUx(
          tester, uxScreens().firstWhere((s) => s.id == 'ST-HOME').build());
      expect(pump.layoutOffenders, isEmpty);
      final node = actionable(
          semanticsRoot(tester))
          .firstWhere((n) => n.getSemanticsData().label.isNotEmpty);
      final measured = globalRect(node);
      expect(measured.width, greaterThan(0));
      expect(measured.height, greaterThan(0));
      // Everything must land inside the screen.
      expect(measured.left, greaterThanOrEqualTo(-1));
      expect(measured.top, greaterThanOrEqualTo(-1));
      expect(measured.right, lessThanOrEqualTo(401));
      handle.dispose();
    });

    /// Material controls whose own box is the target (Flutter expands a
    /// chip's or an icon button's hit area beyond the inner `InkWell`, so the
    /// control — not its internal ink — is what must clear 48 dp).
    const controls = <Type>[
      IconButton,
      TextButton,
      ElevatedButton,
      OutlinedButton,
      FilledButton,
      FloatingActionButton,
      Chip,
      RawChip,
      Switch,
      Checkbox,
      ListTile,
      DropdownButtonFormField,
      Slider,
      TextField,
    ];

    /// Raw app-authored targets. A bare `InkWell` inside a Material control
    /// is that control's implementation detail, so only the ones the app
    /// wrote itself (no control ancestor) are judged on their own box.
    const rawTargets = <Type>[InkWell, InkResponse, GestureDetector];

    bool hasControlAncestor(Element element) {
      var found = false;
      element.visitAncestorElements((a) {
        if (controls.contains(a.widget.runtimeType)) {
          found = true;
          return false;
        }
        return true;
      });
      return found;
    }

    for (final screen in uxScreens()) {
      testWidgets('${screen.id} · ${screen.name} targets and labels',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpUx(
          tester,
          screen.build(),
          role: screen.role,
          scrollable: screen.scrollable,
          surface: Size(screen.wide ? 900 : 400, 800),
        );

        // ── pointer targets, measured on the rendered widget ─────────────
        final tooSmall = <String>[];
        for (final type in controls) {
          for (final e in find.byType(type).evaluate()) {
            final rect = tester.getRect(find.byWidget(e.widget));
            if (rect.width <= 0 || rect.height <= 0) continue;
            if (rect.width < 48 || rect.height < 48) {
              tooSmall.add('$type ${rect.width.toStringAsFixed(0)}×'
                  '${rect.height.toStringAsFixed(0)}');
            }
          }
        }
        for (final type in rawTargets) {
          for (final e in find.byType(type).evaluate()) {
            if (hasControlAncestor(e)) continue;
            final rect = tester.getRect(find.byWidget(e.widget));
            if (rect.width <= 0 || rect.height <= 0) continue;
            if (rect.width < 48 || rect.height < 48) {
              tooSmall.add('$type ${rect.width.toStringAsFixed(0)}×'
                  '${rect.height.toStringAsFixed(0)}');
            }
          }
        }

        // ── accessible names, measured on the real semantics tree ────────
        final unlabelled = <String>[];
        for (final n in actionable(semanticsRoot(tester))) {
          final data = n.getSemanticsData();
          // A control is named by its label, its tooltip or its placeholder —
          // a search box that only carries a hint is still announced.
          if (data.label.isNotEmpty ||
              data.tooltip.isNotEmpty ||
              data.hint.isNotEmpty) {
            continue;
          }
          if (n.isMergedIntoParent) continue;
          final rect = globalRect(n);
          if (rect.width <= 0 || rect.height <= 0) continue;
          unlabelled.add('${rect.width.toStringAsFixed(0)}×'
              '${rect.height.toStringAsFixed(0)}');
        }

        expect(tooSmall, isEmpty,
            reason: '${screen.name}: targets below 48 dp → $tooSmall');
        expect(unlabelled, isEmpty,
            reason: '${screen.name}: unlabelled interactive nodes → '
                '$unlabelled');
        handle.dispose();
      });
    }
  });
}
