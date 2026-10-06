import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/task_classification.dart';
import 'package:stegappe/features/internship/presentation/providers/classification_providers.dart';

void main() {
  group('TaskCategory model', () {
    test('known category keeps id, name, color and order', () {
      const cat = TaskCategory(
          id: 'c1', name: 'Frontend', colorToken: 'blue', position: 2);
      expect(cat.id, 'c1');
      expect(cat.name, 'Frontend');
      expect(cat.colorToken, 'blue');
      expect(cat.position, 2);
    });

    test('missing color stays null (uncolored category)', () {
      const cat = TaskCategory(id: 'c1', name: 'Docs');
      expect(cat.colorToken, isNull);
    });
  });

  group('classificationBoardFromJson (tolerant parse)', () {
    test('parses categories and assignments', () {
      final board = classificationBoardFromJson({
        'categories': [
          {'id': 'c1', 'name': 'Frontend', 'color': 'blue', 'position': 0},
          {'id': 'c2', 'name': 'Backend', 'color': null, 'position': 1},
        ],
        'assignments': {'t1': 'c1', 't2': 'c2'},
      });
      expect(board.categories.map((c) => c.name), ['Frontend', 'Backend']);
      expect(board.categoryOf('t1'), 'c1');
      expect(board.categoryOf('t3'), isNull);
      expect(board.categoryById('c2')?.name, 'Backend');
    });

    test('unknown future color token survives verbatim (never crashes)', () {
      final board = classificationBoardFromJson({
        'categories': [
          {'id': 'c9', 'name': 'Future', 'color': 'holographic', 'position': 0},
        ],
        'assignments': <String, dynamic>{},
      });
      expect(board.categories.single.colorToken, 'holographic');
    });

    test('malformed rows and pairs are skipped, never crash', () {
      final board = classificationBoardFromJson({
        'categories': [
          {'id': '', 'name': 'No id'},
          {'id': 'c1', 'name': '   '},
          {'id': 'c2', 'name': 'Ok'},
          'not-a-map',
          null,
        ],
        'assignments': {'t1': 'c2', '': 'c2', 't2': '', 't3': null},
      });
      expect(board.categories.map((c) => c.id), ['c2']);
      expect(board.assignments, {'t1': 'c2'});
    });

    test('non-map payload degrades to the empty board', () {
      expect(classificationBoardFromJson(null), ClassificationBoard.empty);
      expect(classificationBoardFromJson([]), ClassificationBoard.empty);
      expect(classificationBoardFromJson('nope'), ClassificationBoard.empty);
    });
  });

  group('categoryProposalFromJson', () {
    test('existing-category proposal parses with confidence', () {
      final p = categoryProposalFromJson({
        'taskId': 't1',
        'categoryId': 'c1',
        'confidence': 0.9,
      })!;
      expect(p.taskId, 't1');
      expect(p.categoryId, 'c1');
      expect(p.isNewCategory, isFalse);
      expect(p.confidence, 0.9);
      expect(
          p.displayName(const [TaskCategory(id: 'c1', name: 'Frontend')]),
          'Frontend');
    });

    test('new-name proposal is flagged and shown as new', () {
      final p = categoryProposalFromJson({
        'taskId': 't2',
        'newCategoryName': 'Docs',
      })!;
      expect(p.isNewCategory, isTrue);
      expect(p.displayName(const []), 'Docs');
      // Missing confidence defaults (never null, never NaN).
      expect(p.confidence, 0.5);
    });

    test('confidence outside 0..1 is clamped', () {
      expect(
          categoryProposalFromJson(
              {'taskId': 't', 'categoryId': 'c', 'confidence': 7})!
              .confidence,
          1.0);
      expect(
          categoryProposalFromJson(
              {'taskId': 't', 'categoryId': 'c', 'confidence': -2})!
              .confidence,
          0.0);
    });

    test('proposal without a task id is dropped', () {
      expect(categoryProposalFromJson({'categoryId': 'c'}), isNull);
      expect(categoryProposalFromJson(null), isNull);
      expect(categoryProposalsFromJson({'proposals': 'nope'}), isEmpty);
    });
  });

  group('applyResultsFromJson', () {
    test('parses per-item statuses; unknown values stay verbatim', () {
      final items = applyResultsFromJson({
        'items': [
          {'taskId': 't1', 'status': 'APPLIED', 'categoryId': 'c1'},
          {'taskId': 't2', 'status': 'SKIPPED_ALREADY_CLASSIFIED'},
          {'taskId': 't3', 'status': 'future_status_xyz'},
          {'taskId': ''},
        ],
      });
      expect(items.map((i) => i.taskId), ['t1', 't2', 't3']);
      expect(items.first.applied, isTrue);
      expect(items[1].applied, isFalse);
      // Unknown future statuses degrade (never silent success, never crash).
      expect(items[2].applied, isFalse);
      expect(items[2].status, 'FUTURE_STATUS_XYZ');
    });
  });

  group('ClassificationBoard helpers', () {
    const board = ClassificationBoard(
      categories: [TaskCategory(id: 'c1', name: 'Frontend')],
      assignments: {'t1': 'c1'},
    );

    test('only unclassified tasks are eligible for AI proposals', () {
      expect(board.unclassifiedIds(['t1', 't2', 't3']), ['t2', 't3']);
    });

    test('foreign task ids are ignored (never trusted blindly)', () {
      const proposals = [
        CategoryProposal(taskId: 't2', categoryId: 'c1'),
        CategoryProposal(taskId: 'foreign', categoryId: 'c1'),
      ];
      final valid = board.validProposals(proposals, {'t1', 't2'});
      expect(valid.map((p) => p.taskId), ['t2']);
    });
  });

  group('ClassificationFilter', () {
    test('matches all, unclassified-only, or one category', () {
      const all = ClassificationFilter.all();
      const unclassified = ClassificationFilter.unclassified();
      const cat = ClassificationFilter.category('c1');
      expect(all.matches('c1'), isTrue);
      expect(all.matches(null), isTrue);
      expect(unclassified.matches(null), isTrue);
      expect(unclassified.matches('c1'), isFalse);
      expect(cat.matches('c1'), isTrue);
      expect(cat.matches('c2'), isFalse);
      expect(cat.matches(null), isFalse);
    });
  });

  group('payload builders', () {
    test('assign payload carries the compare-and-set expectation', () {
      final json = assignCategoryJson(
          categoryId: 'c1', expectedCategoryId: null, force: false);
      expect(json['categoryId'], 'c1');
      expect(json, containsPair('expectedCategoryId', null));
      expect(json['force'], isFalse);
    });

    test('apply item omits absent references', () {
      final json = applyItemJson(taskId: 't1', categoryId: 'c1');
      expect(json['taskId'], 't1');
      expect(json.containsKey('newCategoryName'), isFalse);
    });
  });
}
