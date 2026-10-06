import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/l10n/settings_providers.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/network/error_messages.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/messaging/presentation/screens/attachment_sheet.dart';
import 'package:stegappe/features/messaging/presentation/screens/chat_screen.dart';

import '../../support/queue_harness.dart';
import '../../test_fixtures.dart';
import 'messaging_widget_test.dart'
    show FakeMessagingRepo, FakeStomp, pumpMsg;
import 'notifications_test_support.dart'
    show FakeAuthRepository, FakeStompService;

/// T07 — 1-to-1 messaging: contract rules, idempotent sends, echo
/// reconciliation, day separators, send-from-deliverables.
///
/// Server authority recap (verified in code, not re-proven here):
/// membership per active row (`MessagingService.assertActiveMembership`),
/// monotonic `sequenceNumber` ordering, `X-Idempotency-Key` replay
/// (`MessageIdempotencyTest`), sequence watermarks for delivered/read,
/// `MESSAGE_RECEIVED` fan-out, PRIVATE-thread rebind on every assignment
/// path (`ConversationReassignmentTest`).
void main() {
  group('message content contract (server `@NotBlank @Size(max=4000)`)', () {
    test('rules mirror the backend limit and blank rule', () {
      expect(ChatMessageRules.maxLength, 4000);
      expect(ChatMessageRules.tooLongCode, 'MESSAGE_TOO_LONG');
      expect(ChatMessageRules.isSendable(''), isFalse);
      expect(ChatMessageRules.isSendable('   '), isFalse);
      expect(ChatMessageRules.isSendable('bonjour'), isTrue);
    });

    test('attachment size guard: 9 MB passes, 12 MB refused', () {
      const nineMb = 9 * 1024 * 1024;
      const twelveMb = 12 * 1024 * 1024;
      expect(
          ChatAttachmentRules.check('rapport.pdf', nineMb), isNull);
      expect(ChatAttachmentRules.check('rapport.pdf', twelveMb),
          'size');
      expect(ChatAttachmentRules.check('notes.pdf', 0), 'empty');
      expect(ChatAttachmentRules.check('run.exe', 100), 'type');
    });

    test('MESSAGE_TOO_LONG maps to the precise sentence (fr/en/ar)', () {
      const fr = AppLocalizations(Locale('fr'));
      const en = AppLocalizations(Locale('en'));
      const ar = AppLocalizations(Locale('ar'));
      ApiException tooLong() => const ApiException(
          kind: ApiErrorKind.validation,
          message: 'raw backend text',
          statusCode: 422,
          code: 'MESSAGE_TOO_LONG');
      expect(userErrorOf(tooLong(), fr).message,
          fr.errMessageTooLong);
      expect(userErrorOf(tooLong(), en).message,
          en.errMessageTooLong);
      expect(userErrorOf(tooLong(), ar).message,
          ar.errMessageTooLong);
      expect(userErrorOf(tooLong(), fr).retryable, isFalse);
    });
  });

  group('idempotent send (BR-56)', () {
    late FakeMessagingRepo repo;

    Future<ProviderContainer> container() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        internshipRepositoryProvider
            .overrideWithValue(FakeInternshipRepository()),
        messagingRepositoryProvider.overrideWithValue(repo),
        stompChatServiceProvider.overrideWithValue(FakeStompService()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      repo = FakeMessagingRepo();
    });

    test('REST fallback forwards one key per logical message', () async {
      final c = await container();
      final controller =
          c.read(chatControllerProvider('c1').notifier);
      await _awaitInit(controller);

      await controller.send('hello once');

      expect(repo.sentKeys, hasLength(1));
      expect(repo.sentKeys.single, isNotNull);
      expect(controller.state.pending, isEmpty);
      expect(
          controller.state.messages
              .where((m) => m.sequenceNumber == 99),
          hasLength(1));
    });

    test('explicit retry reuses the failed attempt key', () async {
      final c = await container();
      final controller =
          c.read(chatControllerProvider('c1').notifier);

      repo.failSends = true;
      await controller.send('retry me');
      expect(controller.state.failed, hasLength(1));
      final key = controller.state.failed.single.key;
      expect(key, isNotEmpty);

      repo.failSends = false;
      final failed = controller.state.failed.single;
      controller.discardFailed(failed);
      await controller.send(failed.content,
          idempotencyKey: failed.key);
      expect(repo.sentKeys.last, key);
    });

    test('over-length text fails fast with the precise error', () async {
      final c = await container();
      final controller =
          c.read(chatControllerProvider('c1').notifier);

      await controller.send('x' * 4001);

      expect(controller.state.pending, isEmpty);
      expect(controller.state.failed, hasLength(1));
      final error = controller.state.failed.single.error;
      expect(error, isA<ApiException>());
      const fr = AppLocalizations(Locale('fr'));
      expect(userErrorOf(error!, fr).message,
          fr.errMessageTooLong);
    });

    test('REST success + same-id broadcast reconciles to one message',
        () async {
      final c = await container();
      final controller =
          c.read(chatControllerProvider('c1').notifier);
      await _awaitInit(controller);

      await controller.send('rest then echo');
      expect(
          controller.state.messages
              .where((m) => m.sequenceNumber == 99),
          hasLength(1));

      // The live broadcast of the same server row (same id) merges,
      // never appends a twin.
      await controller.debugFrame(
          '{"id":"m99","conversationId":"c1","senderId":"me",'
          '"content":"echo","status":"SENT","sequenceNumber":99,'
          '"sentAt":"2026-09-15T10:09:00Z","attachments":[]}');
      final rows = controller.state.messages
          .where((m) => m.id == 'm99');
      expect(rows, hasLength(1));
    });
  });

  group('rapid identical sends (echo drops oldest match only)', () {
    test('two "ok" pendings need two echoes to clear', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final stomp = FakeStomp()
        ..setState(ChatConnectionState.connected);
      final repo = FakeMessagingRepo(stomp: stomp);
      final c = ProviderContainer(overrides: [
        prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        internshipRepositoryProvider
            .overrideWithValue(FakeInternshipRepository()),
        messagingRepositoryProvider.overrideWithValue(repo),
        stompChatServiceProvider.overrideWithValue(stomp),
      ]);
      addTearDown(c.dispose);
      final controller =
          c.read(chatControllerProvider('c1').notifier);

      // Hold the socket sends mid-flight so both pending bubbles stay
      // on screen (the production shape while waiting for echoes).
      stomp.sendGate = Completer<void>();
      unawaited(controller.send('ok'));
      unawaited(controller.send('ok'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
          controller.state.pending
              .where((p) => p.content == 'ok'),
          hasLength(2));

      await controller.debugFrame(
          '{"id":"m9","conversationId":"c1","senderId":"me",'
          '"content":"ok","status":"SENT","sequenceNumber":9,'
          '"sentAt":"2026-09-15T10:09:00Z","attachments":[]}');
      expect(
          controller.state.pending
              .where((p) => p.content == 'ok'),
          hasLength(1));

      await controller.debugFrame(
          '{"id":"m10","conversationId":"c1","senderId":"me",'
          '"content":"ok","status":"SENT","sequenceNumber":10,'
          '"sentAt":"2026-09-15T10:10:00Z","attachments":[]}');
      expect(
          controller.state.pending
              .where((p) => p.content == 'ok'),
          isEmpty);

      // Release the held sends: their local ids are already gone, so the
      // late completions are no-ops and no twin is created.
      stomp.sendGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
          controller.state.messages
              .where((m) => m.id == 'm9' || m.id == 'm10'),
          hasLength(2));
    });
  });

  group('chat screen (T07 UX)', () {
    testWidgets('day separators split history by calendar day',
        (tester) async {
      final repo = _TwoDayRepo();
      await pumpMsg(tester,
          const ChatScreen(conversationId: 'c1', title: 't'),
          repo: repo);
      // Two calendar days → two full-date separators (fr pump locale).
      expect(find.textContaining('septembre'), findsNWidgets(2));
      expect(find.text('daymsg 1'), findsOneWidget);
      expect(find.text('daymsg 3'), findsOneWidget);
    });

    testWidgets('composer caps input at the server limit',
        (tester) async {
      await pumpMsg(tester,
          const ChatScreen(conversationId: 'c1', title: 't'));
      final field =
          tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, ChatMessageRules.maxLength);
    });

    testWidgets('without internship the document option stays hidden',
        (tester) async {
      await pumpMsg(
          tester,
          const AttachmentSheet(conversationId: 'c1'),
          repo: FakeMessagingRepo());
      expect(find.text('Joindre un fichier'), findsOneWidget);
      expect(find.text('Envoyer un document du stage'),
          findsNothing);
    });

    testWidgets('send journal/report from the chat stages the file',
        (tester) async {
      await pumpMsg(
          tester,
          const AttachmentSheet(
              conversationId: 'c1', internshipId: 'internship-1'),
          repo: FakeMessagingRepo());
      await tester.tap(find.text('Envoyer un document du stage'));
      await tester.pumpAndSettle();
      expect(find.text('Rapport de stage'), findsOneWidget);

      await tester.tap(find.text('Rapport de stage'));
      await tester.pumpAndSettle();

      // Staged file (picker collapses) + prefilled caption in the field.
      expect(find.text('rapport-v2.pdf'), findsOneWidget);
      expect(find.text('Rapport de stage'), findsOneWidget);
    });

    testWidgets('oversize deliverable names the alternative path',
        (tester) async {
      await _pumpSheet(tester, _BigDocInternshipRepo());
      await tester.tap(find.text('Envoyer un document du stage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rapport de stage').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('dépasse 10 Mo'),
          findsOneWidget);
      // Nothing staged: the device-pick slot stays empty.
      expect(find.text('rapport-v2.pdf'), findsNothing);
    });
  });
}

