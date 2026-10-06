import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/domain/entities/task_classification.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/classification_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/classification_suggest_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/task_list_screen.dart';
import 'package:stegappe/features/internship/presentation/widgets/category_chip.dart';

import '../../test_fixtures.dart';

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

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  FakeInternshipRepository? fake,
  bool online = true,
  Locale locale = const Locale('fr'),
  ThemeData? theme,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        internshipRepositoryProvider.overrideWithValue(repo),
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
        theme: theme ?? StegTheme.light(),
        home: Scaffold(body: page),
      ),
    ),
  );
  final ctx = tester.element(find.byType(Scaffold).first);
  await ProviderScope.containerOf(ctx)
      .read(authControllerProvider.notifier)
      .bootstrap();
  await tester.pumpAndSettle();
}

const _board = ClassificationBoard(
  categories: [
    TaskCategory(id: 'c1', name: 'Frontend', colorToken: 'blue'),
    TaskCategory(id: 'c2', name: 'Docs'),
  ],
  assignments: {'t-today': 'c1'},
);

void main() {
  group('CategoryChip', () {
    testWidgets('renders icon + name (never color alone)', (tester) async {
      await _pump(
          tester,
          const CategoryChip(
              category: TaskCategory(id: 'c1', name: 'Frontend')));
      expect(find.text('Frontend'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('unknown color token falls back without crashing', (tester) async {
      await _pump(
          tester,
          const CategoryChip(
              category:
                  TaskCategory(id: 'c9', name: 'Future', colorToken: 'holo')),
          theme: StegTheme.dark());
      expect(find.text('Future'), findsOneWidget);
    });
  });

  group('ClassificationSheet', () {
    testWidgets('lists categories with empty explanation and create action',
        (tester) async {
      final fake = FakeInternshipRepository()..fakeBoard = _board;
      await _pump(tester, const ClassificationSheet(), fake: fake);
      expect(find.text('Frontend'), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
      expect(find.text('Sans catégorie'), findsNothing);
    });

    testWidgets('empty board explains and offers creation', (tester) async {
      await _pump(tester, const ClassificationSheet());
      expect(find.text('Aucune catégorie pour le moment'), findsOneWidget);
    });
  });

  group('SuggestSheet', () {
    testWidgets('no categories disables AI with an explanation', (tester) async {
      await _pump(tester, const SuggestSheet());
      expect(find.textContaining('au moins une catégorie'), findsWidgets);
    });

    testWidgets('proposals show existing chips and NEW badges distinctly',
        (tester) async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = _board
        ..fakeProposals = const [
          CategoryProposal(taskId: 't-week', categoryId: 'c2'),
          CategoryProposal(
              taskId: 't-overdue', newCategoryName: 'Urgent'),
        ]
        ..fakeUnclassifiedCount = 2;
      await _pump(tester, const SuggestSheet(), fake: fake);
      // Trigger the suggestion from the empty state.
      await tester.tap(find.text('Suggérer avec l’IA'));
      await tester.pumpAndSettle();
      expect(find.text('Docs'), findsWidgets);
      expect(find.textContaining('Nouveau'), findsOneWidget);
      expect(find.text('Tout accepter'), findsOneWidget);
    });

    testWidgets('accept-all then undo drive the backend flow', (tester) async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = _board
        ..fakeProposals = const [
          CategoryProposal(taskId: 't-week', categoryId: 'c2'),
        ]
        ..fakeUnclassifiedCount = 1;
      await _pump(tester, const SuggestSheet(), fake: fake);
      await tester.tap(find.text('Suggérer avec l’IA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout accepter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('classée'), findsWidgets);
      expect(find.text('Annuler'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(fake.undoneBatches, ['batch-1']);
    });

    testWidgets('AI failure shows a localized sentence, board preserved',
        (tester) async {
      final fake = FakeInternshipRepository()
        ..fakeBoard = _board
        ..failSuggest = true;
      await _pump(tester, const SuggestSheet(), fake: fake);
      await tester.tap(find.text('Suggérer avec l’IA'));
      await tester.pumpAndSettle();
      // Localized generic sentence — never the raw exception.
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsWidgets);
    });

    testWidgets('offline disables AI with an honest sentence', (tester) async {
      final fake = FakeInternshipRepository()..fakeBoard = _board;
      await _pump(tester, const SuggestSheet(),
          fake: fake, online: false);
      expect(
          find.text('La suggestion IA nécessite une connexion.'),
          findsWidgets);
    });

    testWidgets('arabic renders RTL with translated copy', (tester) async {
      final fake = FakeInternshipRepository()..fakeBoard = _board;
      await _pump(tester, const SuggestSheet(),
          fake: fake, locale: const Locale('ar'));
      expect(find.text('اقتراح بالذكاء الاصطناعي'), findsOneWidget);
      final direction =
          tester.element(find.byType(Scaffold)).findAncestorWidgetOfExactType<Directionality>();
      expect(direction?.textDirection, TextDirection.rtl);
    });
  });

  group('TaskListScreen classification dimension', () {
    testWidgets('filter chips appear separately from status chips',
        (tester) async {
      final fake = FakeInternshipRepository()..fakeBoard = _board;
      await _pump(tester, TaskListScreen(), fake: fake);
      // Status chips (T02) and classification chips (T03) coexist.
      expect(find.text('Frontend'), findsWidgets);
      expect(find.text('Sans catégorie'), findsWidgets);
      // The classified card carries its chip.
      expect(find.text('Today task'), findsOneWidget);
    });

    testWidgets('selecting a category filters the board', (tester) async {
      final fake = FakeInternshipRepository()..fakeBoard = _board;
      await _pump(tester, TaskListScreen(), fake: fake);
      await tester.tap(find.text('Frontend').first);
      await tester.pumpAndSettle();
      // Only the classified task remains visible.
      expect(find.text('Today task'), findsOneWidget);
      expect(find.text('Week task'), findsNothing);
    });

    testWidgets('unclassified filter shows tasks without a category',
        (tester) async {
      final fake = FakeInternshipRepository()..fakeBoard = _board;
      await _pump(tester, TaskListScreen(), fake: fake);
      await tester.tap(find.text('Sans catégorie').first);
      await tester.pumpAndSettle();
      expect(find.text('Today task'), findsNothing);
      expect(find.text('Week task'), findsOneWidget);
    });
  });
}
