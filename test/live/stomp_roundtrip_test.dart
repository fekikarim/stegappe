import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stegappe/core/network/api_client.dart';
import 'package:stegappe/core/storage/token_storage.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service.dart';
import 'package:stegappe/features/messaging/data/services/stomp_chat_service_impl.dart';

/// LIVE integration test against a local backend.
/// Runs only with `--dart-define=LIVE_BACKEND=true` (CI-safe skip),
/// e.g. `flutter test test/live --dart-define=LIVE_BACKEND=true`.
/// Proves, with the app's real transport:
///  1. JWT-authenticated STOMP handshake + topic subscribe;
///  2. STOMP send → server persist → broadcast echo (round trip);
///  3. REST send → broadcast received (simulates the second device);
///  4. unauthorized conversation access rejected (error frame, no leak).
const _live =
    bool.fromEnvironment('LIVE_BACKEND', defaultValue: false);
const _httpBase = 'http://localhost:8080';
const _wsBase = 'ws://localhost:8080';
const _email = 'supervisor.steg@steg.tn';
const _password = 'Supervisor#2026';

Future<String> _login(ApiClient client) async {
  final tokens = await client.post(
    '/api/auth/login',
    body: {'email': _email, 'password': _password},
    decode: (j) => (j as Map<String, dynamic>)['accessToken'] as String,
  );
  return tokens;
}

Future<String> _makeGroup(ApiClient client, String bearer) async {
  final conv = await client.post(
    '/api/conversations/group',
    bearer: bearer,
    body: {'title': 'Live QA ${DateTime.now().millisecondsSinceEpoch}'},
    decode: (j) => (j as Map<String, dynamic>)['id'] as String,
  );
  return conv;
}

void main() {
  test(
    'STOMP round trip against the live backend',
    () async {
      final httpClient = http.Client();
      addTearDown(httpClient.close);
      final api =
          ApiClient(baseUrl: _httpBase, httpClient: httpClient);
      addTearDown(api.close);

      final access = await _login(api);
      final tokens = InMemoryTokenStorage();
      await tokens.saveTokens(
          accessToken: access, refreshToken: 'live-unused');
      final stomp = StompChatServiceImpl(
        tokens: tokens,
        wsBaseUrl: _wsBase,
        reconnectDelay: Duration.zero,
      );
      addTearDown(stomp.disconnect);

      final convId = await _makeGroup(api, access);

      final received = StreamController<String>.broadcast();
      addTearDown(received.close);
      final errors = <String>[];
      await stomp.ensureConnected();
      // Wait for CONNECT (library dials asynchronously).
      final deadline =
          DateTime.now().add(const Duration(seconds: 10));
      while (stomp.currentState !=
              ChatConnectionState.connected &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(
            const Duration(milliseconds: 100));
      }
      expect(stomp.currentState, ChatConnectionState.connected);

      await stomp.subscribeConversation(convId, received.add);
      await stomp.subscribeErrors(
          (code, message) => errors.add('$code:$message'));
      await Future<void>.delayed(
          const Duration(milliseconds: 500));

      // 1. STOMP send → broadcast echo (listen BEFORE sending:
      //    broadcast streams never replay).
      const marker =
          'live-stomp-probe-${0xC0FFEE}';
      final echoFuture = received.stream
          .map((b) => jsonDecode(b) as Map<String, dynamic>)
          .firstWhere(
              (m) => (m['content'] ?? '').toString().contains(marker));
      await stomp.sendMessage(convId, 'hello $marker');
      final echo =
          await echoFuture.timeout(const Duration(seconds: 10));
      expect(echo['conversationId'], convId);
      expect(echo['sequenceNumber'], isA<int>());

      // 2. REST send (second device) → broadcast received here.
      const marker2 = 'live-rest-probe-4451';
      final echo2Future = received.stream
          .map((b) => jsonDecode(b) as Map<String, dynamic>)
          .firstWhere(
              (m) => (m['content'] ?? '').toString().contains(marker2));

      await api.post(
        '/api/conversations/$convId/messages',
        bearer: access,
        body: {'content': 'hello $marker2'},
        decode: (_) {},
      );
      final echo2 =
          await echo2Future.timeout(const Duration(seconds: 10));
      expect(echo2['sequenceNumber'], isA<int>());

      // 3. Unauthorized conversation: REST 403 (no leak).
      try {
        await api.post(
          '/api/conversations/00000000-0000-0000-0000-000000000000/messages',
          bearer: access,
          body: {'content': 'x'},
          decode: (_) {},
        );
        fail('expected rejection for unknown conversation');
      } on Exception catch (e) {
        expect(e.toString(), contains('403'));
      }

      // 4. Unauthorized STOMP send → error frame, no broadcast.
      await stomp.sendMessage(
          '00000000-0000-0000-0000-000000000000', 'intrude');
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
          errors.any((e) =>
              e.startsWith('ACCESS_DENIED') ||
              e.startsWith('NOT_FOUND')),
          isTrue,
          reason: 'expected ACCESS_DENIED/NOT_FOUND, got $errors');
    },
    skip: !_live
        ? 'needs a local backend: flutter test test/live --dart-define=LIVE_BACKEND=true'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
