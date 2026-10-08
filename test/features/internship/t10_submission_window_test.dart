import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/connectivity/connectivity_service.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/core/network/api_client.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/network/endpoints.dart';
import 'package:stegappe/core/network/error_messages.dart';
import 'package:stegappe/core/theme/steg_theme.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/domain/repositories/auth_repository.dart';
import 'package:stegappe/features/auth/presentation/providers/auth_providers.dart';
import 'package:stegappe/features/internship/data/datasources/internship_remote_data_source.dart';
import 'package:stegappe/features/internship/domain/entities/work_items.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/internship/presentation/screens/deliverable_detail_screen.dart';
import 'package:stegappe/features/internship/presentation/widgets/status_labels.dart';

import '../../test_fixtures.dart';

/// T10/B7 — the final-week submission window drives the submit action
/// honestly (show/hide + reason + contact the supervisor, never an override),
/// and T10/B8 — the explicit document kind reaches the multipart wire.
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

Future<FakeInternshipRepository> pumpDetail(
  WidgetTester tester,
  Widget page, {
  AppUser user = _intern,
  FakeInternshipRepository? fake,
}) async {
  final repo = fake ?? FakeInternshipRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuth(user)),
        internshipRepositoryProvider.overrideWithValue(repo),
        isOnlineProvider.overrideWith((ref) => true),
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

/// Captures the multipart fields / JSON body a data source sends, so the
/// T10/B8 wire contract (`documentKind`) is asserted at the request level.
class _CapturingClient implements ApiClient {
  String? lastPath;
  Map<String, String>? lastFields;
  Object? lastBody;

  @override
  Future<T> uploadMultipart<T>(
    String path, {
    String? bearer,
    Map<String, String>? fields,
    required String fileField,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    Map<String, String>? headers,
    void Function(int sent, int total)? onProgress,
    required T Function(dynamic json) decode,
  }) async {
    lastPath = path;
    lastFields = fields;
    return decode(
        {'id': 'd1', 'title': 'T', 'status': 'DRAFT', 'currentVersion': 1});
  }

