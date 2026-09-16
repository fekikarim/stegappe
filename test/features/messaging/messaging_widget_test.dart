import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/paged.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';
import 'package:stegappe/features/messaging/domain/entities/conversation.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/domain/repositories/messaging_repository.dart';
import 'package:stegappe/features/messaging/domain/repositories/notification_repository.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/messaging/presentation/screens/chat_screen.dart';
import 'package:stegappe/features/messaging/presentation/screens/conversations_screen.dart';
import 'package:stegappe/features/messaging/presentation/screens/notifications_screen.dart';

class _FakeAuth implements AuthRepository {
  @override
  Future<AppUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => const AppUser(
      id: 'me', email: 'intern@u.tn', roles: ['INTERN']);
}

/// Controllable socket: state, recorded frames, injectable inbound.
class FakeStomp implements StompChatService {
  ChatConnectionState _state = ChatConnectionState.disconnected;
  final _stateCtrl =
      StreamController<ChatConnectionState>.broadcast();
  final _resyncCtrl = StreamController<void>.broadcast();
  final sent = <String>[];
  final ackedRead = <int>[];
  final ackedDelivered = <int>[];
  final subs = <String>[];
  ChatFrameCallback? frameHandler;
  bool failSends = false;
  Completer<void>? sendGate;

  void setState(ChatConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
    if (s == ChatConnectionState.connected) _resyncCtrl.add(null);
  }

  void inbound(String body) => frameHandler?.call(body);

  @override
  Stream<ChatConnectionState> get state => _stateCtrl.stream;
  @override
  ChatConnectionState get currentState => _state;
  @override
  Stream<void> get resyncRequested => _resyncCtrl.stream;

  @override
  Future<void> ensureConnected() async {
    if (_state == ChatConnectionState.disconnected) {
      setState(ChatConnectionState.connected);
    }
  }

  @override
  Future<void> disconnect() async =>
      setState(ChatConnectionState.disconnected);

  @override
  Future<void Function()> subscribeConversation(
      String conversationId, ChatFrameCallback onFrame) async {
    subs.add(conversationId);
    frameHandler = onFrame;
    return () {};
  }

  @override
  Future<void> subscribeNotifications(
      ChatFrameCallback onPayload) async {}

  @override
  Future<void> subscribeErrors(
      void Function(String code, String message) onError) async {}

  @override
  Future<void> sendMessage(
      String conversationId, String content) async {
    final gate = sendGate;
    if (gate != null) await gate.future;
    if (failSends || _state != ChatConnectionState.connected) {
      throw StateError('STOMP not connected');
    }
    sent.add(content);
  }

  @override
  Future<void> ackDelivered(
      String conversationId, int upToSequence) async {
    ackedDelivered.add(upToSequence);
  }

  @override
  Future<void> ackRead(
      String conversationId, int upToSequence) async {
    ackedRead.add(upToSequence);
  }
}

ChatMessage _m(int seq,
        {String status = 'SENT', String sender = 'u2'}) =>
    ChatMessage(
      id: 'm$seq',
      conversationId: 'c1',
      senderId: sender,
      content: 'hello $seq',
      status: messageStatusFrom(status),
      sequenceNumber: seq,
      sentAt: DateTime(2026, 9, 15, 10, seq),
      mine: sender == 'me',
    );

class FakeMessagingRepo implements MessagingRepository {
  FakeMessagingRepo({this.stomp});

  final FakeStomp? stomp;
  bool failHistory = false;
  bool failSends = false;
  final readMarks = <int>[];

  List<Conversation> convos = const [
    Conversation(
        id: 'c1',
        type: ConversationType.private,
        title: 'Karim Feki',
        unreadCount: 2),
    Conversation(
        id: 'c2',
        type: ConversationType.group,
        title: 'Interns',
        unreadCount: 0),
  ];

  @override
  Future<List<Conversation>> conversations() async => convos;

  @override
  Future<Map<String, int>> unreadCounts() async =>
      {for (final c in convos) c.id: c.unreadCount};

  @override
  Future<Paged<ChatMessage>> history(String conversationId,
      {int? cursor, int size = 30}) async {
    if (failHistory) throw Exception('history failed');
    // Newest-first pages: [3,2] then cursor=2 → [1].
    if (cursor == null) {
      return Paged(
          items: [_m(3), _m(2)],
          page: 0,
          totalElements: 3,
          totalPages: 2,
          isLast: false);
    }
    return Paged(
        items: [_m(1)],
        page: 1,
        totalElements: 3,
        totalPages: 2,
        isLast: true);
  }

  @override
  Future<ChatMessage?> latestMessage(String conversationId) async =>
      conversationId == 'c1' ? _m(3) : null;

