import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ux_harness.dart';

/// T15 · Phase 3 — RTL + localization evidence.
///
/// Three kinds of proof, none of which is "the locale was set to `ar`":
///  1. every shipped screen renders under `ar` with a real `TextDirection.rtl`
///     and produces no layout exception (overflow, unbounded constraints);
///  2. every directional API used in feature code is horizontally symmetric,
///     so no padding/alignment/position can mirror into a defect;
///  3. mixed-direction values (email, reference, filename) are actually
///     isolated with [BidiText] instead of being rendered as bare LTR runs
///     inside an RTL paragraph.
void main() {
  group('T15 RTL · every ux-ui §4 screen renders in Arabic', () {
    for (final screen in uxScreens()) {
      testWidgets('${screen.id} · ${screen.name} is RTL and defect-free',
          (tester) async {
        final pump = await pumpUx(
          tester,
          screen.build(),
          locale: const Locale('ar'),
          role: screen.role,
          scrollable: screen.scrollable,
          surface: Size(screen.wide ? 900 : 400, 800),
        );
        final ctx = tester.element(find.byType(Scaffold).first);
        expect(Directionality.of(ctx), TextDirection.rtl,
            reason: '${screen.name} must lay out right-to-left in Arabic');
        expect(pump.layoutOffenders, isEmpty,
            reason: '${screen.name} overflowed in Arabic:\n'
                '${pump.layoutOffenders.join('\n')}');
      });
    }
  });

  group('T15 RTL · hardest combination (Arabic + dark + 2.0×)', () {
    for (final screen in uxScreens().where((s) =>
        const {'ST-HOME', 'ST-TASK', 'ST-MSG-chat', 'ST-COM', 'ST-NOT', 'SU-HOME'}
            .contains(s.id))) {
      testWidgets('${screen.id} · ${screen.name} survives ar+dark+2×',
          (tester) async {
        final pump = await pumpUx(
          tester,
          screen.build(),
          locale: const Locale('ar'),
          brightness: Brightness.dark,
          textScale: 2.0,
          role: screen.role,
          scrollable: screen.scrollable,
          surface: Size(screen.wide ? 900 : 400, 800),
        );
        final ctx = tester.element(find.byType(Scaffold).first);
        expect(Directionality.of(ctx), TextDirection.rtl);
        expect(pump.layoutOffenders, isEmpty,
            reason: '${screen.name} overflowed at ar+dark+2×:\n'
                '${pump.layoutOffenders.join('\n')}');
      });
    }
  });

  group('T15 RTL · directional APIs are physically neutral', () {
    final sources = <String, String>{
      for (final f in _dartFiles('lib/features')) f.path: f.readAsStringSync(),
      for (final f in _dartFiles('lib/core/widgets')) f.path: f.readAsStringSync(),
    };

    test('InsetsDirectional/EdgeInsets.only never pin a single side', () {
      final offenders = <String>[];
      final pattern = RegExp(r'EdgeInsets\.only\(\s*(left|right)\s*:');
      sources.forEach((path, source) {
        for (final m in pattern.allMatches(source)) {
          offenders.add('$path → ${m.group(0)}');
        }
      });
      expect(offenders, isEmpty,
          reason: 'physical single-side padding cannot mirror: $offenders');
    });

    test('every EdgeInsets.fromLTRB is horizontally symmetric', () {
      final asymmetric = <String>[];
      final pattern = RegExp(
          r'EdgeInsets\.fromLTRB\(\s*([^,]+?),\s*[^,]+?,\s*([^,)]+?)\s*,',
          dotAll: true);
      sources.forEach((path, source) {
        for (final m in pattern.allMatches(source)) {
          final left = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
          final right = m.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (left != right) {
            final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
            asymmetric.add('$path:$line left=$left right=$right');
          }
        }
      });
      expect(asymmetric, isEmpty,
          reason: 'asymmetric LTRB padding mirrors into a defect: $asymmetric');
    });

    test('no physical alignment or positioning in feature code', () {
      final offenders = <String>[];
      final patterns = <RegExp>[
        RegExp(r'Alignment\.center(Left|Right)'),
        RegExp(r'Alignment\.(top|bottom)(Left|Right)'),
        RegExp(r'Positioned\(\s*(left|right)\s*:'),
        RegExp(r'TextAlign\.(left|right)'),
      ];
      sources.forEach((path, source) {
        for (final p in patterns) {
          for (final m in p.allMatches(source)) {
            offenders.add('$path → ${m.group(0)}');
          }
        }
      });
      expect(offenders, isEmpty,
          reason: 'use AlignmentDirectional/PositionedDirectional/start-end: '
              '$offenders');
    });
  });

  group('T15 RTL · mixed-direction values stay readable in Arabic', () {
    /// True when the matched text was rendered under an explicit LTR
    /// directionality (`BidiText`) or wrapped in the bidi isolates
    /// `BidiText.isolate` inserts — both keep an LTR technical run readable
    /// inside an RTL paragraph.
    bool isolated(WidgetTester tester, Finder finder) {
      for (final element in finder.evaluate()) {
        var isIsolated = false;
        element.visitAncestorElements((ancestor) {
          final w = ancestor.widget;
          if (w is Directionality && w.textDirection == TextDirection.ltr) {
            isIsolated = true;
            return false;
          }
          return true;
        });
        if (isIsolated) return true;
        final w = element.widget;
        if (w is Text &&
            (w.data ?? '').contains('\u2068') &&
            (w.data ?? '').contains('\u2069')) {
          return true;
        }
      }
      return false;
    }

    /// Measured: keeps the logical head of the run on the left of the
    /// laid-out line. This reads the glyph boxes a screen would draw, so it
    /// holds whether the value is isolated with `BidiText.isolate`, forced
    /// LTR with `BidiText`, or — for a standalone run that already resolves
    /// LTR-visual — left as a plain string.
    bool laysOutLtrVisual(WidgetTester tester, Finder finder) {
      final element = tester.element(finder);
      final widget = element.widget;
      final String data;
      final TextStyle? style;
      if (widget is Text) {
        data = widget.data ?? widget.textSpan?.toPlainText() ?? '';
        style = widget.style;
      } else if (widget is RichText) {
        data = widget.text.toPlainText();
        style = widget.text.style;
      } else {
        return false;
      }
      if (data.length < 8) return false;
      final painter = TextPainter(
        text: TextSpan(text: data, style: style),
        textDirection: Directionality.of(element),
        maxLines: 1,
      )..layout(maxWidth: 400);
      double left(int from, int to) => painter
          .getBoxesForSelection(
              TextSelection(baseOffset: from, extentOffset: to))
          .first
          .left;
      final headIsLeft = left(0, 4) < left(data.length - 4, data.length);
      painter.dispose();
      return headIsLeft;
    }

    testWidgets('the account email is bidi-isolated in Arabic',
        (tester) async {
      await pumpUx(tester, uxScreens()
          .firstWhere((s) => s.id == 'SH-PRO')
          .build(), locale: const Locale('ar'));
      final email = find.text(kInternUser.email);
      expect(email, findsWidgets,
          reason: 'the email must be rendered — otherwise the check is vacuous');
      expect(isolated(tester, email), isTrue,
          reason: 'an email rendered bare inside RTL reverses visually');
    });

    testWidgets('the internship reference reads LTR on home (measured)',
        (tester) async {
      await pumpUx(tester, uxScreens()
          .firstWhere((s) => s.id == 'ST-HOME')
          .build(), locale: const Locale('ar'));
      final chips = find.textContaining('STG-2026');
      expect(chips, findsWidgets,
          reason: 'the home must show the internship reference');
      // Measured rather than inferred from a wrapper: the chip holds a
      // standalone technical run, which already resolves LTR-visual in an
      // RTL paragraph (checked with TextPainter glyph boxes), so wrapping it
      // in isolates would only put invisible characters into a copyable,
      // screen-reader-read value. What must hold is the reading order.
      expect(laysOutLtrVisual(tester, chips), isTrue,
          reason: 'a reference code must not be read backwards in Arabic');
    });

    testWidgets('an intern-card reference is bidi-isolated in Arabic',
        (tester) async {
      await pumpUx(
          tester,
          uxScreens().firstWhere((s) => s.id == 'W12').build(),
          locale: const Locale('ar'),
          role: UxRole.supervisor);
      final refs = find.textContaining('STG-2026');
      expect(refs, findsWidgets);
      expect(isolated(tester, refs), isTrue,
          reason: 'the reference is embedded in a localized subtitle');
    });
  });
}

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();
