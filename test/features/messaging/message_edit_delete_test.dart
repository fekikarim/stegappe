import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/messaging/presentation/screens/chat_screen.dart';

import 'messaging_widget_test.dart'
    show FakeMessagingRepo, FakeStomp, pumpMsg;

/// Regression: editing/deleting an own 1-to-1 message must never red-screen.
///
/// The edit dialog used to own its TextEditingController and dispose it
/// synchronously on pop — while the popping route still rebuilds its
/// TextField during the exit animation ("used after being disposed",
/// cascading into `InheritedElement._dependents.isEmpty`). The dialog now
/// borrows a screen-owned controller; these tests drive both flows
/// end-to-end and fail on any framework exception.
ChatMessage _mine(int seq, String content) => ChatMessage(
      id: 'mine$seq',
      conversationId: 'c1',
      senderId: 'me',
      content: content,
      status: MessageStatus.sent,
      sequenceNumber: seq,
      sentAt: DateTime(2026, 9, 15, 10, seq),
      mine: true,
    );

class _MineRepo extends FakeMessagingRepo {
  _MineRepo({super.stomp});

  @override
  Future<Paged<ChatMessage>> history(
    String conversationId, {
    int? cursor,
    int size = 30,
  }) async {
    return Paged(
      items: [_mine(5, 'original text')],
      page: 0,
      totalElements: 1,
      totalPages: 1,
      isLast: true,
    );
  }
}

Future<void> _pumpMine(WidgetTester tester) async {
  final s = FakeStomp();
  await pumpMsg(
    tester,
    const ChatScreen(conversationId: 'c1', title: 't'),
    repo: _MineRepo(stomp: s),
    stomp: s,
  );
}

void main() {
  group('1-to-1 message edit / delete (regression)', () {
    testWidgets('edit own message applies without exceptions',
        (tester) async {
      await _pumpMine(tester);
      expect(find.text('original text'), findsOneWidget);

      await tester.longPress(find.text('original text'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le message'), findsOneWidget);

      await tester.enterText(
          find.byType(TextField).last, 'edited text');
      await tester.pump();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('edited text'), findsOneWidget);
    });

    testWidgets('delete own message redacts without exceptions',
        (tester) async {
      await _pumpMine(tester);

      await tester.longPress(find.text('original text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer le message ?'));
      await tester.pumpAndSettle();

      // Confirm dialog (title + explicit destructive action).
      expect(find.text('Supprimer le message ?'), findsOneWidget);
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Soft-delete: slot kept, content redacted.
      expect(find.text('Message supprimé'), findsOneWidget);
      expect(find.text('original text'), findsNothing);
    });

    testWidgets('cancelling edit keeps the original text', (tester) async {
      await _pumpMine(tester);

      await tester.longPress(find.text('original text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'draft');
      await tester.pump();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('original text'), findsOneWidget);
    });
  });
}
