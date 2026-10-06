import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/offline/pending_writes.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/widgets/task_row.dart';

import '../../test_fixtures.dart';
import '../../support/queue_harness.dart';

const _intern = AppUser(id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<AppUser> login({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<bool> refreshSession() async => true;
  @override
  Future<AppUser?> restoreSession() async => _intern;
}

Future<ProviderContainer> _pumpRow(
  WidgetTester tester,
  Widget row, {
  FakeInternshipRepository? fake,
  bool online = true,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWithValue(online),
        await queueOverride(),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: StegLocales.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: StegTheme.light(),
        home: Scaffold(body: row),
      ),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  final container = ProviderScope.containerOf(ctx);
  await container.read(authControllerProvider.notifier).bootstrap();
  await tester.pumpAndSettle();
  return container;
}

const _task = InternTask(id: 't-today', title: 'Today task', status: TaskStatus.todo);

void main() {
  group('TaskRow offline queue (T06/D12)', () {
    testWidgets('offline toggle queues visibly with a pending chip',
        (tester) async {
      final fake = FakeInternshipRepository();
      final container = await _pumpRow(
        tester,
        TaskRow(task: _task, now: DateTime.now()),
        fake: fake,
        online: false,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Accepted into the visible queue — never sent, never lost.
      expect(find.text('Enregistré — sera envoyé à la reconnexion.'),
          findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(container.read(pendingWritesProvider).count, 1);
      // No direct write happened while offline.
      expect(fake.statusUpdates, isEmpty);
    });

    testWidgets('online toggle writes directly with no queue', (tester) async {
      final fake = FakeInternshipRepository();
      await _pumpRow(
        tester,
        TaskRow(task: _task, now: DateTime.now()),
        fake: fake,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(fake.statusUpdates, [('t-today', TaskStatus.awaitingApproval)]);
      expect(find.text('En attente'), findsNothing);
    });

    testWidgets('flush clears the pending chip after the server confirms',
        (tester) async {
      final fake = FakeInternshipRepository();
      final container = await _pumpRow(
        tester,
        TaskRow(task: _task, now: DateTime.now()),
        fake: fake,
        online: false,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('En attente'), findsOneWidget);

      await container
          .read(pendingWritesProvider.notifier)
          .flushTaskStatuses();
      await tester.pumpAndSettle();

      expect(find.text('En attente'), findsNothing);
      expect(fake.statusUpdates, [('t-today', TaskStatus.awaitingApproval)]);
    });

    testWidgets('arabic RTL renders the pending marker', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
            internshipRepositoryProvider
                .overrideWithValue(FakeInternshipRepository()),
            isOnlineProvider.overrideWithValue(false),
            await queueOverride(),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: StegLocales.supported,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: StegTheme.dark(),
            home: Scaffold(
                body: TaskRow(task: _task, now: DateTime.now())),
          ),
        ),
      );
      final ctx = tester.element(find.byType(Scaffold).first);
      await ProviderScope.containerOf(ctx)
          .read(authControllerProvider.notifier)
          .bootstrap();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('قيد الانتظار'), findsOneWidget);
    });
  });
}
