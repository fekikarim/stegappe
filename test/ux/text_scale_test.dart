import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/presentation/screens/bulk_task_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/classification_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/classification_suggest_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/deliverable_upload_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_generation_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/task_editor_sheet.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';

import '../features/messaging/messaging_widget_test.dart' show FakeNotifRepo;
import 'ux_harness.dart';

/// T15 · Phase 4 — text scaling evidence.
///
/// Every shipped screen is pumped at 1.3× and 2.0× (WCAG 1.4.4 resize-text)
/// and every surface that can hold long content (buttons, dialogs, sheets,
/// cards, task rows, chat messages, AI answers, notification rows, calendar,
/// deliverables) is pumped at 2.0× with worst-case strings. Failure means the
/// framework reported a real layout overflow, with the app source location
/// attached — not a visual guess.
void main() {
  for (final scale in <double>[1.3, 2.0]) {
    group('T15 scaling · every ux-ui §4 screen at $scale×', () {
      for (final screen in uxScreens()) {
        testWidgets('${screen.id} · ${screen.name} survives $scale×',
            (tester) async {
          final pump = await pumpUx(
            tester,
            screen.build(),
            textScale: scale,
            role: screen.role,
            scrollable: screen.scrollable,
            surface: Size(screen.wide ? 900 : 400, 800),
          );
          final offenders = pump.layoutOffenders.join('\n');
          expect(pump.layoutOffenders, isEmpty,
              reason: '${screen.name} overflowed at $scale×:\n$offenders');
        });
      }
    });
  }

  group('T15 scaling · bottom sheets and pickers at 2.0×', () {
    final sheets = <String, Widget>{
      'task editor (intern)': const TaskEditorSheet(
          internshipId: 'internship-1'),
      'task editor (staff)': const TaskEditorSheet(
          internshipId: 'internship-1',
          staffMode: true),
      'deliverable upload': const DeliverableUploadSheet(
          internshipId: 'internship-1'),
      'deliverable version': const VersionUploadSheet(
          internshipId: 'internship-1', deliverableId: 'd0'),
      'bulk task': const BulkTaskSheet(),
      'classification': const ClassificationSheet(),
      'AI classification proposal': const SuggestSheet(),
      'journal generation bar': const JournalGenerationBar(
          internshipId: 'internship-1'),
      'journal generation sheet': JournalGenerationSheet(
          internshipId: 'internship-1',
          eligibility: JournalEligibility(
            eligible: true,
            reason: 'ELIGIBLE_WINDOW',
            daysUntilOpen: 0,
            windowDays: 14,
            taskCount: 40,
            approvedTasks: 12,
            belowThreshold: true,
            opensAt: DateTime(2026, 9, 1),
            closesAt: DateTime(2026, 9, 15),
          )),
    };

    for (final entry in sheets.entries) {
      testWidgets('${entry.key} sheet survives 2.0×', (tester) async {
        final pump = await pumpUx(
          tester,
          entry.value,
          textScale: 2.0,
          scrollable: true,
          surface: const Size(400, 800),
        );
        final offenders = pump.layoutOffenders.join('\n');
        expect(pump.layoutOffenders, isEmpty,
            reason: '${entry.key} overflowed at 2.0×:\n$offenders');
      });
    }
  });

  group('T15 scaling · worst-case content at 2.0×', () {
    Future<UxPump> pumpFor(WidgetTester tester, UxScreen screen,
        {FakeNotifRepo? notifications, bool online = true}) async {
      return pumpUx(
        tester,
        screen.build(),
        textScale: 2.0,
        role: screen.role,
        online: online,
        scrollable: screen.scrollable,
        notifications: notifications,
        surface: Size(screen.wide ? 900 : 400, 800),
      );
    }

    UxScreen screen(String id) =>
        uxScreens().firstWhere((s) => s.id == id);

    testWidgets('chat with a 2 000-character mixed-direction message',
        (tester) async {
      final pump = await pumpUx(
        tester,
        screen('ST-MSG-chat').build(),
        textScale: 2.0,
        messaging: UxMessagingRepository(),
      );
      expect(pump.layoutOffenders, isEmpty,
          reason: pump.layoutOffenders.join('\n'));
    });

    testWidgets('conversation list with a long title', (tester) async {
      final pump = await pumpUx(
        tester,
        screen('ST-MSG-list').build(),
        textScale: 2.0,
        messaging: UxMessagingRepository(),
      );
      expect(pump.layoutOffenders, isEmpty,
          reason: pump.layoutOffenders.join('\n'));
    });

    testWidgets('assistant with a 2 000-character answer', (tester) async {
      final pump = await pumpFor(tester, screen('ST-BOT'));
      expect(pump.internship.calls['askAssistant'], isNull,
          reason: 'the probe must not answer before the user asks');
      expect(pump.layoutOffenders, isEmpty,
          reason: pump.layoutOffenders.join('\n'));
    });

    testWidgets('task board with long titles', (tester) async {
      final pump = await pumpFor(tester, screen('ST-TASK'));
      expect(pump.layoutOffenders, isEmpty,
          reason: pump.layoutOffenders.join('\n'));
    });

    testWidgets('deliverables with long titles', (tester) async {
      final pump = await pumpFor(tester, screen('ST-VAL-doc'));
      expect(pump.layoutOffenders, isEmpty,
          reason: pump.layoutOffenders.join('\n'));
    });

    testWidgets('community feed with long posts', (tester) async {
      final pump = await pumpFor(tester, screen('ST-COM'));
      expect(pump.layoutOffenders, isEmpty,
          reason: pump.layoutOffenders.join('\n'));
    });

    testWidgets('notification rows with long titles and messages',
        (tester) async {
      final long = FakeNotifRepo(extraItems: [
        NotificationItem(
          id: 'n-long',
          title: '$kLongFr $kLongAr',
          message: '$kLongAr — $kLongFr',
          priority: 'HIGH',
          createdAt: DateTime(2026, 9, 15, 9),
          isRead: false,
        ),
      ]);
      final pump = await pumpFor(tester, screen('ST-NOT'),
          notifications: long);
      expect(pump.layoutOffenders, isEmpty,
          reason: pump.layoutOffenders.join('\n'));
    });

    testWidgets('intern list with long names at 2.0×', (tester) async {
      final pump = await pumpFor(tester, screen('W12'));
      expect(pump.layoutOffenders, isEmpty,
          reason: pump.layoutOffenders.join('\n'));
    });
  });
}
