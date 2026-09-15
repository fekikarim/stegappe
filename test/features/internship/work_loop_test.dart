import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/data/cache/composer_draft_store.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';

void main() {
  group('write payloads mirror the OpenAPI DTOs', () {
    test('taskWriteJson uses yyyy-MM-dd and API enums', () {
      final json = taskWriteJson(
        title: '  Setup  ',
        description: 'env',
        dueDate: DateTime(2026, 9, 20),
        status: TaskStatus.inProgress,
      );
      expect(json['title'], '  Setup  ');
      expect(json['dueDate'], '2026-09-20');
      expect(json['status'], 'IN_PROGRESS');
    });

    test('taskWriteJson omits nulls', () {
      final json = taskWriteJson(title: 't');
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('dueDate'), isFalse);
      expect(json.containsKey('status'), isFalse);
    });

    test('journalWriteJson always carries entryDate', () {
      final json = journalWriteJson(
          title: 'Day 3',
          description: 'Did X',
          entryDate: DateTime(2026, 9, 15, 23, 59));
      expect(json['entryDate'], '2026-09-15');
    });
  });

  group('composer draft keys', () {
    test('key is namespaced per internship + day', () {
      final a = composerDraftKey('i1', DateTime(2026, 9, 15));
      final b = composerDraftKey('i1', DateTime(2026, 9, 16));
      final c = composerDraftKey('i2', DateTime(2026, 9, 15));
      expect(a, isNot(equals(b)));
      expect(a, isNot(equals(c)));
      expect(a, contains('2026-09-15'));
    });
  });

  group('MemoryComposerDraftStore', () {
    test('save/load/clear round-trip', () async {
      final store = MemoryComposerDraftStore();
      final day = DateTime(2026, 9, 15);
      expect(await store.load('i1', day), isNull);

      await store.save(
          'i1',
          day,
          ComposerDraft(
              title: 'T',
              description: 'D',
              updatedAt: DateTime(2026, 9, 15, 10)));
      final loaded = await store.load('i1', day);
      expect(loaded?.title, 'T');
      expect(loaded?.description, 'D');

      await store.clear('i1', day);
      expect(await store.load('i1', day), isNull);
    });

    test('ComposerDraft serialization round-trip', () {
      const d = ComposerDraft(title: 'T', description: 'D');
      expect(ComposerDraft.fromJson(d.toJson()).title, 'T');
      expect(const ComposerDraft().isEmpty, isTrue);
    });
  });
}
