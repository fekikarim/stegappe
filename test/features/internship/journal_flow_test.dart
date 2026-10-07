import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/queue_harness.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/realtime/document_sync.dart';
import 'package:stegappe/core/realtime/realtime_sync.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/data/cache/composer_draft_store.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_composer_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_detail_sheet.dart';
import 'package:stegappe/features/internship/presentation/screens/journal_list_screen.dart';
import 'package:stegappe/features/messaging/domain/entities/notification_item.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

import '../../test_fixtures.dart';

const _intern = AppUser(id: 'u1', email: 'intern@u.tn', roles: ['INTERN']);
const _sup = AppUser(id: 's1', email: 'sup@steg.tn', roles: ['SUPERVISOR']);

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

/// Pumps a journal surface the way the shell hosts it, with a controllable
/// repository, role, connectivity and a memory-backed composer draft store.
Future<({FakeInternshipRepository repo, MemoryComposerDraftStore drafts})>
    pumpJournal(
  WidgetTester tester,
  Widget page, {
  AppUser user = _intern,
  FakeInternshipRepository? fake,
  MemoryComposerDraftStore? drafts,
  bool online = true,
  Locale locale = const Locale('fr'),
  List<Override> extra = const [],
}) async {
  final repo = fake ?? FakeInternshipRepository();
  final store = drafts ?? MemoryComposerDraftStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(user)),
        internshipRepositoryProvider.overrideWithValue(repo),
        composerDraftStoreProvider.overrideWithValue(store),
        isOnlineProvider.overrideWith((ref) => online),
        await queueOverride(),
        ...extra,
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
  return (repo: repo, drafts: store);
}

Future<AppLocalizations> loadL10n(String code) =>
    AppLocalizations.delegate.load(Locale(code));