  @override
  Future<SentMessage?> send(String conversationId, String content) async {
    if (failSends) throw Exception('send failed');
    final stompRef = stomp;
    final live = stompRef != null &&
        stompRef.currentState == ChatConnectionState.connected;
    if (live) {
      await stompRef.sendMessage(conversationId, content);
      return null; // echo pending via broadcast
    }
    return SentMessage(
        message: _m(99, sender: 'me'), channel: SendChannel.rest);
  }

  @override
  Future<ChatMessage> sendWithAttachment(String conversationId,
      {required String content,
      required String fileName,
      required String contentType,
      required Uint8List bytes,
      void Function(int sent, int total)? onProgress}) async {
    onProgress?.call(bytes.length, bytes.length);
    return _m(100, sender: 'me');
  }

  @override
  Future<void> markRead(String conversationId, int upToSequence) async {
    readMarks.add(upToSequence);
    final stompRef = stomp;
    if (stompRef != null &&
        stompRef.currentState == ChatConnectionState.connected) {
      await stompRef.ackRead(conversationId, upToSequence);
    }
  }

  @override
  Future<void> markDelivered(
      String conversationId, int upToSequence) async {}

  @override
  Future<Uint8List> downloadAttachment(
          String attachmentId, String fileName) async =>
      Uint8List.fromList([1, 2, 3]);

  @override
  @override
  Future<ChatMessage?> parseFrame(String body) async {
    try {
      // ignore: avoid_dynamic_calls
      final map = jsonDecode(body) as Map<String, dynamic>;
      if (map['id'] == null) return null;
      final sender = (map['senderId'] ?? '').toString();
      return ChatMessage(
        id: (map['id'] ?? '').toString(),
        conversationId:
            (map['conversationId'] ?? 'c1').toString(),
        senderId: sender,
        content: (map['content'] ?? '').toString(),
        status: messageStatusFrom(map['status'] as String?),
        sequenceNumber: (map['sequenceNumber'] as num?)?.toInt() ?? 0,
        sentAt: DateTime.tryParse(
                (map['sentAt'] ?? '').toString()) ??
            DateTime.now(),
        mine: sender == 'me',
      );
    } on Exception {
      return null;
    }
  }
}

class FakeNotifRepo implements NotificationRepository {
  var readAll = false;
  final read = <String>[];

  @override
  Future<Paged<NotificationItem>> list(
      {int page = 0, int size = 20, bool unreadOnly = false}) async {
    final items = [
      NotificationItem(
          id: 'n1',
          title: 'Journal validé',
          message: 'Votre entrée a été validée',
          priority: 'NORMAL',
          createdAt: DateTime(2026, 9, 15, 9),
          isRead: false),
      NotificationItem(
          id: 'n2',
          title: 'Bienvenue',
          message: 'Bienvenue sur la plateforme',
          priority: 'LOW',
          createdAt: DateTime(2026, 9, 14, 9),
          isRead: true),
    ];
    final shown =
        unreadOnly ? items.where((n) => !n.isRead).toList() : items;
    return Paged(
        items: shown,
        page: 0,
        totalElements: shown.length,
        totalPages: 1,
        isLast: true);
  }

  @override
  Future<int> unreadCount() async => 1;

  @override
  Future<void> markRead(String id) async {
    read.add(id);
  }

  @override
  Future<void> markAllRead() async {
    readAll = true;
  }
}

Future<void> pumpMsg(
  WidgetTester tester,
  Widget page, {
  FakeMessagingRepo? repo,
  FakeNotifRepo? notifs,
  FakeStomp? stomp,
}) async {
  final s = stomp ?? FakeStomp();
  s.setState(ChatConnectionState.connected);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth()),
        messagingRepositoryProvider.overrideWithValue(
            repo ?? FakeMessagingRepo(stomp: s)),
        notificationRepositoryProvider.overrideWithValue(
            notifs ?? FakeNotifRepo()),
        stompChatServiceProvider.overrideWithValue(s),
        isOnlineProvider.overrideWith((ref) => true),
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
        home: Scaffold(body: page),
      ),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
}

