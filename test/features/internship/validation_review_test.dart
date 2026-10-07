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
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/deliverable_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/screens/logbook_detail_screen.dart';
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

Future<FakeInternshipRepository> pumpValidation(
  WidgetTester tester,
  Widget page, {
  AppUser user = _sup,
  FakeInternshipRepository? fake,
  Locale locale = const Locale('fr'),
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(user)),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => true),
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
        home: Scaffold(body: page),
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

NotificationItem itemOf(String wireType) {
  final parsed = notificationItemFromFrame(jsonEncode({
    'notificationId': 'n1',
    'type': wireType,
    'title': 't',
    'message': 'm',
    'priority': 'HIGH',
    'relatedEntityType': 'Deliverable',
    'relatedEntityId': 'd1',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  }));
  return parsed!;
}

void main() {
  group('T10 realtime: rejection frames converge the validation queues', () {
    test('DOCUMENT_REJECTED maps to the documents category', () {
      // Covers both the Admin path (T01) and the supervisor first-level
      // path (T10): same catalogue key, same queues to refetch.
      expect(
        documentSyncCategoryFor(itemOf('DOCUMENT_REJECTED')),
        RealtimeCategory.documents,
      );
    });

    test('JOURNAL_ENTRY_VALIDATED still maps to documents (T09 pin)', () {
      expect(
        documentSyncCategoryFor(itemOf('JOURNAL_ENTRY_VALIDATED')),
        RealtimeCategory.documents,
      );
    });

    test('task/message frames never touch the document queues', () {
      expect(documentSyncCategoryFor(itemOf('TASK_STATUS_CHANGED')), isNull);
      expect(documentSyncCategoryFor(itemOf('MESSAGE_RECEIVED')), isNull);
    });
  });

  group('T10 first-level framing (D2/BR-28)', () {
    test('reviewFirstLevelNote is localized in fr/en/ar', () async {
      for (final locale in ['fr', 'en', 'ar']) {
        final l10n = await loadL10n(locale);
        expect(l10n.reviewFirstLevelNote.trim(), isNotEmpty);
      }
    });

    testWidgets('deliverable approve states the administration decides last',
        (tester) async {
      final l10n = await loadL10n('fr');
      await pumpValidation(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDeliverableReviewDialog(ctx,
                deliverableId: 'd-sub', approve: true),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewFirstLevelNote), findsOneWidget);
    });

    testWidgets('logbook approve states the administration decides last',
        (tester) async {
      final l10n = await loadL10n('fr');
      await pumpValidation(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showLogbookReviewDialog(ctx,
                internshipId: 'internship-1',
                internshipReference: 'STG-2026-0001',
                logbookId: 'l1',
                approve: true),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reviewFirstLevelNote), findsOneWidget);
    });
  });

  group('T10 deliverable review: server-confirmed, reason-gated', () {
    testWidgets('approve records a VALIDATED decision with the note',
        (tester) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      await pumpValidation(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDeliverableReviewDialog(ctx,
                deliverableId: 'd-sub', approve: true),
            child: const Text('open'),
          ),
        ),
        fake: fake,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.validateAction).last);
      await tester.pumpAndSettle();
      expect(
          fake.deliverableDecisions, contains(('d-sub', 'VALIDATED', null)));
    });

    testWidgets('reject without a comment is refused client-side',
        (tester) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      await pumpValidation(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDeliverableReviewDialog(ctx,
                deliverableId: 'd-sub', approve: false),
            child: const Text('open'),
          ),
        ),
        fake: fake,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.rejectAction).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.commentRequired), findsOneWidget);
      expect(fake.deliverableDecisions, isEmpty);
    });

    testWidgets('reject with a comment records REJECTED with the reason',
        (tester) async {
      final fake = FakeInternshipRepository();
      final l10n = await loadL10n('fr');
      await pumpValidation(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDeliverableReviewDialog(ctx,
                deliverableId: 'd-sub', approve: false),
            child: const Text('open'),
          ),
        ),
        fake: fake,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Add the STEG header');
      await tester.tap(find.text(l10n.rejectAction).last);
      await tester.pumpAndSettle();
      expect(fake.deliverableDecisions,
          contains(('d-sub', 'REJECTED', 'Add the STEG header')));
    });

    testWidgets('failed review stays open with the error (never fake-done)',
        (tester) async {
      final fake = FakeInternshipRepository()..failWrites = true;
      final l10n = await loadL10n('fr');
      await pumpValidation(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDeliverableReviewDialog(ctx,
                deliverableId: 'd-sub', approve: true),
            child: const Text('open'),
          ),
        ),
        fake: fake,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.validateAction).last);
      await tester.pumpAndSettle();
      expect(fake.deliverableDecisions, isEmpty);
      // The dialog stays open: the decision was not taken.
      expect(find.text(l10n.deliverableReviewTitle), findsOneWidget);
    });
  });

  group('T10 deliverable submit: single-flight', () {
    testWidgets('double tap submits once', (tester) async {
      final fake = FakeInternshipRepository()..draftDetail = true;
      final l10n = await loadL10n('fr');
      await pumpValidation(
        tester,
        const DeliverableDetailScreen(deliverableId: 'd-sub'),
        user: _intern,
        fake: fake,
      );
      await tester.tap(find.text(l10n.deliverableSubmitAction));
      await tester.tap(find.text(l10n.deliverableSubmitAction));
      await tester.pumpAndSettle();
      expect(
          fake.submittedDeliverables.where((e) => e == 'd-sub'), hasLength(1));
    });
  });
}