void main() {
  group('T09 journal contract (backend-authoritative, no invented fields)', () {
    test('status wire mapping covers all four states + tolerant default', () {
      expect(journalStatusFrom('DRAFT'), JournalStatus.draft);
      expect(journalStatusFrom('SUBMITTED'), JournalStatus.submitted);
      expect(journalStatusFrom('VALIDATED'), JournalStatus.validated);
      expect(journalStatusFrom('REJECTED'), JournalStatus.rejected);
      // Unknown/absent values degrade to draft, never throw (T01 posture).
      expect(journalStatusFrom('FUTURE_STATE'), JournalStatus.draft);
      expect(journalStatusFrom(null), JournalStatus.draft);
      expect(journalStatusToApi(JournalStatus.draft), 'DRAFT');
      expect(journalStatusToApi(JournalStatus.submitted), 'SUBMITTED');
      expect(journalStatusToApi(JournalStatus.validated), 'VALIDATED');
      expect(journalStatusToApi(JournalStatus.rejected), 'REJECTED');
    });

    test('lifecycle predicates mirror the server transition table', () {
      JournalEntry entry(JournalStatus s) => JournalEntry(
          id: 'j', title: 't', status: s, entryDate: DateTime(2026, 1, 1));
      // Server: only DRAFT/REJECTED accept submit; only SUBMITTED accepts
      // validate/reject; entries are immutable (no update endpoint).
      expect(entry(JournalStatus.draft).canSubmit, isTrue);
      expect(entry(JournalStatus.rejected).canSubmit, isTrue);
      expect(entry(JournalStatus.submitted).canSubmit, isFalse);
      expect(entry(JournalStatus.validated).canSubmit, isFalse);
      expect(entry(JournalStatus.submitted).awaitsSupervisor, isTrue);
      expect(entry(JournalStatus.draft).awaitsSupervisor, isFalse);
      expect(entry(JournalStatus.validated).awaitsSupervisor, isFalse);
    });

    test('title cap mirrors the server column (VARCHAR 255)', () {
      expect(kJournalTitleMaxLength, 255);
    });

    test('write payload mirrors JournalEntryRequest (title/description/ymd)', () {
      final body = journalWriteJson(
        title: '  Jour  ',
        description: 'fait',
        entryDate: DateTime(2026, 10, 5),
      );
      expect(body['title'], '  Jour  ');
      expect(body['description'], 'fait');
      expect(body['entryDate'], '2026-10-05');
      expect(body.keys.toSet(), {'title', 'description', 'entryDate'});
    });

    test('journalTitleTooLong is localized in fr/en/ar with the bound', () async {
      for (final locale in ['fr', 'en', 'ar']) {
        final l10n = await loadL10n(locale);
        final text = l10n.journalTitleTooLong(255);
        expect(text.trim(), isNotEmpty);
        expect(text, contains('255'));
      }
    });
  });

  group('T09 realtime: validated-entry frames invalidate the journal queues',
      () {
    NotificationItem itemOf(String wireType) {
      final parsed = notificationItemFromFrame(jsonEncode({
        'notificationId': 'n1',
        'type': wireType,
        'title': 't',
        'message': 'm',
        'priority': 'NORMAL',
        'relatedEntityType': 'JournalEntry',
        'relatedEntityId': 'j1',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }));
      return parsed!;
    }

    test('JOURNAL_ENTRY_VALIDATED maps to the documents category', () {
      expect(
        documentSyncCategoryFor(itemOf('JOURNAL_ENTRY_VALIDATED')),
        RealtimeCategory.documents,
      );
    });

    test('task/community/unknown frames never touch the journal queues', () {
      expect(documentSyncCategoryFor(itemOf('TASK_STATUS_CHANGED')), isNull);
      expect(documentSyncCategoryFor(itemOf('COMMUNITY_COMMENT')), isNull);
      expect(
        documentSyncCategoryFor(
          NotificationItem(
            id: 'n',
            title: 't',
            message: 'm',
            priority: 'NORMAL',
            createdAt: DateTime.now(),
            isRead: false,
          ),
        ),
        isNull,
      );
    });

    test('documents category covers the journal list + supervisor queue', () {
      final targets = RiverpodRealtimeSync((_) {})
          .targetsFor(RealtimeCategory.documents);
      expect(targets, contains(journalListProvider));
      expect(targets, contains(pendingValidationsProvider));
      expect(targets, contains(dashboardProvider));
    });
  });

  group('T09 composer: student input stays student input', () {
    testWidgets('empty submit shows both required errors and creates nothing',
        (tester) async {
      final h = await pumpJournal(
        tester,
        JournalComposerScreen(
          internshipId: 'internship-1',
          day: DateTime.now(),
        ),
      );
      final l10n = await loadL10n('fr');
      await tester.tap(find.text(l10n.journalSaveDraft));
      await tester.pumpAndSettle();
      expect(find.text(l10n.journalFieldRequired), findsNWidgets(2));
      expect(h.repo.createdJournals, isEmpty);
    });

    testWidgets('over-long title is refused client-side with the bound',
        (tester) async {
      final h = await pumpJournal(
        tester,
        JournalComposerScreen(
          internshipId: 'internship-1',
          day: DateTime.now(),
        ),
      );
      final l10n = await loadL10n('fr');
      await tester.enterText(
          find.byType(TextField).first, 'x' * (kJournalTitleMaxLength + 1));
      await tester.enterText(
          find.byType(TextField).last, 'description valide');
      await tester.tap(find.text(l10n.journalSaveDraft));
      await tester.pumpAndSettle();
      expect(
          find.text(l10n.journalTitleTooLong(kJournalTitleMaxLength)),
          findsOneWidget);
      expect(h.repo.createdJournals, isEmpty);
    });

    testWidgets('valid entry is created trimmed for the selected day',
        (tester) async {
      final day = DateTime(2026, 10, 5);
      final h = await pumpJournal(
        tester,
        JournalComposerScreen(internshipId: 'internship-1', day: day),
      );
      final l10n = await loadL10n('fr');
      await tester.enterText(
          find.byType(TextField).first, '  Mise en place  ');
      await tester.enterText(
          find.byType(TextField).last, '  Activités du jour  ');
      await tester.tap(find.text(l10n.journalSaveDraft));
      await tester.pumpAndSettle();
      expect(h.repo.createdJournals, hasLength(1));
      final created = h.repo.createdJournals.single;
      expect(created['title'], 'Mise en place');
      expect(created['description'], 'Activités du jour');
      expect(created['entryDate'], day);
      // Success pops the composer (the snackbar is transient under
      // pumpAndSettle, so the pop + the repo call are the assertions).
      expect(find.byType(JournalComposerScreen), findsNothing);
    });

    testWidgets('a saved local draft is restored on reopen (never lost)',
        (tester) async {
      final day = DateTime(2026, 10, 5);
      final drafts = MemoryComposerDraftStore();
      await drafts.save(
          'internship-1',
          day,
          ComposerDraft(
              title: 'Brouillon',
              description: 'Suite demain',
              updatedAt: DateTime(2026, 10, 5, 14, 30)));
      await pumpJournal(
        tester,
        JournalComposerScreen(internshipId: 'internship-1', day: day),
        drafts: drafts,
      );
      expect(find.text('Brouillon'), findsOneWidget);
      expect(find.text('Suite demain'), findsOneWidget);
      final l10n = await loadL10n('fr');
      expect(find.textContaining(l10n.journalDraftSavedAt('').split('{')[0]),
          findsOneWidget);
    });

    testWidgets('quick back-navigation flushes keystrokes inside the debounce',
        (tester) async {
      final day = DateTime(2026, 10, 5);
      final h = await pumpJournal(
        tester,
        JournalComposerScreen(internshipId: 'internship-1', day: day),
      );
      await tester.enterText(find.byType(TextField).first, 'queue');
      // Dispose before the 600 ms debounce fires.
      await tester.pumpWidget(Container());
      final restored = await h.drafts.load('internship-1', day);
      expect(restored?.title, 'queue');
    });

    testWidgets('offline create fails honestly without faking persistence',
        (tester) async {
      final fake = FakeInternshipRepository()..failWrites = true;
      final h = await pumpJournal(
        tester,
        JournalComposerScreen(
          internshipId: 'internship-1',
          day: DateTime.now(),
        ),
        fake: fake,
        online: false,
      );
      final l10n = await loadL10n('fr');
      await tester.enterText(find.byType(TextField).first, 'Titre');
      await tester.enterText(find.byType(TextField).last, 'Description');
      await tester.tap(find.text(l10n.journalSaveDraft));
      await tester.pumpAndSettle();
      // Nothing persisted anywhere: no server row, local draft retained.
      expect(h.repo.createdJournals, isEmpty);
      expect(find.text(l10n.journalCreated), findsNothing);
    });
  });

  group('T09 list + detail: lifecycle states are honest', () {
    testWidgets('today entries render with status chips; stale when offline',
        (tester) async {
      await pumpJournal(tester, const JournalListScreen(), online: false);
      // Fixture: draft entry dated today renders even offline (stale cache).
      expect(find.text('Draft entry'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('intern submits a draft once despite a double tap',
        (tester) async {
      final h = await pumpJournal(tester, const JournalListScreen());
      final l10n = await loadL10n('fr');
      await tester.tap(find.text('Draft entry'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.journalSubmitAction), findsOneWidget);
      await tester.tap(find.text(l10n.journalSubmitAction));
      await tester.tap(find.text(l10n.journalSubmitAction));
      await tester.pumpAndSettle();
      expect(h.repo.submitted.where((e) => e == 'j-draft'), hasLength(1));
      // Success closes the sheet back to the list (snackbar transient).
      expect(find.text('Draft entry'), findsOneWidget);
    });

    testWidgets('validated entries offer no action (immutable)', (tester) async {
      await pumpJournal(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showJournalDetailSheet(
              ctx,
              JournalEntry(
                id: 'j-val',
                title: 'Validated entry',
                status: JournalStatus.validated,
                entryDate: DateTime.now(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l10n = await loadL10n('fr');
      expect(find.text(l10n.journalSubmitAction), findsNothing);
      expect(find.text(l10n.validateAction), findsNothing);
      expect(find.text(l10n.rejectAction), findsNothing);
    });

    testWidgets('supervisor reject requires a comment (server rule mirrored)',
        (tester) async {
      final h = await pumpJournal(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReviewDialog(
              ctx,
              entry: JournalEntry(
                id: 'j-sub',
                title: 'Submitted entry',
                status: JournalStatus.submitted,
                entryDate: DateTime.now(),
              ),
              approve: false,
            ),
            child: const Text('open'),
          ),
        ),
        user: _sup,
      );
      final l10n = await loadL10n('fr');
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.rejectAction).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.commentRequired), findsOneWidget);
      expect(h.repo.decisions, isEmpty);
      await tester.enterText(find.byType(TextField), 'Préciser les heures');
      await tester.tap(find.text(l10n.rejectAction).last);
      await tester.pumpAndSettle();
      expect(h.repo.decisions, hasLength(1));
      expect(h.repo.decisions.single.$2, 'REJECTED');
      expect(h.repo.decisions.single.$3, 'Préciser les heures');
    });

    testWidgets('supervisor validates with an optional note', (tester) async {
      final h = await pumpJournal(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReviewDialog(
              ctx,
              entry: JournalEntry(
                id: 'j-sub',
                title: 'Submitted entry',
                status: JournalStatus.submitted,
                entryDate: DateTime.now(),
              ),
              approve: true,
            ),
            child: const Text('open'),
          ),
        ),
        user: _sup,
      );
      final l10n = await loadL10n('fr');
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.validateAction).last);
      await tester.pumpAndSettle();
      expect(h.repo.decisions, hasLength(1));
      expect(h.repo.decisions.single.$2, 'VALIDATED');
      // The dialog + sheet both close on success.
      expect(find.text(l10n.reviewTitle), findsNothing);
    });

    testWidgets('arabic renders the journal list (RTL smoke)', (tester) async {
      await pumpJournal(
        tester,
        const JournalListScreen(),
        locale: const Locale('ar'),
      );
      // Data titles are locale-independent; rendering under an RTL
      // Directionality without overflow is the assertion (throws otherwise).
      expect(find.text('Draft entry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
