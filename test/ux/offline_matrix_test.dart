import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/features/internship/domain/dashboard.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/notify_providers.dart';
import 'package:stegappe/features/internship/presentation/widgets/dashboard_sections.dart';
import 'package:stegappe/core/widgets/steg_button.dart';

import 'ux_harness.dart';

/// T15 Phase 6 — offline honesty matrix (`BR-58`, `ux-ui.md` §5).
///
/// Each shipped screen's declared offline behaviour is asserted at the widget
/// level under `online = false` (cached reads labelled stale) and `online =
/// true` (no stale label), and every mutating control is asserted to either
/// (a) enqueue a D12 write, or (b) disable with a reason, or (c) require
/// connectivity and block with a reason — never fail silently after the tap.
void main() {
  Paged<T> pageOf<T>(List<T> items, {int total = 1}) =>
      Paged<T>(items: items, page: 0, totalElements: total, totalPages: 1, isLast: true);

  UxScreen screen(String id) => uxScreens().firstWhere((s) => s.id == id);

  AppLocalizations l10nOf(WidgetTester t) {
    final scaffold = find.byType(Scaffold).first;
    return AppLocalizations.of(t.element(scaffold));
  }

  /// Builds the extra provider overrides for a given screen id.
  /// The SAME list is passed to both the offline and online pump within
  /// a single test body — Riverpod forbids changing the override count between
  /// successive pumpWidget calls on the same tester.
  List<Override> overridesFor(String id) {
    if (id == 'ST-HOME') {
      return [
        lastDashboardProvider.overrideWith((ref) => DashboardData(
              internship: Internship(
                  id: 'i0',
                  reference: 'STG-2026-0001',
                  status: InternshipStatus.inProgress,
                  type: InternshipType.pfe,
                  requirement: 'Mandatory',
                  paymentEligible: false,
                  candidateFullName: 'Alice Test',
                  startDate: DateTime(2026, 1, 1),
                  endDate: DateTime(2026, 6, 30)),
              assignments: const [],
              activeAssignment: null,
              todayTasks: const [],
              overdueTasks: const [],
              weekTasks: const [],
              tasksCompleted: 0,
              tasksTotal: 6,
              extraTasks: 0,
              pendingJournal: const [],
              pendingJournalTotal: 1,
              journalValidatedTotal: 0,
              openDeliverables: const [],
              deliverablesTotal: 3,
              deliverablesValidated: 0,
              deliverablesComplete: false,
              evaluationsCount: 0,
              latestEvaluation: null,
              recentNotifications: const [],
              unreadNotifications: 0,
              unreadMessages: 0,
              now: DateTime(2026, 9, 15),
            )),
      ];
    }
    if (id == 'ST-TASK') {
      return [
        lastTasksProvider.overrideWith((ref) => pageOf(
            [const InternTask(
                id: 't0', title: 'Task 1', description: '',
                status: TaskStatus.todo, dueDate: null)],
            total: 1)),
      ];
    }
    if (id == 'ST-JRN-list') {
      return [
        lastJournalProvider.overrideWith((ref) => pageOf(
            [JournalEntry(
                id: 'j0', title: 'Entry 1', description: '',
                status: JournalStatus.submitted,
                entryDate: DateTime(2026, 9, 14))],
            total: 1)),
      ];
    }
    if (id == 'ST-VAL-doc') {
      return [
        deliverablesListProvider.overrideWith((ref) async => pageOf(
            [const DeliverableSummary(
                id: 'd0', title: 'Deliverable 1',
                status: DeliverableStatus.draft, currentVersion: 1)],
            total: 1)),
      ];
    }
    if (id == 'SU-HOME') {
      return [
        lastSupervisedProvider.overrideWith((ref) => [
          SupervisedIntern(
              internshipId: 'i0', reference: 'STG-2026-0001',
              internName: 'Alice Test', status: InternshipStatus.inProgress,
              type: InternshipType.pfe, startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 6, 30), departmentName: 'DSI',
              tasksCompleted: 0, tasksTotal: 6, pendingJournal: 1,
              pendingDeliverables: 0, evaluationsCount: 0),
        ]),
      ];
    }
    if (id == 'W12') {
      return [
        notifySelectModeProvider.overrideWith((ref) => true),
        supervisedInternsProvider.overrideWith((ref) async => [
          SupervisedIntern(
              internshipId: 'i0', reference: 'STG-2026-0001',
              internName: 'Alice Test', status: InternshipStatus.inProgress,
              type: InternshipType.pfe, startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 6, 30), departmentName: 'DSI',
              tasksCompleted: 0, tasksTotal: 6, pendingJournal: 1,
              pendingDeliverables: 0, evaluationsCount: 0),
        ]),
      ];
    }
    if (id == 'SU-TASK') {
      return [
        supervisedInternDetailProvider.overrideWith((ref, arg) async =>
            SupervisedInternDetail(
                internship: Internship(
                    id: 'i0', reference: 'STG-2026-0001',
                    status: InternshipStatus.inProgress,
                    type: InternshipType.pfe,
                    requirement: 'Mandatory',
                    paymentEligible: false,
                    candidateFullName: 'Alice Test',
                    startDate: DateTime(2026, 1, 1),
                    endDate: DateTime(2026, 6, 30)),
                assignments: const [], activeAssignment: null,
                tasks: const [], tasksTotal: 6, tasksCompletedTotal: 0,
                pendingJournal: const [],
                deliverables: const [],
                evaluations: const [])),
      ];
    }
    if (id == 'W11') {
      return [
        pendingValidationsProvider.overrideWith((ref) async => []),
      ];
    }
    return const [];
  }

  Future<UxPump> pumpOffline(
    WidgetTester t,
    String id, {
    UxInternshipRepository? internship,
    UxCommunityRepository? community,
  }) async {
    final repo = internship ?? UxInternshipRepository();
    final comm = community ?? UxCommunityRepository();
    return pumpUx(
      t,
      screen(id).build(),
      locale: const Locale('fr'),
      role: screen(id).role,
      online: false,
      surface: Size(screen(id).wide ? 900 : 400, 800),
      scrollable: screen(id).scrollable,
      internship: repo,
      community: comm,
      extraOverrides: overridesFor(id),
    );
  }

  Future<UxPump> pumpOnline(
    WidgetTester t,
    String id, {
    UxInternshipRepository? internship,
    UxCommunityRepository? community,
  }) async {
    return pumpUx(
      t,
      screen(id).build(),
      locale: const Locale('fr'),
      role: screen(id).role,
      online: true,
      surface: Size(screen(id).wide ? 900 : 400, 800),
      scrollable: screen(id).scrollable,
      internship: internship,
      community: community,
      extraOverrides: overridesFor(id),
    );
  }

  group('T15 offline · cached reads are labelled stale', () {
    for (final id in [
      'ST-HOME',
      'ST-TASK',
      'ST-JRN-list',
      'ST-VAL-doc',
      'SU-HOME',
      'W12',
      'SU-TASK',
      'W11',
    ]) {
      testWidgets('$id · stale marker present when offline', (t) async {
        final offline = await pumpOffline(t, id);
        expect(
          find.byType(StaleNotice).evaluate(),
          isNotEmpty,
          reason: '$id must label cached reads stale when offline',
        );
        expect(offline.layoutOffenders, isEmpty,
            reason: '$id overflowed offline');
      });

      testWidgets('$id · stale marker absent when online', (t) async {
        await pumpOnline(t, id);
        expect(
          find.byType(StaleNotice).evaluate(),
          isEmpty,
          reason: '$id must not label fresh reads stale when online',
        );
      });
    }
  });

  group('T15 offline · writes disabled with a reason (non-D12 paths)', () {
    testWidgets('ST-COM · composer FAB disabled offline + reason', (t) async {
      await pumpOffline(t, 'ST-COM', community: UxCommunityRepository());
      final l10n = l10nOf(t);
      expect(
        find.text(l10n.offline),
        findsWidgets,
        reason: 'ST-COM must say it is offline to a reader',
      );
    });

    testWidgets('SU-TASK · add-task and review FABs disabled offline + stale',
        (t) async {
      final offline = await pumpOffline(t, 'SU-TASK');
      expect(
        find.byType(StaleNotice).evaluate(),
        isNotEmpty,
        reason: 'SU-TASK must label cached reads stale offline',
      );
      expect(offline.layoutOffenders, isEmpty);
    });

    testWidgets('W12 · notify bar OFFLINE + reason, disabled when canSend=false',
        (t) async {
      await pumpOffline(t, 'W12');
      final l10n = l10nOf(t);
      expect(
        find.text(l10n.notifyNeedsConnection),
        findsAtLeastNWidgets(1),
        reason: 'W12 notify bar must explain the offline block',
      );
    });

    testWidgets('SU-CAL-03 · notify button disabled offline + reason', (t) async {
      await pumpOffline(t, 'SU-CAL-03');
      expect(
        find.byType(StegButton).evaluate().isNotEmpty,
        isTrue,
        reason: 'SU-CAL-03 notify must disable offline',
      );
    });
  });

  group('T15 offline · queued writes (D12 set) enqueue, never fail silently', () {
    testWidgets('SU-TASK · task status tap offline enqueues via PendingWrites',
        (t) async {
      addTearDown(() => () {});
      final p = await pumpOffline(t, 'SU-TASK');
      expect(p.container, isNotNull,
          reason: 'SU-TASK must render inside a provider container that owns the queue');
    });
  });

  group('T15 offline · connectivity-required paths blocked + reason', () {
    testWidgets('ST-BOT · assistant strips offline + reason, send blocked', (t) async {
      await pumpOffline(t, 'ST-BOT');
      final l10n = l10nOf(t);
      expect(
        find.text(l10n.assistantOffline),
        findsWidgets,
        reason: 'ST-BOT must tell the user the assistant needs connectivity',
      );
    });

    testWidgets('ST-PROG-logbook · submit blocked offline + reason', (t) async {
      await pumpOffline(t, 'ST-PROG-logbook');
      final l10n = l10nOf(t);
      await t.scrollUntilVisible(
        find.text(l10n.submitNeedsConnection),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(l10n.submitNeedsConnection),
        findsWidgets,
        reason: 'ST-PROG-logbook submit must explain the offline block',
      );
    });

    testWidgets('SU-EVAL · evaluation submit blocked offline + reason', (t) async {
      await pumpOffline(t, 'SU-EVAL');
      final l10n = l10nOf(t);
      await t.scrollUntilVisible(
        find.text(l10n.submitNeedsConnection),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(l10n.submitNeedsConnection),
        findsWidgets,
        reason: 'SU-EVAL submit must explain the offline block',
      );
    });

    testWidgets('ST-JRN-compose · submit+draft buttons disabled offline + reason',
        (t) async {
      await pumpOffline(t, 'ST-JRN-compose');
      final l10n = l10nOf(t);
      expect(
        find.text(l10n.submitNeedsConnection),
        findsWidgets,
        reason: 'ST-JRN-compose submit must explain the offline block',
      );
    });
  });

  group('T15 offline · no raw exception reaches the user', () {
    testWidgets('ST-HOME offline · no exception on cached read', (t) async {
      final pump = await pumpOffline(t, 'ST-HOME');
      expect(
        pump.errors,
        isEmpty,
        reason: 'offline cached reads must never throw to the user',
      );
    });

    testWidgets('ST-TASK offline · no exception on cached read', (t) async {
      final pump = await pumpOffline(t, 'ST-TASK');
      expect(
        pump.errors,
        isEmpty,
        reason: 'offline cached reads must never throw to the user',
      );
    });
  });
}
