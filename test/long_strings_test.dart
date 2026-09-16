import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/widgets/intern_card.dart';
import 'package:stegappe/features/internship/presentation/widgets/task_row.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/messaging/presentation/widgets/message_bubble.dart';

Future<void> pumpL10n(
    WidgetTester tester, Widget child, Locale locale) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: StegLocales.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: StegTheme.light(),
        home: Scaffold(
          body: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _longAr =
    'متربص مجتهد جدا في قسم الأنظمة المعلوماتية والتحول الرقمي والتطوير المستمر للمنصة الذكية للتربصات';
const _longFr =
    'Préparer une démonstration très détaillée du projet de digitalisation du suivi avec tous les écrans et tous les cas limites possibles et imaginables';

/// D7 gate: very long Arabic/French strings must wrap or ellipsize —
/// never overflow — on fixed-width phone layouts.
void main() {
  group('long-string overflow gate', () {
    testWidgets('intern card with very long Arabic name', (tester) async {
      await pumpL10n(
        tester,
        InternCard(
          intern: SupervisedIntern(
            internshipId: 'i1',
            reference: 'STG-2026-0000000001-TRÈS-LONGUE-RÉFÉRENCE',
            internName: _longAr,
            status: InternshipStatus.active,
            type: InternshipType.pfe,
            startDate: DateTime(2026, 1, 1),
            endDate: DateTime(2026, 12, 31),
            departmentName: _longAr,
            tasksCompleted: 1,
            tasksTotal: 4,
            pendingJournal: 9,
            pendingDeliverables: 0,
            evaluationsCount: 0,
          ),
        ),
        const Locale('ar'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('task row with very long French title', (tester) async {
      await pumpL10n(
        tester,
        TaskRow(
          task: InternTask(
            id: 't1',
            title: _longFr,
            description: _longFr,
            status: TaskStatus.inProgress,
            dueDate: DateTime(2026, 9, 20),
          ),
          now: DateTime(2026, 9, 15),
          onOpen: () {},
        ),
        const Locale('fr'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('message bubble with very long content', (tester) async {
      await pumpL10n(
        tester,
        MessageBubble(
          message: ChatMessage(
            id: 'm1',
            conversationId: 'c1',
            senderId: 'u2',
            content: '$_longAr $_longFr',
            status: MessageStatus.delivered,
            sequenceNumber: 1,
            sentAt: DateTime(2026, 9, 15, 10),
          ),
        ),
        const Locale('ar'),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
