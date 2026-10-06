import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/task_drafts.dart';
import 'package:stegappe/features/internship/presentation/providers/task_draft_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';

import '../../test_fixtures.dart';

ProviderContainer _container(FakeInternshipRepository fake) =>
    ProviderContainer(overrides: [
      internshipRepositoryProvider.overrideWithValue(fake),
    ]);

TaskDraftFlowController _controller(
        ProviderContainer container, String ref) =>
    container.read(taskDraftFlowProvider(ref).notifier);

void main() {
  group('draft DTOs (tolerant parse, typed writes)', () {
    test('parses a full draft and drops malformed rows', () {
      final drafts = taskDraftListFromJson([
        {
          'id': 'd1',
          'referenceInternshipId': 'internship-1',
          'title': 'Do the bench',
          'description': 'Setup first',
          'dueDate': '2026-03-01',
          'createdAt': '2026-02-01T10:00:00Z',
          'futureField': 'ignored',
        },
        {'id': '', 'title': 'No id'},
        {'id': 'd2', 'title': '   '},
        'not-a-map',
      ]);
      expect(drafts.map((d) => d.id), ['d1']);
      // Backend sends yyyy-MM-dd (no zone): parsed as local midnight.
      expect(drafts.single.dueDate, DateTime(2026, 3, 1));
      expect(taskDraftListFromJson({'items': []}), isEmpty);
      expect(taskDraftListFromJson(null), isEmpty);
    });

    test('bulk result sorts by index and keeps per-pair ids', () {
      final result = draftBulkResultFromJson({
        'items': [
          {
            'index': 1,
            'draftId': 'd1',
            'internshipId': 'i2',
            'taskId': 't2',
            'status': 'OK'
          },
          {
            'index': 0,
            'draftId': 'd1',
            'internshipId': 'i1',
            'taskId': 't1',
            'status': 'OK'
          },
        ]
      });
      expect(result.okCount, 2);
      expect(result.items.first.internshipId, 'i1');
      expect(draftBulkResultFromJson({}).items, isEmpty);
    });

    test('payload builders carry schedule only when set', () {
      final withSchedule = bulkAddDraftsJson(
          draftIds: ['d1'],
          internshipIds: ['i1'],
          visibleFrom: DateTime.utc(2026, 2, 15, 12));
      expect(withSchedule['visibleFrom'], '2026-02-15T12:00:00.000Z');
      final plain =
          bulkAddDraftsJson(draftIds: ['d1'], internshipIds: ['i1']);
      expect(plain.containsKey('visibleFrom'), isFalse);
      expect(
          manualDraftJson(
              referenceInternshipId: 'i1',
              title: 'T',
              dueDate: DateTime.utc(2026, 3, 1))['dueDate'],
          '2026-03-01');
    });
  });

  group('TaskDraftFlowController', () {
    test('empty spec is refused client-side without a backend call',
        () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);

      await _controller(container, 'internship-1').generate();
      expect(fake.generateCalls, 0);
    });

    test('generate uses the typed spec and stores proposals', () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller = _controller(container, 'internship-1');

      controller.setSpecText('  Set up the bench.  ');
      await controller.generate();
      expect(fake.generateCalls, 1);
      final state = container.read(taskDraftFlowProvider('internship-1'));
      expect(state.drafts.map((d) => d.title),
          ['Draft one', 'Draft two']);
      expect(
          state.drafts.every(
              (d) => d.referenceInternshipId == 'internship-1'),
          isTrue);
    });

    test('double generate is guarded (second call is a no-op)', () async {
      final fake = FakeInternshipRepository()
        ..draftGate = Completer<void>();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller = _controller(container, 'internship-1');
      controller.setSpecText('Do the work.');

      final first = controller.generate();
      final second = controller.generate();
      fake.draftGate!.complete();
      await first;
      await second;
      expect(fake.generateCalls, 1);
    });

    test('abandon ignores the late result (no stale flash)', () async {
      final fake = FakeInternshipRepository()
        ..draftGate = Completer<void>();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller = _controller(container, 'internship-1');
      controller.setSpecText('Do the work.');

      final pending = controller.generate();
      controller.abandon();
      fake.draftGate!.complete();
      await pending;
      final state = container.read(taskDraftFlowProvider('internship-1'));
      expect(state.generating, isFalse);
      expect(state.drafts, isEmpty);
    });

    test('AI failure stores a raw error and preserves existing drafts',
        () async {
      final fake = FakeInternshipRepository()..failDrafts = true;
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller = _controller(container, 'internship-1');
      controller.setSpecText('Do the work.');
      await controller.generate();
      final state = container.read(taskDraftFlowProvider('internship-1'));
      expect(state.error, isNotNull);
      expect(state.drafts, isEmpty);
      expect(state.generating, isFalse);
    });

    test('manual lifecycle: add, edit, revise, delete', () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller = _controller(container, 'internship-1');

      expect(await controller.addManual(title: '  '), isFalse);
      expect(
          await controller.addManual(
              title: 'Manual', dueDate: DateTime.utc(2026, 3, 5)),
          isTrue);
      expect(
          await controller.updateDraft('d-manual-1',
              title: 'Manual v2'),
          isTrue);
      expect(
          await controller.reviseDraft(
              'd-manual-1', 'More concrete'),
          isTrue);
      expect(fake.revisedDrafts.single['instruction'], 'More concrete');
      expect(await controller.reviseDraft('d-manual-1', '  '), isFalse);
      expect(await controller.deleteDraft('d-manual-1'), isTrue);
      expect(
          container
              .read(taskDraftFlowProvider('internship-1'))
              .drafts,
          isEmpty);
    });

    test('bulk-add sends targets + schedule with a fresh key per submit',
        () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller = _controller(container, 'internship-1');
      controller.setSpecText('Do the work.');
      await controller.generate();
      controller.toggleTarget('internship-2', true);
      controller.setSchedule(DateTime.utc(2026, 2, 15, 12));

      expect(await controller.bulkAdd(), isTrue);
      expect(await controller.bulkAdd(), isTrue);
      expect(fake.bulkDraftCalls, 2);
      expect(fake.bulkDraftKeys.toSet().length, 2);
      expect(fake.lastBulkVisibleFrom, DateTime.utc(2026, 2, 15, 12));
      final state = container.read(taskDraftFlowProvider('internship-1'));
      expect(state.lastBulk?.okCount, 4);
    });

    test('bulk-add without drafts or targets is refused without a call',
        () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller = _controller(container, 'internship-1');

      expect(await controller.bulkAdd(), isFalse);
      expect(fake.bulkDraftCalls, 0);
    });

    test('reference switch reloads that student’s drafts', () async {
      final fake = FakeInternshipRepository()
        ..fakeDrafts = [
          const TaskDraft(
              id: 'dx',
              referenceInternshipId: 'internship-2',
              title: 'Other student draft'),
        ];
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller = _controller(container, 'internship-1');

      await controller.reload();
      expect(
          container
              .read(taskDraftFlowProvider('internship-1'))
              .drafts,
          isEmpty);
      controller.setReference('internship-2');
      await controller.reload();
      expect(
          container
              .read(taskDraftFlowProvider('internship-1'))
              .drafts
              .map((d) => d.id),
          ['dx']);
    });

    test('typed backend failures are stored raw for the localized UI',
        () async {
      final fake = _ForbiddenDraftsFake();
      final container = _container(fake);
      addTearDown(container.dispose);

      await _controller(container, 'internship-1').reload();
      final error = container
          .read(taskDraftFlowProvider('internship-1'))
          .error;
      expect(error, isA<ApiException>());
      expect((error as ApiException).kind, ApiErrorKind.forbidden);
    });

    test('PDF bytes ride the multipart path with progress', () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);

      final bytes = Uint8List.fromList(List.filled(128, 7));
      final drafts =
          await fake.generateDraftsFromPdf('internship-9',
              fileName: 'specs.pdf', bytes: bytes,
              onProgress: (sent, total) {
        expect(sent, total);
      });
      expect(drafts.every((d) => d.referenceInternshipId == 'internship-9'),
          isTrue);
      expect(fake.generateCalls, 1);
    });
  });
}

/// Fake whose draft list answers 403 (scope gate must degrade honestly).
class _ForbiddenDraftsFake extends FakeInternshipRepository {
  @override
  Future<List<TaskDraft>> listDrafts({String? internshipId}) async {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Forbidden',
        statusCode: 403,
        code: 'FORBIDDEN');
  }
}
