import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/queue_harness.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/core/widgets/steg_button.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/domain/entities/evaluation.dart';
import 'package:stegappe/features/internship/domain/entities/internship.dart';
import 'package:stegappe/features/internship/presentation/providers/notify_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/intern_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/supervised_interns_screen.dart';

import '../../test_fixtures.dart';

const _sup = AppUser(id: 's1', email: 'sup@steg.tn', roles: ['SUPERVISOR']);

class _FakeAuth implements AuthRepository {
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
  Future<AppUser?> restoreSession() async => _sup;
}

SupervisedIntern _row(String id, String name) => SupervisedIntern(
      internshipId: id,
      reference: 'REF-$id',
      internName: name,
      status: InternshipStatus.inProgress,
      type: InternshipType.perfectionnement,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 3, 31),
      departmentName: 'DSI',
      tasksCompleted: 0,
      tasksTotal: 0,
      pendingJournal: 0,
      pendingDeliverables: 0,
      evaluationsCount: 0,
    );

Future<ProviderContainer> makeContainer({
  FakeInternshipRepository? fake,
  bool online = true,
}) async {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(_FakeAuth()),
    internshipRepositoryProvider
        .overrideWithValue(fake ?? FakeInternshipRepository()),
    isOnlineProvider.overrideWith((ref) => online),
  ]);
  addTearDown(container.dispose);
  await container.read(authControllerProvider.notifier).bootstrap();
  return container;
}

Future<FakeInternshipRepository> pumpSupervised(
  WidgetTester tester, {
  FakeInternshipRepository? fake,
  bool online = true,
  Locale locale = const Locale('fr'),
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth()),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => online),
        await queueOverride(),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: StegLocales.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: StegTheme.light(),
        home: const Scaffold(body: SupervisedInternsScreen()),
      ),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
  return repo;
}