/// Waits for the controller's initial history load: without this, an
/// immediately following send can be wiped by the racing initial merge
/// (`loadInitial` replaces, later merges win — production converges the
/// same way through resync).
Future<void> _awaitInit(ChatController c) async {
  for (var i = 0; i < 100 && !c.state.initialized; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(c.state.initialized, isTrue);
}
/// Two-day history: seq 1–2 on 2026-09-14, seq 3 on 2026-09-15.
class _TwoDayRepo extends FakeMessagingRepo {
  ChatMessage _d(int seq, DateTime day) => ChatMessage(
        id: 'd$seq',
        conversationId: 'c1',
        senderId: 'u2',
        content: 'daymsg $seq',
        status: MessageStatus.sent,
        sequenceNumber: seq,
        sentAt: day,
      );

  @override
  Future<Paged<ChatMessage>> history(String conversationId,
      {int? cursor, int size = 30}) async {
    return Paged(
      items: [
        _d(3, DateTime(2026, 9, 15, 10, 5)),
        _d(2, DateTime(2026, 9, 14, 18, 40)),
        _d(1, DateTime(2026, 9, 14, 9, 2)),
      ],
      page: 0,
      totalElements: 3,
      totalPages: 1,
      isLast: true,
    );
  }
}

/// 11 MB download: the picker must refuse with the alternative path.
class _BigDocInternshipRepo extends FakeInternshipRepository {
  @override
  Future<Uint8List> downloadDeliverable(String deliverableId,
      {int? version}) async {
    return Uint8List(11 * 1024 * 1024);
  }
}

/// Sheet pump with a controllable internship repository (deliverables).
Future<void> _pumpSheet(
    WidgetTester tester, FakeInternshipRepository docs) async {
  final repo = FakeMessagingRepo();
  final stomp = FakeStomp()
    ..setState(ChatConnectionState.connected);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository()),
        internshipRepositoryProvider.overrideWithValue(docs),
        messagingRepositoryProvider.overrideWithValue(repo),
        stompChatServiceProvider.overrideWithValue(stomp),
        isOnlineProvider.overrideWith((ref) => true),
        await queueOverride(),
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
        home: const Scaffold(
          body: AttachmentSheet(
              conversationId: 'c1',
              internshipId: 'internship-1'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
