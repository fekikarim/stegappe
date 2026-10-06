import 'dart:async';

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
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/domain/repositories/notification_repository.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:stegappe/features/messaging/presentation/screens/notifications_screen.dart';

/// Server-state fake: rows and failures are configurable per test, and every
/// call is recorded so a test can assert the screen asked the *server* the
/// right question (filter, size) instead of filtering a stale page locally.
class FakeNotificationsRepository implements NotificationRepository {
  FakeNotificationsRepository({
    List<NotificationItem>? items,
    this.unread = 0,
  }) : items = items ?? const [];

  List<NotificationItem> items;
  int unread;
  bool failList = false;
  bool failRead = false;
  bool failReadAll = false;
  bool failUnreadCount = false;

  final List<String> read = [];
  int readAllCalls = 0;
  final List<({int size, bool unreadOnly})> queries = [];

  @override
  Future<Paged<NotificationItem>> list({
    int page = 0,
    int size = 20,
    bool unreadOnly = false,
  }) async {
    queries.add((size: size, unreadOnly: unreadOnly));
    if (failList) throw Exception('list failed');
    final shown = unreadOnly
        ? [for (final n in items) if (!n.isRead) n]
        : items;
    return Paged(
      items: shown,
      page: 0,
      totalElements: shown.length,
      totalPages: 1,
      isLast: true,
    );
  }

  @override
  Future<int> unreadCount() async {
    if (failUnreadCount) throw Exception('count failed');
    return unread;
  }

  @override
  Future<void> markRead(String id) async {
    if (failRead) throw Exception('read failed');
    read.add(id);
    items = [
      for (final n in items)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  @override
  Future<void> markAllRead() async {
    readAllCalls++;
    if (failReadAll) throw Exception('mark-all failed');
    items = [for (final n in items) n.copyWith(isRead: true)];
  }
}

/// Controllable socket (state + resync only — notification frames travel
/// through the app's session-wide sink, so a test injects them there).
class FakeStompService implements StompChatService {
  ChatConnectionState _state = ChatConnectionState.disconnected;
  final _stateCtrl = StreamController<ChatConnectionState>.broadcast();
  final _resyncCtrl = StreamController<void>.broadcast();

  void setState(ChatConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
    if (s == ChatConnectionState.connected) _resyncCtrl.add(null);
  }

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
    String conversationId,
    ChatFrameCallback onFrame,
  ) async =>
      () {};

  @override
  Future<void> subscribeNotifications(ChatFrameCallback onPayload) async {}

  @override
  Future<void> subscribeErrors(
    void Function(String code, String message) onError,
  ) async {}

  @override
  Future<void> sendMessage(String conversationId, String content) async {}

  @override
  Future<void> ackDelivered(String conversationId, int upToSequence) async {}

  @override
  Future<void> ackRead(String conversationId, int upToSequence) async {}
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<AppUser> login({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async =>
      const AppUser(id: 'me', email: 'intern@u.tn', roles: ['INTERN']);
}

/// Row factory mirroring the backend wire payload (`NotificationResponse`).
NotificationItem notif(
  String id, {
  NotificationType type = NotificationType.unknown,
  String title = 'Titre',
  String message = 'Message',
  String priority = 'NORMAL',
  DateTime? createdAt,
  bool isRead = false,
  String? entity,
  String? entityId,
}) =>
    NotificationItem(
      id: id,
      title: title,
      message: message,
      priority: priority,
      createdAt: createdAt ?? DateTime.now(),
      isRead: isRead,
      type: type,
      relatedEntityType: entity,
      relatedEntityId: entityId,
    );

/// Raw `/user/queue/notifications` frame (`NotificationPayload`).
String frame(
  String id, {
  String? type,
  String title = 'Live',
  String message = 'Message direct',
  DateTime? createdAt,
}) =>
    '{"notificationId":"$id",'
    '${type == null ? '' : '"type":"$type",'}'
    '"title":"$title","message":"$message","priority":"HIGH",'
    '"relatedEntityType":"Task","relatedEntityId":"t1",'
    '"createdAt":"${(createdAt ?? DateTime.now()).toUtc().toIso8601String()}"}';

/// Pumps the notification center the way the shell opens it (pushed as a
/// route from a launcher so the deep-link pop is real) and returns the
/// container for frame injection.
Future<ProviderContainer> pumpNotifications(
  WidgetTester tester, {
  FakeNotificationsRepository? repo,
  FakeStompService? stomp,
  ValueChanged<int>? onOpenTab,
}) async {
  final socket = stomp ?? FakeStompService();
  socket.setState(ChatConnectionState.connected);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        notificationRepositoryProvider.overrideWithValue(
          repo ?? FakeNotificationsRepository(),
        ),
        stompChatServiceProvider.overrideWithValue(socket),
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
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        NotificationsScreen(onOpenTab: onOpenTab),
                  ),
                ),
                child: const Text('open-notifications'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final container = ProviderScope.containerOf(
    tester.element(find.text('open-notifications')),
  );
  await container.read(authControllerProvider.notifier).bootstrap();
  await tester.tap(find.text('open-notifications'));
  await tester.pumpAndSettle();
  return container;
}
