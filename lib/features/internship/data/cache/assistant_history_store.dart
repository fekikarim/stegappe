import 'dart:convert';

import '../../../../core/storage/prefs_store.dart';
import '../../domain/entities/assistant.dart';

/// Local assistant conversation history, keyed by user id (T11).
///
/// The participant assistant path has no server history endpoint, so the
/// conversation survives restarts here instead of a new backend contract.
/// Bounded (newest 100 rows) so a long chat cannot grow storage without
/// limit. Wiped on logout by the shell gate — one user's questions must
/// never leak into the next session on a shared device. Question/answer
/// text is user content, never a secret, but it is still local-only.
abstract class AssistantHistoryStore {
  static const int maxRows = 100;

  Future<List<AssistantMessage>> load(String userId);
  Future<void> save(String userId, List<AssistantMessage> messages);
  Future<void> clear(String userId);
}

String assistantHistoryKey(String userId) => 'steg.assistant_history.$userId';

List<AssistantMessage> boundAssistantRows(List<AssistantMessage> messages) =>
    messages.length <= AssistantHistoryStore.maxRows
        ? messages
        : messages.sublist(messages.length - AssistantHistoryStore.maxRows);

class PrefsAssistantHistoryStore implements AssistantHistoryStore {
  PrefsAssistantHistoryStore(this._prefs);

  final PrefsStore _prefs;

  @override
  Future<List<AssistantMessage>> load(String userId) async {
    final raw = _prefs.readRaw(assistantHistoryKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map<String, dynamic>) AssistantMessage.fromJson(e),
      ];
    } on Exception {
      return const [];
    }
  }

  @override
  Future<void> save(String userId, List<AssistantMessage> messages) =>
      _prefs.writeRaw(assistantHistoryKey(userId),
          jsonEncode([for (final m in boundAssistantRows(messages)) m.toJson()]));

  @override
  Future<void> clear(String userId) =>
      _prefs.removeRaw(assistantHistoryKey(userId));
}

/// In-memory fake for tests.
class MemoryAssistantHistoryStore implements AssistantHistoryStore {
  final _map = <String, List<AssistantMessage>>{};

  @override
  Future<List<AssistantMessage>> load(String userId) async =>
      List.of(_map[userId] ?? const []);

  @override
  Future<void> save(String userId, List<AssistantMessage> messages) async {
    _map[userId] = List.of(boundAssistantRows(messages));
  }

  @override
  Future<void> clear(String userId) async => _map.remove(userId);

  Map<String, List<AssistantMessage>> get snapshot => _map;
}
