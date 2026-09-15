import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';

List<EvaluationCriterion> criteria() => const [
      EvaluationCriterion(
          id: 'c-tech',
          templateId: 't1',
          name: 'Technique',
          weight: 60,
          maxScore: 20),
      EvaluationCriterion(
          id: 'c-soft',
          templateId: 't1',
          name: 'Comportement',
          weight: 40,
          maxScore: 20),
    ];

void main() {
  group('estimateTotal mirrors the backend formula', () {
    test('weighted average scaled to /20', () {
      // (15/20*60 + 15/20*40) / 100 * 20 = 15.0
      expect(
          estimateTotal(
              {'c-tech': 15, 'c-soft': 15}, criteria()),
          15.0);
    });

    test('partial scoring uses scored weights only', () {
      // (20/20*60) / 60 * 20 = 20.0
      expect(
          estimateTotal({'c-tech': 20}, criteria()), 20.0);
    });

    test('null when nothing scorable', () {
      expect(estimateTotal({}, criteria()), isNull);
      expect(
          estimateTotal(
              {'c-tech': 10},
              const [
                EvaluationCriterion(
                    id: 'c-tech',
                    templateId: 't',
                    name: 'x',
                    weight: 0,
                    maxScore: 20),
              ]),
          isNull);
    });

    test('zero maxScore criteria are skipped like the backend', () {
      expect(
          estimateTotal(
              {'c-tech': 15, 'c-bad': 99},
              [
                ...criteria(),
                const EvaluationCriterion(
                    id: 'c-bad',
                    templateId: 't',
                    name: 'bad',
                    weight: 50,
                    maxScore: 0),
              ]),
          15.0);
    });

    test('HALF_UP rounding to 2 decimals', () {
      // 10/20*1 + 10/20*1 + 10/20*1 over weights 1,1,1 → 10.0
      const cs = [
        EvaluationCriterion(
            id: 'a', templateId: 't', name: 'a', weight: 1, maxScore: 3),
        EvaluationCriterion(
            id: 'b', templateId: 't', name: 'b', weight: 1, maxScore: 3),
        EvaluationCriterion(
            id: 'c', templateId: 't', name: 'c', weight: 1, maxScore: 3),
      ];
      // (1/3 + 1/3 + 1/3)/3*20 = 6.666... → 6.67
      expect(estimateTotal({'a': 1, 'b': 1, 'c': 1}, cs), 6.67);
    });
  });

  group('evaluation payloads', () {
    test('evaluationWriteJson carries backend field names', () {
      final json = evaluationWriteJson(
          templateId: 't1',
          kind: EvaluationKind.weekly,
          date: DateTime(2026, 9, 15),
          feedback: 'Bien');
      expect(json['templateId'], 't1');
      expect(json['type'], 'WEEKLY');
      expect(json['evaluationDate'], '2026-09-15');
      expect(json['feedback'], 'Bien');
    });

    test('score/task-review payloads omit empty optionals', () {
      final s = scoreWriteJson(criterionId: 'c', score: 12);
      expect(s.containsKey('comment'), isFalse);
      final r = taskReviewWriteJson(taskId: 't', completed: true);
      expect(r, {'taskId': 't', 'completed': true});
    });
  });

  group('evaluationKindFrom', () {
    test('unknown maps to custom, never throws', () {
      expect(evaluationKindFrom('WEEKLY'), EvaluationKind.weekly);
      expect(evaluationKindFrom('MID_TERM'), EvaluationKind.midTerm);
      expect(evaluationKindFrom('whatever'), EvaluationKind.custom);
      expect(evaluationKindFrom(null), EvaluationKind.custom);
    });
  });
}
