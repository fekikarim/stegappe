import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../storage/prefs_store.dart';

/// T06/D12 persisted offline write queue (BR-56, BR-58).
///
/// Only two write kinds are ever queued — task status changes and message
/// sends — each carrying a client-generated idempotency key the backend
/// replays safely (`X-Idempotency-Key`). Everything else (AI, drafts,
/// submissions, reviews, bulk) stays online-only and fails fast.
///
/// Token-free by construction: entries hold ids, content and keys — never
/// tokens. Wiped on logout and on auth-failure discard.
enum PendingWriteKind { taskStatus, message }

class PendingWrite extends Equatable {
  const PendingWrite({
    required this.key,
    required this.kind,
    this.taskId,
    this.targetStatus,
    this.conversationId,
    this.content,
    this.localId,
    required this.createdAtMs,
    this.attempts = 0,
  });

  /// Idempotency key: one fresh UUID per logical write, reused only for
  /// retries of that same write (T06 §10).
  final String key;
  final PendingWriteKind kind;

  /// Task-status writes: backend status name (`COMPLETED`, …).
  final String? taskId;
  final String? targetStatus;

  /// Message writes.
  final String? conversationId;
  final String? content;

  /// Links a queued message to its on-screen pending bubble.
  final String? localId;
  final int createdAtMs;
  final int attempts;

  PendingWrite withAttempts(int value) => PendingWrite(
        key: key,
        kind: kind,
        taskId: taskId,
        targetStatus: targetStatus,
        conversationId: conversationId,
        content: content,
        localId: localId,
        createdAtMs: createdAtMs,
        attempts: value,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'kind': kind.name,
        'taskId': taskId,
        'targetStatus': targetStatus,
        'conversationId': conversationId,
        'content': content,
        'localId': localId,
        'createdAtMs': createdAtMs,
        'attempts': attempts,
      };

  /// Tolerant decode: a corrupt row degrades to null and is skipped, never
  /// a crash, never a half-applied write.
  static PendingWrite? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final key = json['key']?.toString() ?? '';
    final kindRaw = json['kind']?.toString() ?? '';
    if (key.isEmpty) return null;
    final kind = PendingWriteKind.values
        .where((k) => k.name == kindRaw)
        .firstOrNull;
    if (kind == null) return null;
    if (kind == PendingWriteKind.taskStatus &&
        ((json['taskId']?.toString() ?? '').isEmpty ||
            (json['targetStatus']?.toString() ?? '').isEmpty)) {
      return null;
    }
    if (kind == PendingWriteKind.message &&
        ((json['conversationId']?.toString() ?? '').isEmpty ||
            (json['content']?.toString() ?? '').isEmpty)) {
      return null;
    }
    return PendingWrite(
      key: key,
      kind: kind,
      taskId: json['taskId']?.toString(),
      targetStatus: json['targetStatus']?.toString(),
      conversationId: json['conversationId']?.toString(),
      content: json['content']?.toString(),
      localId: json['localId']?.toString(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        key,
        kind,
        taskId,
        targetStatus,
        conversationId,
        content,
        localId,
        createdAtMs,
        attempts,
      ];
}

/// Persisted, bounded FIFO of [PendingWrite] backed by [PrefsStore].
///
/// Ordering is insertion order (server timestamps decide truth on merge;
/// device clocks are never used for ordering). Bounded: pushes past
/// [maxItems] are refused so the queue — and its UI count — stays honest.
class PendingWriteStore {
  PendingWriteStore(this._prefs);

  static const storageKey = 'steg.pending_writes.v1';

  /// Visible bound (T06 edge case: 50+ items show a count + manual flush).
  static const maxItems = 50;

  final PrefsStore _prefs;

  List<PendingWrite> load() {
    final raw = _prefs.readRaw(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <PendingWrite>[];
      for (final e in decoded) {
        final w = PendingWrite.fromJson(e);
        if (w != null) out.add(w);
      }
      return out;
    } on Exception {
      return const [];
    }
  }

  Future<void> save(List<PendingWrite> items) =>
      _prefs.writeRaw(storageKey,
          jsonEncode([for (final w in items) w.toJson()]));

  /// Returns false when the bound refuses the push (caller shows
  /// `queueFull` instead of silently dropping).
  Future<bool> push(PendingWrite write) async {
    final items = load();
    if (items.length >= maxItems) return false;
    await save([...items, write]);
    return true;
  }

  Future<void> remove(String key) async {
    final items = load();
    await save([for (final w in items) if (w.key != key) w]);
  }

  Future<void> replace(PendingWrite write) async {
    final items = load();
    await save([
      for (final w in items)
        if (w.key == write.key) write else w,
    ]);
  }

  Future<void> clear() => _prefs.removeRaw(storageKey);
}
