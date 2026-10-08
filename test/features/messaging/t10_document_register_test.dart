import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/messaging/presentation/screens/attachment_sheet.dart';
import 'package:stegappe/features/messaging/presentation/widgets/message_bubble.dart';

import '../../test_fixtures.dart';

/// T10/SU-VAL-01 — the supervisor long-presses (or opens the "…" menu on) a
/// received attachment and registers it as the journal/report; the feedback
/// states this is a first-level review (D2/BR-28). Document-sourced sends
/// carry the `deliverableId` link that makes the registration possible.
class _FakeMessagingRepo implements MessagingRepository {
  String? lastAttachmentDeliverableId;
  String? lastContent;

  @override
  Future<ChatMessage> sendWithAttachment(
    String conversationId, {
    required String content,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
    String? deliverableId,
  }) async {
    lastAttachmentDeliverableId = deliverableId;
    lastContent = content;
    return ChatMessage(
      id: 'm100',
      conversationId: conversationId,
      senderId: 'u1',
      content: content,
      status: MessageStatus.sent,
      sequenceNumber: 100,
      sentAt: DateTime(2026, 10, 7, 10),
      attachments: [
        MessageAttachment(
          id: 'a100',
          fileName: fileName,
          mimeType: contentType,
          size: bytes.length,
          sourceDeliverableId: deliverableId,
        ),
      ],
      mine: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _linkedAttachment = MessageAttachment(
  id: 'a1',
  fileName: 'journal-envoye.pdf',
  mimeType: 'application/pdf',
  size: 4096,
  sourceDeliverableId: 'd-sub',
);

const _plainAttachment = MessageAttachment(
  id: 'a2',
  fileName: 'photo-libre.pdf',
  mimeType: 'application/pdf',
  size: 2048,
);

ChatMessage _messageWith(MessageAttachment attachment) => ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      senderId: 'other',
      content: 'Voici mon document.',
      status: MessageStatus.sent,
      sequenceNumber: 1,
      sentAt: DateTime(2026, 10, 7, 9),
      attachments: [attachment],
    );

Future<FakeInternshipRepository> pumpWith(
  WidgetTester tester,
  Widget page, {
  FakeInternshipRepository? fake,
  MessagingRepository? messaging,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  final messagingRepo = messaging ?? _FakeMessagingRepo();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        internshipRepositoryProvider.overrideWithValue(repo),
        messagingRepositoryProvider.overrideWithValue(messagingRepo),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: StegLocales.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: StegTheme.light(),
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<AppLocalizations> loadL10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  group('T10/SU-VAL-01 — supervisor registers the attachment from the chat',
      () {
    testWidgets('long-press opens the actions and registers as journal',
        (tester) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      await pumpWith(
        tester,
        MessageBubble(
          message: _messageWith(_linkedAttachment),
          canRegisterDocuments: true,
        ),
        fake: fake,
      );

      await tester.longPress(find.text('journal-envoye.pdf'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.msgSetAsJournal), findsOneWidget);
      expect(find.text(l10n.msgSetAsReport), findsOneWidget);

      await tester.tap(find.text(l10n.msgSetAsJournal));
      await tester.pumpAndSettle();

      expect(fake.registeredKinds, contains(('d-sub', 'JOURNAL')));
      // First-level framing in the feedback (D2/BR-28): the administration
      // takes the final decision.
      expect(
        find.text(l10n.msgDocRegistered(l10n.deliverableKindJournal)),
        findsOneWidget,
      );
    });

    testWidgets('the explicit "…" menu reaches the same actions', (
      tester,
    ) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      await pumpWith(
        tester,
        MessageBubble(
          message: _messageWith(_linkedAttachment),
          canRegisterDocuments: true,
        ),
        fake: fake,
      );

      await tester.tap(find.byTooltip(l10n.msgDocMenu));
      await tester.pumpAndSettle();
      expect(find.text(l10n.msgSetAsReport), findsOneWidget);

      await tester.tap(find.text(l10n.msgSetAsReport));
      await tester.pumpAndSettle();
      expect(fake.registeredKinds, contains(('d-sub', 'REPORT')));
    });

    testWidgets('a viewer without the staff role gets no registration rows',
        (tester) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      await pumpWith(
        tester,
        MessageBubble(
          message: _messageWith(_linkedAttachment),
          canRegisterDocuments: false,
        ),
        fake: fake,
      );

      await tester.longPress(find.text('journal-envoye.pdf'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.msgSetAsJournal), findsNothing);
      expect(find.text(l10n.msgSetAsReport), findsNothing);
      expect(fake.registeredKinds, isEmpty);
    });

    testWidgets('a plain chat file says honestly why it cannot register', (
      tester,
    ) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      await pumpWith(
        tester,
        MessageBubble(
          message: _messageWith(_plainAttachment),
          canRegisterDocuments: true,
        ),
        fake: fake,
      );

      await tester.longPress(find.text('photo-libre.pdf'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.msgDocNotLinked), findsOneWidget);
      expect(find.text(l10n.msgSetAsJournal), findsNothing);
    });

    testWidgets('an already-registered kind marks itself and refuses re-taps',
        (tester) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      const alreadyJournal = MessageAttachment(
        id: 'a3',
        fileName: 'journal.pdf',
        mimeType: 'application/pdf',
        size: 1024,
        sourceDeliverableId: 'd1',
        sourceDocumentKind: 'JOURNAL',
      );
      await pumpWith(
        tester,
        MessageBubble(
          message: _messageWith(alreadyJournal),
          canRegisterDocuments: true,
        ),
        fake: fake,
      );

      // The chip shows the registered kind inline.
      expect(find.text(l10n.deliverableKindJournal), findsOneWidget);

      await tester.longPress(find.text('journal.pdf'));
      await tester.pumpAndSettle();
      // The current kind row is present but not re-registerable.
      final journalRow = find.widgetWithText(ListTile, l10n.msgSetAsJournal);
      expect(journalRow, findsOneWidget);
      expect(tester.widget<ListTile>(journalRow).enabled, isFalse);
      expect(fake.registeredKinds, isEmpty);
    });
  });

  group('T10/SU-VAL-01 — sending a document carries the source link', () {
    testWidgets('the deliverable picker stages with its id and sends it',
        (tester) async {
      final fake = FakeInternshipRepository();
      final messaging = _FakeMessagingRepo();
      final l10n = await loadL10n('fr');
      await pumpWith(
        tester,
        const AttachmentSheet(
          conversationId: 'c1',
          internshipId: 'internship-1',
        ),
        fake: fake,
        messaging: messaging,
      );

      await tester.tap(find.text(l10n.msgFromDocs));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brouillon rapport'));
      await tester.pumpAndSettle();

      // Caption prefilled by the staging step (contract requires one).
      expect(find.widgetWithText(TextField, 'Brouillon rapport'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, l10n.msgSend));
      await tester.pumpAndSettle();

      expect(messaging.lastAttachmentDeliverableId, 'd-draft');
      expect(messaging.lastContent, 'Brouillon rapport');
    });
  });
}
