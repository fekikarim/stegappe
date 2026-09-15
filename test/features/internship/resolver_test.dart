import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/storage/token_storage.dart';
import 'package:stegappe/features/internship/data/cache/internship_id_store.dart';
import 'package:stegappe/features/internship/data/datasources/internship_remote_data_source.dart';
import 'package:stegappe/features/internship/data/models/internship_dtos.dart';
import 'package:stegappe/features/internship/data/repositories/internship_repository_impl.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';

class _MockRemote extends Mock implements InternshipRemoteDataSource {}

void main() {
  group('InternshipRepositoryImpl.resolveMyInternshipId', () {
    late _MockRemote remote;
    late MemoryInternshipIdStore ids;
    late InternshipRepositoryImpl repo;

    Map<String, dynamic> detail(String id) => {
          'id': id,
          'reference': 'STG-1',
          'startDate': '2026-09-01',
          'endDate': '2026-12-01',
          'status': 'ACTIVE',
          'type': 'PFE',
          'requirement': 'OBLIGATOIRE',
          'paymentEligible': true,
        };

    setUp(() {
      remote = _MockRemote();
      ids = MemoryInternshipIdStore();
      final tokens = InMemoryTokenStorage();
      repo = InternshipRepositoryImpl(
          remote: remote, tokens: tokens, idStore: ids);
    });

    test('verifies and returns the cached id', () async {
      await ids.write('cached-1');
      when(() => remote.getInternship('cached-1', any())).thenAnswer(
          (_) async => internshipFromJson(detail('cached-1')));

      expect(await repo.resolveMyInternshipId(), 'cached-1');
      verify(() => remote.getInternship('cached-1', any())).called(1);
      verifyNever(() => remote.listConversations(any()));
    });

    test('discovers via PRIVATE conversation then caches', () async {
      when(() => remote.listConversations(any())).thenAnswer((_) async => [
            const ConversationLink(type: 'GROUP', internshipId: null),
            const ConversationLink(
                type: 'PRIVATE', internshipId: 'found-9'),
          ]);
      when(() => remote.getInternship('found-9', any())).thenAnswer(
          (_) async => internshipFromJson(detail('found-9')));

      expect(await repo.resolveMyInternshipId(), 'found-9');
      expect(await ids.read(), 'found-9');
    });

    test('invalid cache falls back to discovery', () async {
      await ids.write('stale-1');
      when(() => remote.getInternship('stale-1', any())).thenThrow(
          const ApiException(
              kind: ApiErrorKind.forbidden, message: 'denied'));
      when(() => remote.listConversations(any()))
          .thenAnswer((_) async => []);
      expect(await repo.resolveMyInternshipId(), isNull);
      expect(await ids.read(), isNull);
    });

    test('network errors rethrow (UI shows stale cache, never wipes)',
        () async {
      when(() => remote.listConversations(any()))
          .thenThrow(ApiException.network());
      expect(repo.resolveMyInternshipId(),
          throwsA(isA<ApiException>()));
    });

    test('no conversation link means no linked internship', () async {
      when(() => remote.listConversations(any()))
          .thenAnswer((_) async => []);
      expect(await repo.resolveMyInternshipId(), isNull);
    });
  });

  group('ROLE_ prefix regression (live JWT uses ROLE_SUPERVISOR)', () {
    test('prefixed roles route correctly', () {
      expect(userRoleFromBackend(['ROLE_SUPERVISOR']),
          UserRole.supervisor);
      expect(
          userRoleFromBackend(['ROLE_INTERN']), UserRole.intern);
      expect(userRoleFromBackend(['SUPERVISOR']), UserRole.supervisor);
    });
  });
}
