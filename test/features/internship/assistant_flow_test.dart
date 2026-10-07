import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/data/cache/assistant_history_store.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/assistant.dart';
import 'package:stegappe/features/internship/presentation/providers/assistant_providers.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/assistant_screen.dart';

import '../../test_fixtures.dart';

const _intern = AppUser(id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.user);
  final AppUser user;

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
  Future<AppUser?> restoreSession() async => user;
}

Future<ProviderContainer> makeContainer({
  FakeInternshipRepository? fake,
  MemoryAssistantHistoryStore? store,
  bool online = true,
  AppUser user = _intern,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuth(user)),
      internshipRepositoryProvider.overrideWithValue(
          fake ?? FakeInternshipRepository()),
      assistantHistoryStoreProvider.overrideWithValue(
          store ?? MemoryAssistantHistoryStore()),
      assistantControllerProvider
          .overrideWith((ref) => AssistantController(ref)),
      isOnlineProvider.overrideWith((ref) => online),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.notifier).bootstrap();
  return container;
}

Future<({FakeInternshipRepository repo, MemoryAssistantHistoryStore store})>
    pumpAssistant(
  WidgetTester tester,
  Widget page, {
  FakeInternshipRepository? fake,
  MemoryAssistantHistoryStore? store,
  bool online = true,
  Locale locale = const Locale('fr'),
}) async {
  final repo = fake ?? FakeInternshipRepository();
  final history = store ?? MemoryAssistantHistoryStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(_intern)),
        internshipRepositoryProvider.overrideWithValue(repo),
        assistantHistoryStoreProvider.overrideWithValue(history),
        assistantControllerProvider
            .overrideWith((ref) => AssistantController(ref)),
        isOnlineProvider.overrideWith((ref) => online),
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
        home: Scaffold(body: page),
      ),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
  return (repo: repo, store: history);
}

