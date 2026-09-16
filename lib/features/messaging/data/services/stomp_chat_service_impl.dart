import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/token_storage.dart';
import 'stomp_chat_service.dart';

/// `stomp_dart_client`-backed implementation.
///
/// Resilience model:
/// - header maps are mutated inside `beforeConnect`, which runs before
///   EVERY dial (initial + library reconnects), so a token refreshed by
///   the REST 401 flow is always picked up — no stale-token reconnects;
/// - on each CONNECT we resubscribe every tracked destination and emit
///   [resyncRequested] (callers refetch missed frames via REST `cursor`);
/// - sends/acks throw [StateError] when offline so callers fall back to
///   REST or surface an honest retry — never silently dropped.
class StompChatServiceImpl implements StompChatService {
  StompChatServiceImpl({
    required this.tokens,
    String? wsBaseUrl,
    this.reconnectDelay = const Duration(seconds: 5),
  }) : _wsBaseUrl = wsBaseUrl ?? AppConfig.wsBaseUrl;

  final TokenStorage tokens;
  final String _wsBaseUrl;
  final Duration reconnectDelay;

  StompClient? _client;
  bool _disposed = false;

  final _stompHeaders = <String, String>{};
  final _wsHeaders = <String, dynamic>{};

  final _state =
      StreamController<ChatConnectionState>.broadcast();
  final _resync = StreamController<void>.broadcast();
  final _subs = <String, ChatFrameCallback>{};
  void Function(String code, String message)? _errorHandler;

  @override
  Stream<ChatConnectionState> get state => _state.stream;

  @override
  ChatConnectionState currentState = ChatConnectionState.disconnected;

  @override
  Stream<void> get resyncRequested => _resync.stream;

  void _emit(ChatConnectionState s) {
    currentState = s;
    if (!_state.isClosed) _state.add(s);
  }

  @override
  Future<void> ensureConnected() async {
    if (_disposed) return;
    if (_client != null &&
        (currentState == ChatConnectionState.connected ||
            currentState == ChatConnectionState.connecting)) {
      return;
    }
    _emit(ChatConnectionState.connecting);
    _client?.deactivate();
    _client = StompClient(
      config: StompConfig(
        url: '$_wsBaseUrl/ws',
        reconnectDelay: reconnectDelay,
        stompConnectHeaders: _stompHeaders,
        webSocketConnectHeaders: _wsHeaders,
        beforeConnect: () async {
          final token = await tokens.readAccessToken();
          if (token == null || token.isEmpty) {
            throw StateError('missing access token for WS');
          }
          _stompHeaders['Authorization'] = 'Bearer $token';
          _wsHeaders['Authorization'] = 'Bearer $token';
          await Future<void>.delayed(Duration.zero);
        },
        onConnect: (_) => _onConnect(),
        onDisconnect: (_) =>
            _emit(ChatConnectionState.disconnected),
        onStompError: (_) =>
            _emit(ChatConnectionState.disconnected),
        onWebSocketError: (_) =>
            _emit(ChatConnectionState.disconnected),
      ),
    );
    _client!.activate();
  }

  void _onConnect() {
    if (_disposed) return;
    _emit(ChatConnectionState.connected);
    final client = _client;
    if (client == null) return;
    for (final entry in _subs.entries) {
      client.subscribe(
          destination: entry.key,
          callback: (f) => entry.value(f.body ?? ''));
    }
    if (_errorHandler != null) {
      client.subscribe(
          destination: '/user/queue/errors',
          callback: (f) => _handleErrorFrame(f.body ?? ''));
    }
    if (!_resync.isClosed) _resync.add(null);
  }

  void _handleErrorFrame(String body) {
    final handler = _errorHandler;
    if (handler == null) return;
    try {
      final map = jsonDecode(body);
      if (map is Map<String, dynamic>) {
        handler((map['code'] ?? '').toString(),
            (map['message'] ?? '').toString());
        return;
      }
    } on Exception {
      // Fall through to raw body.
    }
    handler('UNKNOWN', body);
  }

  StompClient _requireClient() {
    final client = _client;
    if (client == null ||
        currentState != ChatConnectionState.connected) {
      throw StateError('STOMP not connected');
    }
    return client;
  }

  @override
  Future<void Function()> subscribeConversation(
      String conversationId, ChatFrameCallback onFrame) async {
    final dest = '/topic/conversations/$conversationId';
    _subs[dest] = onFrame;
    final client = _client;
    if (client != null &&
        currentState == ChatConnectionState.connected) {
      client.subscribe(
          destination: dest,
          callback: (f) => onFrame(f.body ?? ''));
    } else {
      await ensureConnected();
    }
    return () {
      _subs.remove(dest);
    };
  }

  @override
  Future<void> subscribeNotifications(
      ChatFrameCallback onPayload) async {
    const dest = '/user/queue/notifications';
    _subs[dest] = onPayload;
    final client = _client;
    if (client != null &&
        currentState == ChatConnectionState.connected) {
      client.subscribe(
          destination: dest,
          callback: (f) => onPayload(f.body ?? ''));
    } else {
      await ensureConnected();
    }
  }

  @override
  Future<void> subscribeErrors(
      void Function(String code, String message) onError) async {
    _errorHandler = onError;
    final client = _client;
    if (client != null &&
        currentState == ChatConnectionState.connected) {
      client.subscribe(
          destination: '/user/queue/errors',
          callback: (f) => _handleErrorFrame(f.body ?? ''));
    } else {
      await ensureConnected();
    }
  }

  @override
  Future<void> sendMessage(
      String conversationId, String content) async {
    _requireClient().send(
      destination: '/app/conversations/$conversationId/send',
      body: jsonEncode({'content': content}),
    );
  }

  @override
  Future<void> ackDelivered(
      String conversationId, int upToSequence) async {
    _requireClient().send(
      destination:
          '/app/conversations/$conversationId/delivered',
      body: jsonEncode({'upToSequenceNumber': upToSequence}),
    );
  }

  @override
  Future<void> ackRead(
      String conversationId, int upToSequence) async {
    _requireClient().send(
      destination: '/app/conversations/$conversationId/read',
      body: jsonEncode({'upToSequenceNumber': upToSequence}),
    );
  }

  @override
  Future<void> disconnect() async {
    _disposed = true;
    _subs.clear();
    _errorHandler = null;
    _client?.deactivate();
    _client = null;
    _emit(ChatConnectionState.disconnected);
    await _state.close();
    await _resync.close();
  }
}