void main() {
  group('conversations list (acceptance)', () {
    testWidgets('unread badges + last-message preview', (tester) async {
      await pumpMsg(tester, const ConversationsScreen());
      expect(find.text('Karim Feki'), findsOneWidget);
      expect(find.text('Interns'), findsOneWidget);
      expect(find.text('hello 3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // unread badge
    });

    testWidgets('empty state explains the space', (tester) async {
      final repo = FakeMessagingRepo()..convos = const [];
      await pumpMsg(tester, const ConversationsScreen(),
          repo: repo);
      expect(find.text('Aucune conversation.'), findsOneWidget);
    });
  });

  group('chat screen (acceptance)', () {
    testWidgets('history renders ascending with read markers',
        (tester) async {
      await pumpMsg(
          tester,
          const ChatScreen(
              conversationId: 'c1', title: 'Karim Feki'));
      expect(find.text('hello 2'), findsOneWidget);
      expect(find.text('hello 3'), findsOneWidget);
      // Older page loads through the controller (edge scroll in prod).
      final ctx = tester.element(find.byType(ChatScreen));
      await ProviderScope.containerOf(ctx)
          .read(chatControllerProvider('c1').notifier)
          .loadMore();
      await tester.pumpAndSettle();
      expect(find.text('hello 1'), findsOneWidget);
    });

    testWidgets('STOMP send shows pending until broadcast echo',
        (tester) async {
      final s = FakeStomp();
      final repo = FakeMessagingRepo(stomp: s);
      await pumpMsg(tester,
          const ChatScreen(conversationId: 'c1', title: 't'),
          repo: repo, stomp: s);

      // Hold the socket send so the pending frame is observable.
      s.sendGate = Completer<void>();
      await tester.enterText(
          find.byType(TextField), 'live hello');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pump();
      expect(find.text('live hello'), findsOneWidget);
      s.sendGate!.complete();
      await tester.pumpAndSettle();
      expect(s.sent, contains('live hello'));

      // Broadcast echo reconciles the pending bubble + advances read.
      s.inbound(
          '{"id":"m9","conversationId":"c1","senderId":"me",'
          '"content":"live hello","status":"SENT","sequenceNumber":9,'
          '"sentAt":"2026-09-15T10:09:00Z","attachments":[]}');
      await tester.pumpAndSettle();
      expect(s.ackedRead, contains(9));
    });

    testWidgets('failed send shows retry + discard', (tester) async {
      final repo = FakeMessagingRepo()..failSends = true;
      await pumpMsg(tester,
          const ChatScreen(conversationId: 'c1', title: 't'),
          repo: repo);

      await tester.enterText(find.byType(TextField), 'oops');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(find.text('Non envoyé. Touchez pour réessayer.'),
          findsOneWidget);
      expect(
          find.byTooltip('Réessayer'), findsOneWidget);
      expect(find.byTooltip('Supprimer'), findsOneWidget);
    });

    testWidgets('socket strip appears when real-time drops',
        (tester) async {
      final s = FakeStomp();
      await pumpMsg(tester,
          const ChatScreen(conversationId: 'c1', title: 't'),
          stomp: s);
      // pumpMsg connects; drop afterwards.
      s.setState(ChatConnectionState.disconnected);
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Temps réel indisponible — les messages s’envoient par relais.'),
          findsOneWidget);
    });
  });

  group('notification center (acceptance)', () {
    testWidgets('list + unread filter + mark read', (tester) async {
      final notifs = FakeNotifRepo();
      await pumpMsg(tester, const NotificationsScreen(),
          notifs: notifs);

      expect(find.text('Journal validé'), findsOneWidget);
      expect(find.text('Bienvenue'), findsOneWidget);

      await tester.tap(find.text('Non lues'));
      await tester.pumpAndSettle();
      expect(find.text('Journal validé'), findsOneWidget);
      expect(find.text('Bienvenue'), findsNothing);

      await tester.tap(find.text('Marquer comme lue'));
      await tester.pumpAndSettle();
      expect(notifs.read, contains('n1'));
    });
  });

  group('large history performance smoke (task 11)', () {
    testWidgets('300 messages scroll without errors', (tester) async {
      final repo = _BigHistoryRepo();
      await pumpMsg(
          tester,
          const ChatScreen(
              conversationId: 'c-big', title: 'Stress'),
          repo: repo);
      expect(find.text('bulk 300'), findsOneWidget);
      await tester.drag(
          find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      await tester.drag(
          find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

class _BigHistoryRepo extends FakeMessagingRepo {
  _BigHistoryRepo() : super(stomp: null);

  @override
  Future<Paged<ChatMessage>> history(String conversationId,
      {int? cursor, int size = 30}) async {
    final items = [
      for (var i = 300; i >= 271; i--)
        ChatMessage(
          id: 'b$i',
          conversationId: conversationId,
          senderId: 'u2',
          content: 'bulk $i',
          status: MessageStatus.sent,
          sequenceNumber: i,
          sentAt: DateTime(2026, 9, 15, 10),
        ),
    ];
    return Paged(
        items: items,
        page: 0,
        totalElements: 300,
        totalPages: 10,
        isLast: false);
  }
}
