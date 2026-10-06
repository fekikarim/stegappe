import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/domain/schedule.dart';
import 'package:stegappe/features/internship/presentation/providers/supervisor_tasks_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';

import '../../test_fixtures.dart';

ProviderContainer _container(FakeInternshipRepository fake) =>
    ProviderContainer(overrides: [
      internshipRepositoryProvider.overrideWithValue(fake),
    ]);

void main() {
  group('schedule clock (Tunis, no device ambiguity)', () {
    test('tunis wall converts with the fixed +01:00 offset', () {
      // Africa/Tunis has no DST: 14:30 wall is always 13:30Z.
      final instant =
          tunisWallToInstant(DateTime.utc(2026, 6, 15), 14, 30);
      expect(instant.toUtc(), DateTime.utc(2026, 6, 15, 13, 30));
      expect(tunisWallFromInstant(instant),
          DateTime.utc(2026, 6, 15, 14, 30));
    });

    test('midnight boundary rolls the UTC day back', () {
      final instant =
          tunisWallToInstant(DateTime.utc(2026, 1, 10), 0, 15);
      expect(instant.toUtc(), DateTime.utc(2026, 1, 9, 23, 15));
    });
  });

  group('taskWriteJson/taskFromJson scheduling', () {
    test('write emits an absolute UTC instant; read parses it back', () {
      final at = DateTime.utc(2026, 4, 2, 13, 30);
      final json = taskWriteJson(title: 'T', visibleFrom: at);
      expect(json['visibleFrom'], '2026-04-02T13:30:00.000Z');
      final task = taskFromJson({
        'id': 't',
        'title': 'T',
        'visibleFrom': json['visibleFrom'],
      });
      expect(task.visibleFrom?.toUtc(), at);
      expect(task.isScheduled(DateTime.utc(2026, 4, 1)), isTrue);
      expect(task.isScheduled(DateTime.utc(2026, 4, 3)), isFalse);
    });

    test('absent schedule stays absent (immediate)', () {
      final json = taskWriteJson(title: 'T');
      expect(json.containsKey('visibleFrom'), isFalse);
      final task = taskFromJson({'id': 't', 'title': 'T'});
      expect(task.visibleFrom, isNull);
      expect(task.isScheduled(DateTime.now()), isFalse);
    });
  });

  group('SupervisorTaskController', () {
    test('create sends the schedule and reports success', () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);

      final at = DateTime.utc(2030, 5, 1, 12);
      final ok = await container
          .read(supervisorTaskControllerProvider.notifier)
          .createTask('internship-1',
              title: 'Scheduled', visibleFrom: at);
      expect(ok, isTrue);
      expect(fake.createdTasks.single['visibleFrom'], at);
      expect(fake.createdTasks.single['internshipId'], 'internship-1');
    });

    test('concurrent creates are guarded (double-tap protection)', () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller =
          container.read(supervisorTaskControllerProvider.notifier);

      final results = await Future.wait([
        controller.createTask('internship-1', title: 'One'),
        controller.createTask('internship-1', title: 'Two'),
      ]);
      expect(results.where((r) => r).length, 1);
      expect(fake.createdTasks.length, 1);
    });

    test('review approve/deny drive the fake and record the reason',
        () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller =
          container.read(supervisorTaskControllerProvider.notifier);

      final approved = await controller.reviewTask('t-x', 'internship-1',
          approve: true);
      expect(approved?.status, TaskStatus.approved);
      final denied = await controller.reviewTask('t-y', 'internship-1',
          approve: false, comment: 'Missing tests');
      expect(denied?.status, TaskStatus.denied);
      expect(denied?.denialReason, 'Missing tests');
      expect(
          fake.reviewedTasks
              .where((r) => r['approve'] == false)
              .single['comment'],
          'Missing tests');
    });

    test('delete records the task id', () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);

      final ok = await container
          .read(supervisorTaskControllerProvider.notifier)
          .deleteTask('t-doomed', 'internship-1');
      expect(ok, isTrue);
      expect(fake.deletedTasks, ['t-doomed']);
    });

    test('bulk submits mutations with a fresh key per submit', () async {
      final fake = FakeInternshipRepository();
      final container = _container(fake);
      addTearDown(container.dispose);
      final controller =
          container.read(supervisorTaskControllerProvider.notifier);

      final mutations = [
        bulkMutationJson(
            action: 'CREATE',
            internshipId: 'internship-1',
            task: taskWriteJson(title: 'A')),
        bulkMutationJson(
            action: 'CREATE',
            internshipId: 'internship-1',
            task: taskWriteJson(title: 'B')),
      ];
      final first = await controller.bulkTasks(mutations);
      final second = await controller.bulkTasks(mutations);
      expect(first?.okCount, 2);
      expect(second?.okCount, 2);
      expect(fake.bulkCalls, 2);
      // A corrected payload resends with a NEW key (replay, not duplicate).
      expect(fake.bulkKeys.toSet().length, 2);
      expect(fake.bulkMutations.length, 4);
    });

    test('offline failure stores a raw error for the localized UI',
        () async {
      final fake = FakeInternshipRepository()..failWrites = true;
      final container = _container(fake);
      addTearDown(container.dispose);

      final ok = await container
          .read(supervisorTaskControllerProvider.notifier)
          .createTask('internship-1', title: 'Nope');
      expect(ok, isFalse);
      expect(
          container.read(supervisorTaskControllerProvider).error,
          isNotNull);
    });
  });
}