  @override
  Future<T> post<T>(
    String path, {
    String? bearer,
    Object? body,
    Map<String, String>? headers,
    required T Function(dynamic json) decode,
  }) async {
    lastPath = path;
    lastBody = body;
    return decode(
        {'id': 'd1', 'title': 'T', 'status': 'DRAFT', 'currentVersion': 1});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('T10/B7 — the final-week window shows the submit action honestly', () {
    testWidgets('closed (late) hides submit, explains, offers the chat',
        (tester) async {
      final closesAt = DateTime(2026, 10, 1);
      final fake = FakeInternshipRepository()
        ..draftDetail = true
        ..documentKindFixture = 'REPORT'
        ..submissionWindowFixture = SubmissionWindow(
          open: false,
          closesAt: closesAt,
          reason: 'AFTER_WINDOW',
          daysUntilOpen: 0,
          windowDays: 7,
        );
      final l10n = await loadL10n('fr');
      await pumpDetail(
          tester, const DeliverableDetailScreen(deliverableId: 'd-sub'),
          fake: fake);

      expect(find.text(l10n.deliverableSubmitAction), findsNothing);
      expect(
          find.text(l10n.submissionWindowLate(
              formatDay(closesAt, const Locale('fr')))),
          findsOneWidget);
      expect(find.text(l10n.contactSupervisorAction), findsOneWidget);
    });

    testWidgets('closed (not yet open) explains the opening date', (
      tester,
    ) async {
      final opensAt = DateTime(2026, 10, 12);
      final fake = FakeInternshipRepository()
        ..draftDetail = true
        ..documentKindFixture = 'JOURNAL'
        ..submissionWindowFixture = SubmissionWindow(
          open: false,
          opensAt: opensAt,
          closesAt: DateTime(2026, 10, 19),
          reason: 'BEFORE_WINDOW',
          daysUntilOpen: 4,
          windowDays: 7,
        );
      final l10n = await loadL10n('fr');
      await pumpDetail(
          tester, const DeliverableDetailScreen(deliverableId: 'd-sub'),
          fake: fake);

      expect(find.text(l10n.deliverableSubmitAction), findsNothing);
      expect(
          find.text(l10n.submissionWindowOpens(
              formatDay(opensAt, const Locale('fr')))),
          findsOneWidget);
      expect(find.text(l10n.contactSupervisorAction), findsOneWidget);
    });

    testWidgets('open shows submit and the closing date', (tester) async {
      final closesAt = DateTime(2026, 10, 8);
      final fake = FakeInternshipRepository()
        ..draftDetail = true
        ..documentKindFixture = 'REPORT'
        ..submissionWindowFixture = SubmissionWindow(
          open: true,
          opensAt: DateTime(2026, 10, 1),
          closesAt: closesAt,
          reason: 'OPEN',
          daysUntilOpen: 0,
          windowDays: 7,
        );
      final l10n = await loadL10n('fr');
      await pumpDetail(
          tester, const DeliverableDetailScreen(deliverableId: 'd-sub'),
          fake: fake);

      expect(find.text(l10n.deliverableSubmitAction), findsOneWidget);
      expect(
          find.text(l10n.submissionWindowUntil(
              formatDay(closesAt, const Locale('fr')))),
          findsOneWidget);
      expect(find.text(l10n.contactSupervisorAction), findsNothing);
    });

    testWidgets('a free document (no declared kind) ignores the window',
        (tester) async {
      final fake = FakeInternshipRepository()
        ..draftDetail = true
        // documentKindFixture stays null: ordinary deliverables keep the
        // pre-existing lifecycle (B7 enforces validation documents only).
        ..submissionWindowFixture = const SubmissionWindow(
          open: false,
          reason: 'AFTER_WINDOW',
          daysUntilOpen: 0,
          windowDays: 7,
        );
      final l10n = await loadL10n('fr');
      await pumpDetail(
          tester, const DeliverableDetailScreen(deliverableId: 'd-sub'),
          fake: fake);

      expect(find.text(l10n.deliverableSubmitAction), findsOneWidget);
      expect(find.text(l10n.contactSupervisorAction), findsNothing);
    });

    testWidgets('submit still works when the window read fails (server owns it)',
        (tester) async {
      final fake = FakeInternshipRepository()
        ..draftDetail = true
        ..documentKindFixture = 'REPORT'
        ..submissionWindowError = Exception('window read failed');
      final l10n = await loadL10n('fr');
      await pumpDetail(
          tester, const DeliverableDetailScreen(deliverableId: 'd-sub'),
          fake: fake);

      // Honest fallback: the action stays available because the server
      // enforces the window anyway; a refusal maps to a coded sentence.
      expect(find.text(l10n.deliverableSubmitAction), findsOneWidget);
    });
  });

  group('T10/B7 — coded refusals map to honest sentences (never raw)', () {
    ApiException err(String code) => ApiException(
          kind: ApiErrorKind.validation,
          message: code,
          statusCode: 422,
          code: code,
        );

    test('SUBMISSION_NOT_IN_WINDOW explains in fr/en/ar', () async {
      for (final code in ['fr', 'en', 'ar']) {
        final l10n = await loadL10n(code);
        final mapped = userErrorOf(err('SUBMISSION_NOT_IN_WINDOW'), l10n);
        expect(mapped.message, l10n.errSubmissionWindowClosed);
        expect(mapped.message, isNot(contains('SUBMISSION_NOT_IN_WINDOW')));
        expect(mapped.retryable, isFalse);
      }
    });

    test('locked document kind shares one honest sentence', () async {
      final l10n = await loadL10n('fr');
      for (final code in [
        'DOCUMENT_KIND_LOCKED',
        'DELIVERABLE_ALREADY_VALIDATED',
      ]) {
        final mapped = userErrorOf(err(code), l10n);
        expect(mapped.message, l10n.errDeliverableKindLocked);
        expect(mapped.retryable, isFalse);
      }
    });

    test('a foreign conversation document is named as such', () async {
      final l10n = await loadL10n('fr');
      final mapped =
          userErrorOf(err('DELIVERABLE_NOT_IN_CONVERSATION'), l10n);
      expect(mapped.message, l10n.errDocumentNotInConversation);
      expect(mapped.retryable, isFalse);
    });
  });

  group('T10/B8 — documentKind reaches the wire (multipart + JSON)', () {
    test('create sends the declared kind as a multipart field', () async {
      final client = _CapturingClient();
      final ds = InternshipRemoteDataSource(client);
      await ds.createDeliverable('i1', 'bearer',
          title: 'Rapport',
          documentKind: 'REPORT',
          fileName: 'r.pdf',
          fileBytes: Uint8List.fromList([1, 2, 3]));
      expect(client.lastPath, '/api/internships/i1/deliverables');
      expect(client.lastFields?['documentKind'], 'REPORT');
      expect(client.lastFields?['title'], 'Rapport');
    });

    test('a free document omits the field entirely', () async {
      final client = _CapturingClient();
      final ds = InternshipRemoteDataSource(client);
      await ds.createDeliverable('i1', 'bearer',
          title: 'Note',
          fileName: 'n.pdf',
          fileBytes: Uint8List.fromList([1]));
      expect(client.lastFields!.containsKey('documentKind'), isFalse);
    });

    test('registration posts {documentKind} to the exact endpoint', () async {
      final client = _CapturingClient();
      final ds = InternshipRemoteDataSource(client);
      await ds.registerDocumentKind('d9', 'bearer', 'JOURNAL');
      expect(client.lastPath,
          '/api/internships/deliverables/d9/document-kind');
      expect(client.lastBody, {'documentKind': 'JOURNAL'});
    });

    test('the window read hits the exact endpoint', () {
      expect(Endpoints.submissionWindow('i1'),
          '/api/internships/i1/submission-window');
      expect(Endpoints.deliverableDocumentKind('d9'),
          '/api/internships/deliverables/d9/document-kind');
    });
  });
}
