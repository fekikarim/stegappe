import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/theme/steg_motion.dart';
import 'package:stegappe/features/community/presentation/widgets/community_cards.dart';
import 'package:stegappe/features/internship/presentation/widgets/intern_card.dart';
import 'package:stegappe/features/internship/presentation/widgets/task_row.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/shell/presentation/role_shells.dart';

import '../support/shell_harness.dart';
import 'ux_harness.dart';

/// T15 · Phase 5 — performance evidence (measured, not claimed).
///
/// Covers `tasks/T15` required change 5 and acceptance criterion 3:
///  * the two home screens issue **one** data request each and the supervisor
///    lists no longer fan out per intern (T12/T13) — counted on the real
///    repository interface by the harness's counting fake;
///  * the main lists (tasks, feed, conversations) render a viewport out of
///    ~200 items instead of the whole page, with the measured numbers
///    printed for the report;
///  * motion stays within the 250 ms ceiling of `ux-ui.md` §6 and collapses
///    when the platform asks for reduced motion.
void main() {
  UxScreen screen(String id) => uxScreens().firstWhere((s) => s.id == id);

  /// Endpoints whose per-section fan-out T13 removed from the dashboard.
  /// Any of them firing on a screen that reads a single snapshot is a
  /// regression to the pre-T13 behaviour.
  const fanOutEndpoints = [
    'getInternship',
    'getAssignments',
    'listTasks',
    'listJournal',
    'listDeliverables',
    'listEvaluations',
    'listNotifications',
  ];

  group('T15 perf · one request per screen (no N× fan-out)', () {
    testWidgets('intern home issues exactly one data request', (tester) async {
      final pump = await pumpUx(tester, screen('ST-HOME').build());
      final repo = pump.internship;
      expect(repo.calls['internshipSummary'], 1,
          reason: 'the home must read the single summary snapshot');
      for (final endpoint in fanOutEndpoints) {
        expect(repo.calls[endpoint], isNull,
            reason: '$endpoint fired on home → the 13-call fan-out is back');
      }
      expect(repo.sectionCalls, isEmpty,
          reason: 'per-section reads on home: ${repo.sectionCalls}');
      expect(repo.calls['resolveMyInternshipId'], lessThanOrEqualTo(1),
          reason: 'the id must be resolved, not re-fetched per section');
    });

    testWidgets('supervisor home reads the supervised list once',
        (tester) async {
      final pump = await pumpUx(
        tester,
        screen('SU-HOME').build(),
        role: UxRole.supervisor,
      );
      final repo = pump.internship;
      expect(repo.calls['supervisedInterns'], 1,
          reason: 'one endpoint returns every supervised intern with its '
              'progress — no per-intern round trip');
      expect(repo.calls['getInternship'], isNull,
          reason: 'the supervisor home must not fan out per intern');
      expect(repo.sectionCalls, isEmpty,
          reason: 'per-section reads on SU-HOME: ${repo.sectionCalls}');
      expect(pump.layoutOffenders, isEmpty);
    });

    testWidgets('interns list (W12) is one request, not one per row',
        (tester) async {
      final pump = await pumpUx(
        tester,
        screen('W12').build(),
        role: UxRole.supervisor,
      );
      final repo = pump.internship;
      expect(repo.calls['supervisedInterns'], 1);
      expect(repo.calls['getInternship'], isNull,
          reason: 'T12: rows carry backend-sourced progress from the list '
              'endpoint instead of N detail calls');
      expect(repo.sectionCalls, isEmpty,
          reason: 'per-section reads on W12: ${repo.sectionCalls}');
    });

    testWidgets('task management loads one student\'s page, not every '
        'student\'s', (tester) async {
      final pump = await pumpUx(
        tester,
        screen('SU-TASK').build(),
        role: UxRole.supervisor,
      );
      final repo = pump.internship;
      expect(repo.calls['supervisedInterns'], 1);
      expect((repo.calls['listTasks'] ?? 0), lessThanOrEqualTo(1),
          reason: 'tasks are fetched for the selected student only, '
              'got ${repo.calls['listTasks']}');
      expect(repo.calls['getInternship'], isNull,
          reason: 'no per-intern detail fan-out');
    });
  });

  group('T15 perf · 200-item lists build a viewport, not the page', () {
    testWidgets('task list: a 200-row page builds only the viewport',
        (tester) async {
      final sw = Stopwatch()..start();
      final pump = await pumpUx(
        tester,
        screen('ST-TASK').build(),
        internship: UxInternshipRepository(taskCount: 200),
        surface: Size(screen('ST-TASK').wide ? 900 : 400, 800),
      );
      sw.stop();
      // The default board pages task sections (T02); the flat list is the
      // one-Page path (SliverList.builder), so culling is measured there.
      final boardBuilt = find.byType(TaskRow).evaluate().length;
      expect(boardBuilt, greaterThan(0), reason: 'the board must render');
      await tester.tap(find.byIcon(Icons.view_list_outlined));
      await tester.pumpAndSettle();
      final built = find.byType(TaskRow).evaluate().length;
      expect(built, greaterThan(0), reason: 'the list must render');
      expect(built, lessThan(60),
          reason: 'the SliverList must cull off-screen rows: '
              'built $built of 167 visible (200 − cancelled) in '
              '${sw.elapsedMilliseconds} ms of pump');
      expect(pump.layoutOffenders, isEmpty);
      // ignore: avoid_print
      print('T15 perf · ST-TASK 200 tasks → board built $boardBuilt, '
          'flat list built $built rows, pump ${sw.elapsedMilliseconds} ms '
          '(test binding)');
    });

    testWidgets('community feed: only on-screen posts are built',
        (tester) async {
      final sw = Stopwatch()..start();
      final pump = await pumpUx(
        tester,
        screen('ST-COM').build(),
        community: UxCommunityRepository(postCount: 200),
      );
      sw.stop();
      final built = find.byType(CommunityPostCard).evaluate().length;
      expect(built, greaterThan(0), reason: 'the feed must render');
      expect(built, lessThan(200),
          reason: 'built $built of 200 posts in ${sw.elapsedMilliseconds} ms');
      expect(pump.layoutOffenders, isEmpty);
      // ignore: avoid_print
      print('T15 perf · ST-COM 200 posts → $built cards built, '
          '${sw.elapsedMilliseconds} ms');
    });

    testWidgets('conversation list: tree size grows sub-linearly',
        (tester) async {
      Future<int> treeSizeFor(int count) async {
        final messaging = UxMessagingRepository()
          ..convos = [
            for (var i = 0; i < count; i++)
              Conversation(
                id: 'c$i',
                type: ConversationType.private,
                title: 'Conversation numéro $i — un intitulé volontairement '
                    'long pour éprouver la mise en page',
                unreadCount: i % 5,
              ),
          ];
        await pumpUx(tester, screen('ST-MSG-list').build(),
            messaging: messaging);
        return find.byWidgetPredicate((_) => true).evaluate().length;
      }

      final small = await treeSizeFor(40);
      final large = await treeSizeFor(200);
      // A builder-driven list shows a viewport: 5× the data must not build
      // 5× the tree.
      expect(large, lessThan(small * 2),
          reason: 'the conversation list built $large elements for 200 rows '
              'vs $small for 40 — the list is not lazy');
      // ignore: avoid_print
      print('T15 perf · ST-MSG-list tree: $small elements (40 convos) → '
          '$large elements (200 convos)');
    });

    testWidgets('interns list: 200 rows render as cards, lazily',
        (tester) async {
      final sw = Stopwatch()..start();
      final pump = await pumpUx(
        tester,
        screen('W12').build(),
        role: UxRole.supervisor,
        internship: UxInternshipRepository(internCount: 200),
      );
      sw.stop();
      final built = find.byType(InternCard).evaluate().length;
      expect(built, greaterThan(0), reason: 'the list must render');
      expect(built, lessThan(200),
          reason: 'built $built of 200 intern cards in '
              '${sw.elapsedMilliseconds} ms');
      expect(pump.layoutOffenders, isEmpty);
      // ignore: avoid_print
      print('T15 perf · W12 200 interns → $built cards built, '
          '${sw.elapsedMilliseconds} ms');
    });
  });

  group('T15 motion · short transitions that collapse on request', () {
    test('every motion token stays within the 250 ms ceiling', () {
      const ceiling = Duration(milliseconds: 250);
      expect(StegMotion.medium, lessThanOrEqualTo(ceiling),
          reason: 'ux-ui.md §6 caps an in-page transition at 250 ms');
      expect(StegMotion.shell, lessThanOrEqualTo(StegMotion.medium));
      expect(StegMotion.fast, lessThanOrEqualTo(StegMotion.shell));
      expect(StegMotion.instant, lessThanOrEqualTo(StegMotion.fast));
    });

    test('no presentation animation literal exceeds 250 ms', () {
      // Source scan (same style as the RTL API scan): every animation
      // duration written in the presentation layer must fit the ceiling.
      // `Timer(...)` lines are excluded on purpose — debounce/timeouts are
      // not motion.
      final over = <String>[];
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) =>
              f.path.contains('presentation') ||
              f.path.contains('core/widgets') ||
              f.path.contains('core/theme'));
      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final match = RegExp(r'Duration\(milliseconds:\s*(\d+)\)')
              .firstMatch(lines[i]);
          if (match == null) continue;
          final ms = int.parse(match.group(1)!);
          if (ms <= 250) continue;
          if (lines[i].contains('Timer(')) continue;
          over.add('${file.path}:${i + 1} → $ms ms');
        }
      }
      expect(over, isEmpty,
          reason: 'animations must stay ≤ 250 ms (ux-ui.md §6): $over');
    });

    testWidgets('the shell tab switch animates with StegMotion.shell',
        (tester) async {
      await pumpAuthGate(tester, user: kInternUser);
      final switchers = find
          .descendant(
              of: find.byType(InternShell),
              matching: find.byType(AnimatedSwitcher))
          .evaluate();
      expect(switchers, isNotEmpty,
          reason: 'the shell swaps its pages through an AnimatedSwitcher');
      for (final element in switchers) {
        final duration = (element.widget as AnimatedSwitcher).duration;
        expect(duration, lessThanOrEqualTo(StegMotion.medium),
            reason: 'shell transition must stay ≤ 250 ms');
      }
    });

    testWidgets('reduced motion removes the shell transition entirely',
        (tester) async {
      await pumpAuthGate(tester, user: kInternUser, reduceMotion: true);
      expect(find.byType(InternShell), findsOneWidget);
      expect(
        find
            .descendant(
                of: find.byType(InternShell),
                matching: find.byType(AnimatedSwitcher))
            .evaluate(),
        isEmpty,
        reason: 'with disableAnimations the shell swaps pages instantly',
      );
    });

    testWidgets('StegMotion.resolve returns zero under reduce motion',
        (tester) async {
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: SizedBox(),
      ));
      final context = tester.element(find.byType(SizedBox));
      expect(StegMotion.resolve(context, StegMotion.shell), Duration.zero);
    });
  });
}
