import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/features/internship/domain/entities/task_classification.dart';
import 'package:stegappe/features/internship/presentation/providers/classification_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';

import '../../test_fixtures.dart';

ProviderContainer _container(FakeInternshipRepository fake) =>
    ProviderContainer(overrides: [
      internshipRepositoryProvider.overrideWithValue(fake),
    ]);

void main() {
  group('classificationBoardProvider', () {
    test('loads categories and assignments from the server', () async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = const ClassificationBoard(
          categories: [TaskCategory(id: 'c1', name: 'Frontend')],
          assignments: {'t-today': 'c1'},
        );
      final container = _container(fake);
      addTearDown(container.dispose);

      final board = await container.read(classificationBoardProvider.future);
      expect(board.categories.map((c) => c.name), ['Frontend']);
      expect(board.categoryOf('t-today'), 'c1');
      expect(board.categoryOf('t-week'), isNull);
    });

    test('classification is independent from workflow status', () async {
      // The board carries no status at all: assigning a category cannot
      // move a task through the workflow by construction.
      final fake = FakeInternshipRepository()
        ..fakeBoard = const ClassificationBoard(
          categories: [TaskCategory(id: 'c1', name: 'Frontend')],
          assignments: {},
        );
      final container = _container(fake);
      addTearDown(container.dispose);

      await container.read(classificationBoardProvider.future);
      await fake.assignTaskCategory('t-today', categoryId: 'c1');
      final tasks = await fake.listTasks('internship-1');
      final toggled =
          tasks.items.firstWhere((t) => t.id == 't-today');
      // The fake mirrors the server rule: status untouched by classification.
      expect(toggled.status.name, isNot('approved'));
      expect(fake.fakeBoard.categoryOf('t-today'), 'c1');
    });
  });

  group('SuggestionFlowController', () {
    test('accepting one proposal affects only that task', () async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = const ClassificationBoard(
          categories: [TaskCategory(id: 'c1', name: 'Frontend')],
          assignments: {},
        )
        ..fakeProposals = const [
          CategoryProposal(taskId: 't-today', categoryId: 'c1'),
          CategoryProposal(taskId: 't-week', categoryId: 'c1'),
        ]
        ..fakeUnclassifiedCount = 2;
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller =
          container.read(suggestionFlowProvider.notifier);

      await controller.load();
      expect(container.read(suggestionFlowProvider).proposals.length, 2);

      await controller.acceptOne(
          const CategoryProposal(taskId: 't-today', categoryId: 'c1'));
      final state = container.read(suggestionFlowProvider);
      expect(state.acceptedTaskIds, {'t-today'});
      expect(fake.appliedItems.length, 1);
      expect(fake.appliedItems.single['taskId'], 't-today');
      expect(state.lastBatchId, isNotNull);
    });

    test('accept-all affects only valid proposals (rejected lines skipped)',
        () async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = const ClassificationBoard(
          categories: [TaskCategory(id: 'c1', name: 'Frontend')],
          assignments: {},
        )
        ..fakeProposals = const [
          CategoryProposal(taskId: 't-today', categoryId: 'c1'),
          CategoryProposal(taskId: 't-week', categoryId: 'c1'),
        ];
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller =
          container.read(suggestionFlowProvider.notifier);

      await controller.load();
      await controller.acceptAll();
      expect(fake.appliedItems.length, 2);
      expect(
          container.read(suggestionFlowProvider).acceptedTaskIds,
          {'t-today', 't-week'});
    });

    test('AI failure keeps an explicit error and preserves the board',
        () async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = const ClassificationBoard(
          categories: [TaskCategory(id: 'c1', name: 'Frontend')],
          assignments: {},
        )
        ..failSuggest = true;
      final container = _container(fake);
      addTearDown(container.dispose);

      await container.read(classificationBoardProvider.future);
      await container.read(suggestionFlowProvider.notifier).load();
      final state = container.read(suggestionFlowProvider);
      expect(state.error, isNotNull);
      expect(state.proposals, isEmpty);
      // The board the student already had is untouched.
      final board = container.read(classificationBoardProvider).valueOrNull;
      expect(board?.categories.map((c) => c.name), ['Frontend']);
    });

    test('double invocation is guarded (second load is a no-op)', () async {
      final gate = Completer<void>();
      final fake = FakeInternshipRepository()
        ..fakeBoard = const ClassificationBoard(
          categories: [TaskCategory(id: 'c1', name: 'Frontend')],
          assignments: {},
        )
        ..suggestGate = gate;
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller =
          container.read(suggestionFlowProvider.notifier);

      final first = controller.load();
      final second = controller.load();
      gate.complete();
      await first;
      await second;
      expect(fake.suggestCalls, 1);
    });

    test('accept-all while accepting is guarded', () async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = const ClassificationBoard(
          categories: [TaskCategory(id: 'c1', name: 'Frontend')],
          assignments: {},
        )
        ..fakeProposals = const [
          CategoryProposal(taskId: 't-today', categoryId: 'c1'),
        ];
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller =
          container.read(suggestionFlowProvider.notifier);

      await controller.load();
      await Future.wait([controller.acceptAll(), controller.acceptAll()]);
      expect(fake.applyCalls, 1);
    });

    test('undo replays through the backend and refreshes', () async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = const ClassificationBoard(
          categories: [TaskCategory(id: 'c1', name: 'Frontend')],
          assignments: {},
        )
        ..fakeProposals = const [
          CategoryProposal(taskId: 't-today', categoryId: 'c1'),
        ];
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller =
          container.read(suggestionFlowProvider.notifier);

      await controller.load();
      await controller.acceptAll();
      final batchId =
          container.read(suggestionFlowProvider).lastBatchId;
      expect(batchId, isNotNull);
      await controller.undo();
      expect(fake.undoneBatches, [batchId]);
    });

    test('unauthorized AI response is stored raw for the localized UI',
        () async {
      final fake = _ForbiddenSuggestFake();
      final container = _container(fake);
      addTearDown(container.dispose);

      await container.read(suggestionFlowProvider.notifier).load();
      final error = container.read(suggestionFlowProvider).error;
      expect(error, isA<ApiException>());
      expect((error as ApiException).kind, ApiErrorKind.forbidden);
    });
  });
}

/// Fake whose AI endpoint answers 403 (student must never see this in
/// practice — the backend gate is INTERN-only — but the flow must degrade
/// honestly if it ever happens).
class _ForbiddenSuggestFake extends FakeInternshipRepository {
  @override
  Future<ClassificationSuggestion> suggestCategories(
      String internshipId) async {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Forbidden',
        statusCode: 403,
        code: 'FORBIDDEN');
  }
}
