import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/offline/pending_write_store.dart';
import 'package:stegappe/core/storage/prefs_store.dart';

/// Store-level guarantees: tolerant codec, FIFO order, bound, persistence
/// across restarts, and logout wipe. No socket, no network.
void main() {
  Future<PendingWriteStore> freshStore() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return PendingWriteStore(PrefsStore(prefs));
  }

  /// Reopens the SAME mock storage (no reset) to prove restart persistence.
  Future<PendingWriteStore> reopenStore() async {
    final prefs = await SharedPreferences.getInstance();
    return PendingWriteStore(PrefsStore(prefs));
  }

  PendingWrite write(String key, {String task = 't1'}) => PendingWrite(
        key: key,
        kind: PendingWriteKind.taskStatus,
        taskId: task,
        targetStatus: 'COMPLETED',
        createdAtMs: 1,
      );

  group('PendingWrite codec', () {
    test('round-trips both kinds', () {
      const status = PendingWrite(
        key: 'k1',
        kind: PendingWriteKind.taskStatus,
        taskId: 't1',
        targetStatus: 'IN_PROGRESS',
        createdAtMs: 7,
        attempts: 2,
      );
      expect(PendingWrite.fromJson(status.toJson()), status);

      const message = PendingWrite(
        key: 'k2',
        kind: PendingWriteKind.message,
        conversationId: 'c1',
        content: 'hello',
        localId: 'p1',
        createdAtMs: 8,
      );
      expect(PendingWrite.fromJson(message.toJson()), message);
    });

    test('corrupt rows degrade to null (skipped, never crash)', () {
      expect(PendingWrite.fromJson(null), isNull);
      expect(PendingWrite.fromJson('nope'), isNull);
      expect(PendingWrite.fromJson({'kind': 'taskStatus'}), isNull);
      expect(
          PendingWrite.fromJson(
              {'key': 'k', 'kind': 'nope', 'taskId': 't'}),
          isNull);
      expect(
          PendingWrite.fromJson({
            'key': 'k',
            'kind': 'taskStatus',
            'taskId': 't',
          }),
          isNull);
      expect(
          PendingWrite.fromJson({
            'key': 'k',
            'kind': 'message',
            'conversationId': 'c',
          }),
          isNull);
    });
  });

  group('PendingWriteStore', () {
    test('persists across restarts in insertion order', () async {
      final first = await freshStore();
      await first.push(write('k1'));
      await first.push(write('k2', task: 't2'));

      final second = await reopenStore();
      expect(
          second.load().map((w) => w.key), orderedEquals(['k1', 'k2']));
    });

    test('corrupt storage degrades to empty', () async {
      SharedPreferences.setMockInitialValues({
        PendingWriteStore.storageKey: '[[broken',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(PendingWriteStore(PrefsStore(prefs)).load(), isEmpty);
    });

    test('bound refuses the 51st push (honest, never silent drop)',
        () async {
      final s = await freshStore();
      for (var i = 0; i < PendingWriteStore.maxItems; i++) {
        expect(await s.push(write('k$i')), isTrue);
      }
      expect(await s.push(write('overflow')), isFalse);
      expect(s.load(), hasLength(PendingWriteStore.maxItems));
    });

    test('remove/replace/clear behave', () async {
      final s = await freshStore();
      await s.push(write('k1'));
      await s.push(write('k2'));
      await s.remove('k1');
      expect(s.load().map((w) => w.key), ['k2']);
      await s.replace(write('k2').withAttempts(3));
      expect(s.load().single.attempts, 3);
      await s.clear();
      expect(s.load(), isEmpty);
    });
  });
}