Future<AppLocalizations> loadL10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  group('T11 contract: responseText is authoritative', () {
    test('decodes the backend responseText field', () {
      expect(
        assistantAnswerFromJson({
          'analysis': {'id': 'a'},
          'recommendations': [],
          'responseText': 'Voici un résumé.',
        }),
        'Voici un résumé.',
      );
    });

    test('a displayText-only body is rejected (the T11 regression)', () {
      // The old client read m['displayText']; the contract never carried
      // it, so every success rendered as "unavailable". A body without
      // responseText must throw here — never silently degrade.
      expect(
        () => assistantAnswerFromJson({'displayText': 'Bonjour'}),
        throwsFormatException,
      );
    });

    test('blank or absent answers throw instead of rendering empty', () {
      expect(() => assistantAnswerFromJson({'responseText': '  '}),
          throwsFormatException);
      expect(() => assistantAnswerFromJson({'responseText': ''}),
          throwsFormatException);
      expect(() => assistantAnswerFromJson({}), throwsFormatException);
      expect(() => assistantAnswerFromJson({'responseText': 42}),
          throwsFormatException);
    });

    test('responseText wins when both keys are present', () {
      expect(
        assistantAnswerFromJson(
            {'responseText': 'real', 'displayText': 'stale'}),
        'real',
      );
    });
  });

  group('T11 history store: local, bounded, per-user', () {
    test('round-trips messages for one user only', () async {
      final store = MemoryAssistantHistoryStore();
      await store.save('u1', const [
        AssistantMessage(mine: true, text: 'q'),
        AssistantMessage(mine: false, text: 'a'),
      ]);
      expect(await store.load('u1'), hasLength(2));
      expect(await store.load('u2'), isEmpty);
      await store.clear('u1');
      expect(await store.load('u1'), isEmpty);
    });

    test('keeps only the newest 100 rows', () async {
      final store = MemoryAssistantHistoryStore();
      await store.save('u1', [
        for (var i = 0; i < 105; i++)
          AssistantMessage(mine: true, text: 'q$i'),
      ]);
      final rows = await store.load('u1');
      expect(rows, hasLength(100));
      expect(rows.first.text, 'q5');
      expect(rows.last.text, 'q104');
    });

    test('message JSON survives the prefs codec', () {
      const m = AssistantMessage(mine: false, text: 'a', failed: true);
      expect(AssistantMessage.fromJson(m.toJson()), m);
    });
  });

  group('T11 controller: server-confirmed conversation', () {
    test('send appends the pair, persists and clears the error', () async {
      final fake = FakeInternshipRepository();
      final store = MemoryAssistantHistoryStore();
      final container =
          await makeContainer(fake: fake, store: store);
      final notifier = container.read(assistantControllerProvider.notifier);

      expect(await notifier.send('  Bonjour  '), isTrue);
      final state = container.read(assistantControllerProvider);
      expect(state.messages, hasLength(2));
      expect(state.messages[0].mine, isTrue);
      expect(state.messages[0].text, 'Bonjour');
      expect(state.messages[1].text, contains('Bonjour'));
      expect(state.pending, isFalse);
      expect(state.error, isNull);
      expect(fake.askedQuestions, ['Bonjour']);
      expect(await store.load('u1'), hasLength(2));
    });

    test('empty text and double-submit never dispatch twice', () async {
      final fake = FakeInternshipRepository();
      final container = await makeContainer(fake: fake);
      final notifier = container.read(assistantControllerProvider.notifier);

      expect(await notifier.send('   '), isFalse);
      final first = notifier.send('première');
      expect(await notifier.send('seconde'), isFalse);
      expect(await first, isTrue);
      expect(fake.askedQuestions, ['première']);
    });

    test('failure renders a failed row and keeps the raw error', () async {
      final fake = FakeInternshipRepository()..failAi = true;
      final container = await makeContainer(fake: fake);
      final notifier = container.read(assistantControllerProvider.notifier);

      expect(await notifier.send('aie'), isTrue);
      final state = container.read(assistantControllerProvider);
      expect(state.messages, hasLength(2));
      expect(state.messages[1].failed, isTrue);
      expect(state.error, isNotNull);
      // The failed row persists: retry stays possible after a restart.
      expect(state.messages[1].text, isEmpty);
    });

    test('retry replaces the failed row with the answer', () async {
      final fake = FakeInternshipRepository()..failAi = true;
      final store = MemoryAssistantHistoryStore();
      final container =
          await makeContainer(fake: fake, store: store);
      final notifier = container.read(assistantControllerProvider.notifier);

      await notifier.send('recommence');
      fake.failAi = false;
      expect(await notifier.retry(1), isTrue);
      final state = container.read(assistantControllerProvider);
      expect(state.messages, hasLength(2));
      expect(state.messages[1].failed, isFalse);
      expect(state.messages[1].text, contains('recommence'));
      expect(fake.askedQuestions, ['recommence', 'recommence']);
    });

    test('retry rejects nonsense indexes and non-failed rows', () async {
      final container = await makeContainer();
      final notifier = container.read(assistantControllerProvider.notifier);
      await notifier.send('ok');
      expect(await notifier.retry(99), isFalse);
      expect(await notifier.retry(0), isFalse); // user row, not failed
      expect(await notifier.retry(1), isFalse); // succeeded row
    });

    test('clear wipes memory and the persisted rows', () async {
      final store = MemoryAssistantHistoryStore();
      final container = await makeContainer(store: store);
      final notifier = container.read(assistantControllerProvider.notifier);
      await notifier.send('salut');
      await notifier.clear();
      expect(
          container.read(assistantControllerProvider).messages, isEmpty);
      expect(await store.load('u1'), isEmpty);
    });

    test('restore reloads the persisted conversation', () async {
      final store = MemoryAssistantHistoryStore();
      await store.save('u1', const [
        AssistantMessage(mine: true, text: 'avant'),
        AssistantMessage(mine: false, text: 'réponse avant'),
      ]);
      final container = await makeContainer(store: store);
      await container.read(assistantControllerProvider.notifier).restore();
      expect(
          container.read(assistantControllerProvider).messages, hasLength(2));
    });

    test('offline send fails honestly without dispatching', () async {
      final fake = FakeInternshipRepository();
      final container = await makeContainer(fake: fake, online: false);
      final notifier = container.read(assistantControllerProvider.notifier);

      expect(await notifier.send('hors ligne'), isFalse);
      final state = container.read(assistantControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.error, isA<ApiException>());
      expect(
          (state.error! as ApiException).kind, ApiErrorKind.network);
      expect(fake.askedQuestions, isEmpty);
    });

    test('a 404 stays raw for the no-internship empty state', () async {
      final fake = FakeInternshipRepository()
        ..assistantError = const ApiException(
            kind: ApiErrorKind.notFound, message: 'No internship');
      final container = await makeContainer(fake: fake);
      final notifier = container.read(assistantControllerProvider.notifier);
      await notifier.send('où en suis-je ?');
      final error = container.read(assistantControllerProvider).error;
      expect(error, isA<ApiException>());
      expect((error! as ApiException).kind, ApiErrorKind.notFound);
    });
  });

  group('T11 screen: honest states, retry, clear, offline', () {
    testWidgets('empty state then a real answer renders', (tester) async {
      final l10n = await loadL10n('fr');
      await pumpAssistant(tester, const AssistantScreen());
      expect(find.text(l10n.assistantEmpty), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Bonjour');
      await tester.tap(find.text(l10n.assistantSend));
      await tester.pumpAndSettle();
      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.textContaining('Réponse de test'), findsOneWidget);
      // The composer clears only after a dispatched send.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('failure shows a failed row with retry, then recovers',
        (tester) async {
      final fake = FakeInternshipRepository()..failAi = true;
      final l10n = await loadL10n('fr');
      await pumpAssistant(tester, const AssistantScreen(), fake: fake);

      await tester.enterText(find.byType(TextField), 'aie');
      await tester.tap(find.text(l10n.assistantSend));
      await tester.pumpAndSettle();
      expect(find.text(l10n.assistantUnavailable), findsWidgets);
      expect(find.text(l10n.retry), findsWidgets);

      fake.failAi = false;
      await tester.tap(find.text(l10n.retry).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Réponse de test'), findsOneWidget);
      expect(find.text(l10n.assistantUnavailable), findsNothing);
    });

    testWidgets('offline disables the composer with an explicit reason',
        (tester) async {
      final h = await pumpAssistant(tester, const AssistantScreen(),
          online: false);
      final l10n = await loadL10n('fr');
      expect(find.text(l10n.assistantOffline), findsOneWidget);
      final send = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(send.onPressed, isNull);
      expect(h.repo.askedQuestions, isEmpty);
    });

    testWidgets('clear asks for confirmation and wipes the thread',
        (tester) async {
      final h = await pumpAssistant(tester, const AssistantScreen());
      final l10n = await loadL10n('fr');
      await tester.enterText(find.byType(TextField), 'salut');
      await tester.tap(find.text(l10n.assistantSend));
      await tester.pumpAndSettle();
      expect(find.text('salut'), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.assistantClearTitle));
      await tester.pumpAndSettle();
      expect(find.text(l10n.assistantClearMessage), findsOneWidget);
      await tester.tap(find.text(l10n.assistantClearConfirm));
      await tester.pumpAndSettle();
      expect(find.text('salut'), findsNothing);
      expect(find.text(l10n.assistantEmpty), findsOneWidget);
      expect(await h.store.load('u1'), isEmpty);
    });

    testWidgets('no internship renders the dedicated empty state',
        (tester) async {
      final fake = FakeInternshipRepository()
        ..assistantError = const ApiException(
            kind: ApiErrorKind.notFound, message: 'No internship');
      final l10n = await loadL10n('fr');
      await pumpAssistant(tester, const AssistantScreen(), fake: fake);
      await tester.enterText(find.byType(TextField), 'où en suis-je ?');
      await tester.tap(find.text(l10n.assistantSend));
      await tester.pumpAndSettle();
      expect(find.text(l10n.assistantNoInternship), findsOneWidget);
    });

    testWidgets('rate limit surfaces the wait hint, text is kept',
        (tester) async {
      final fake = FakeInternshipRepository()
        ..assistantError =
            const ApiException(kind: ApiErrorKind.unknown, message: 'slow down', statusCode: 429);
      final l10n = await loadL10n('fr');
      await pumpAssistant(tester, const AssistantScreen(), fake: fake);
      await tester.enterText(find.byType(TextField), 'vite');
      await tester.tap(find.text(l10n.assistantSend));
      await tester.pumpAndSettle();
      expect(find.text(l10n.errRateLimited), findsOneWidget);
      // The failed row offers retry; the answer never fabricates.
      expect(find.text(l10n.retry), findsWidgets);
    });

    testWidgets('arabic renders the thread (RTL smoke)', (tester) async {
      await pumpAssistant(tester, const AssistantScreen(),
          locale: const Locale('ar'));
      final l10n = await loadL10n('ar');
      await tester.enterText(find.byType(TextField), 'مرحبا');
      await tester.tap(find.text(l10n.assistantSend));
      await tester.pumpAndSettle();
      expect(find.text('مرحبا'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a very long answer renders without overflow', (tester) async {
      await pumpAssistant(tester, const AssistantScreen());
      final l10n = await loadL10n('fr');
      await tester.enterText(find.byType(TextField), 'x' * 2000);
      await tester.tap(find.text(l10n.assistantSend));
      await tester.pumpAndSettle();
      expect(find.textContaining('Réponse de test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('T11 l10n: new assistant keys', () {
    test('offline/no-internship/clear keys exist in fr/en/ar', () async {
      for (final locale in ['fr', 'en', 'ar']) {
        final l10n = await loadL10n(locale);
        expect(l10n.assistantOffline.trim(), isNotEmpty);
        expect(l10n.assistantNoInternship.trim(), isNotEmpty);
        expect(l10n.assistantClearTitle.trim(), isNotEmpty);
        expect(l10n.assistantClearMessage.trim(), isNotEmpty);
        expect(l10n.assistantClearConfirm.trim(), isNotEmpty);
      }
    });
  });
}