Future<AppLocalizations> loadL10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  group('T14 notify controller: scoped, single-flight, honest', () {
    test('toggle selects and deselects; empty send dispatches nothing',
        () async {
      final fake = FakeInternshipRepository();
      final container = await makeContainer(fake: fake);
      final notifier =
          container.read(notifyPreparationProvider.notifier);

      notifier.toggle('i1');
      notifier.toggle('i2');
      notifier.toggle('i1');
      expect(
          container.read(notifyPreparationProvider).selected, {'i2'});

      expect(await notifier.send(), 1);
      expect(fake.notifyCalls, 1);
      expect(fake.notifyIds.single, ['i2']);
      expect(
          container.read(notifyPreparationProvider).selected, isEmpty);
      expect(
          container.read(notifyPreparationProvider).lastNotified, 1);
    });

    test('empty selection never reaches the server', () async {
      final fake = FakeInternshipRepository();
      final container = await makeContainer(fake: fake);
      expect(
          await container
              .read(notifyPreparationProvider.notifier)
              .send(),
          isNull);
      expect(fake.notifyCalls, 0);
    });

    test('concurrent sends collapse to one dispatch', () async {
      final fake = FakeInternshipRepository();
      final container = await makeContainer(fake: fake);
      final notifier =
          container.read(notifyPreparationProvider.notifier);
      notifier.toggle('i1');
      final first = notifier.send();
      expect(await notifier.send(), isNull);
      expect(await first, 1);
      expect(fake.notifyCalls, 1);
    });

    test('a failed batch reuses its key (server replays, never double-notifies)',
        () async {
      final fake = FakeInternshipRepository()..failWrites = true;
      final container = await makeContainer(fake: fake);
      final notifier =
          container.read(notifyPreparationProvider.notifier);
      notifier.toggle('i1');
      notifier.toggle('i2');
      expect(await notifier.send(), isNull);
      expect(
          container.read(notifyPreparationProvider).error, isNotNull);

      // Same selection, resubmitted: the SAME key, so the server answers
      // from the stored receipt instead of notifying twice when the first
      // request actually landed (lost response / timeout).
      fake.failWrites = false;
      expect(await notifier.send(), 2);
      expect(fake.notifyCalls, 1);
      // Two attempts, ONE key: the retry is a replay, not a second batch.
      expect(fake.notifyKeys, hasLength(2));
      expect(fake.notifyKeys[0], isNotNull);
      expect(fake.notifyKeys[0], fake.notifyKeys[1]);
      expect(fake.notifyIds[0].toSet(), {'i1', 'i2'});
      expect(fake.notifyIds[1].toSet(), {'i1', 'i2'});
    });

    test('editing the selection after a failure mints a new key ',
        () async {
      final fake = FakeInternshipRepository()..failWrites = true;
      final container = await makeContainer(fake: fake);
      final notifier =
          container.read(notifyPreparationProvider.notifier);
      notifier.toggle('i1');
      expect(await notifier.send(), isNull);
      final failedKey = fake.notifyKeys.single;

      // A different target set must NOT replay the old receipt: the server
      // keys idempotency on (key, user, endpoint), not on the body, so a
      // reused key with new ids would silently notify nobody.
      fake.failWrites = false;
      notifier.toggle('i2');
      expect(await notifier.send(), 2);
      expect(fake.notifyKeys, hasLength(2));
      expect(fake.notifyKeys.last, isNot(failedKey));
      expect(fake.notifyIds.last.toSet(), {'i1', 'i2'});
    });
    test('a new batch after a success always mints a new key', () async {
      final fake = FakeInternshipRepository();
      final container = await makeContainer(fake: fake);
      final notifier =
          container.read(notifyPreparationProvider.notifier);
      notifier.toggle('i1');
      expect(await notifier.send(), 1);
      notifier.toggle('i1');
      expect(await notifier.send(), 1);
      expect(fake.notifyCalls, 2);
      // Two deliberate batches, two distinct keys: the second is a real
      // request, not a replay of the first receipt.
      expect(fake.notifyKeys[0], isNot(fake.notifyKeys[1]));
    });

    test('offline fails honestly without dispatching', () async {
      final fake = FakeInternshipRepository();
      final container = await makeContainer(fake: fake, online: false);
      final notifier =
          container.read(notifyPreparationProvider.notifier);
      notifier.toggle('i1');
      expect(await notifier.send(), isNull);
      final state = container.read(notifyPreparationProvider);
      expect(state.error, isA<ApiException>());
      expect((state.error! as ApiException).kind, ApiErrorKind.network);
      // The selection survives: nothing was lost, nothing was sent.
      expect(state.selected, {'i1'});
      expect(fake.notifyCalls, 0);
    });

    test('single-student shortcut leaves the shared selection alone',
        () async {
      final fake = FakeInternshipRepository();
      final container = await makeContainer(fake: fake);
      final notifier =
          container.read(notifyPreparationProvider.notifier);
      notifier.toggle('i9');
      expect(await notifier.sendTo('i1'), 1);
      expect(fake.notifyCalls, 1);
      expect(fake.notifyIds.single, ['i1']);
      expect(
          container.read(notifyPreparationProvider).selected, {'i9'});
    });

    test('clearSelection resets rows, error and result', () async {
      final container = await makeContainer();
      final notifier =
          container.read(notifyPreparationProvider.notifier);
      notifier.toggle('i1');
      await notifier.send();
      notifier.clearSelection();
      final state = container.read(notifyPreparationProvider);
      expect(state.selected, isEmpty);
      expect(state.error, isNull);
      expect(state.lastNotified, isNull);
    });
  });

  group('T14 notify UI: multi-select, feedback, offline', () {
    testWidgets('select mode, send, success feedback', (tester) async {
      final fake = FakeInternshipRepository()
        ..supervisedOverride = [
          _row('a', 'Amira Ben Salah'),
          _row('b', 'Karim Gharbi'),
        ];
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester, fake: fake);

      // Enter selection mode and tick both rows.
      await tester.tap(find.byTooltip(l10n.notifyPrepareAsk));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amira Ben Salah'));
      await tester.tap(find.text('Karim Gharbi'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.notifySelected(2)), findsOneWidget);

      await tester.tap(find.text(l10n.notifyPrepareAsk).last);
      await tester.pumpAndSettle();
      expect(fake.notifyCalls, 1);
      expect(find.text(l10n.notifySuccess(2)), findsWidgets);
    });

    testWidgets('empty selection keeps send disabled', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester);
      await tester.tap(find.byTooltip(l10n.notifyPrepareAsk));
      await tester.pumpAndSettle();
      expect(find.text(l10n.notifyEmptyHint), findsOneWidget);
      final button = tester.widget<StegButton>(find.byWidgetPredicate(
          (w) => w is StegButton && w.label == l10n.notifyPrepareAsk));
      expect(button.onPressed, isNull);
    });

    testWidgets('rate limit surfaces the wait hint with retry', (tester) async {
      final fake = FakeInternshipRepository()
        ..notifyError = const ApiException(
            kind: ApiErrorKind.unknown,
            message: 'slow down',
            statusCode: 429);
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester, fake: fake);
      await tester.tap(find.byTooltip(l10n.notifyPrepareAsk));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amira Ben Salah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.notifyPrepareAsk).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.errRateLimited), findsOneWidget);
      expect(fake.notifyCalls, 0);
    });

    testWidgets('offline send shows the connectivity reason', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester, online: false);
      await tester.tap(find.byTooltip(l10n.notifyPrepareAsk));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amira Ben Salah'));
      await tester.pumpAndSettle();
      final send = tester.widget<StegButton>(find.byWidgetPredicate(
          (w) => w is StegButton && w.label == l10n.notifyPrepareAsk));
      expect(send.onPressed, isNull);
      expect(find.text(l10n.notifyNeedsConnection), findsOneWidget);
    });

    testWidgets('detail shortcut notifies one student', (tester) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      await pumpSupervised(tester, fake: fake);
      // Open the intern file from the list, then use its shortcut.
      await tester.tap(find.text('Amira Ben Salah'));
      await tester.pumpAndSettle();
      expect(find.byType(InternDetailScreen), findsOneWidget);
      await tester.dragUntilVisible(
        find.text(l10n.notifyPrepareAsk),
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tester.tap(find.text(l10n.notifyPrepareAsk));
      await tester.pumpAndSettle();
      expect(fake.notifyCalls, 1);
      // Inline result plus the transient snackbar carry the same receipt
      // (exactly one internship was targeted).
      expect(find.text(l10n.notifySuccess(1)), findsWidgets);
    });

    testWidgets('arabic renders the selection flow (RTL smoke)',
        (tester) async {
      final l10n = await loadL10n('ar');
      await pumpSupervised(tester, locale: const Locale('ar'));
      await tester.tap(find.byTooltip(l10n.notifyPrepareAsk));
      await tester.pumpAndSettle();
      expect(find.text(l10n.notifyEmptyHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
