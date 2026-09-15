import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/storage/token_storage.dart';
import 'package:stegappe/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stegappe/features/auth/data/models/auth_models.dart';
import 'package:stegappe/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

String _jwt(Map<String, dynamic> payload) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS512'})}.${enc(payload)}.sig';
}

void main() {
  group('AuthRepositoryImpl', () {
    late _MockRemote remote;
    late InMemoryTokenStorage tokens;
    late AuthRepositoryImpl repo;

    setUp(() {
      remote = _MockRemote();
      tokens = InMemoryTokenStorage();
      repo = AuthRepositoryImpl(remote: remote, tokens: tokens);
      registerFallbackValue(const LoginRequest(email: 'e', password: 'p'));
    });

    test('login saves tokens to secure storage (never prefs)', () async {
      when(() => remote.login(any())).thenAnswer(
        (_) async =>
            const AuthTokens(accessToken: 'a.b.c', refreshToken: 'r'),
      );
      await repo.login(email: 'i@u.tn', password: 'password123');
      expect(await tokens.readAccessToken(), 'a.b.c');
      expect(await tokens.readRefreshToken(), 'r');
    });

    test('decodes backend roles for routing', () async {
      final jwt = _jwt({
        'sub': 'u1',
        'email': 'i@u.tn',
        'roles': ['INTERN'],
      });
      when(() => remote.login(any())).thenAnswer(
        (_) async => AuthTokens(accessToken: jwt, refreshToken: 'r'),
      );
      final AppUser user =
          await repo.login(email: 'i@u.tn', password: 'password123');
      expect(user.mobileRole, UserRole.intern);
      expect(user.id, 'u1');
    });

    test('failed refresh clears tokens', () async {
      await tokens.saveTokens(accessToken: 'a', refreshToken: 'bad');
      when(() => remote.refresh(any())).thenThrow(
        const ApiException(
            kind: ApiErrorKind.unauthorized, message: 'expired'),
      );
      expect(await repo.refreshSession(), isFalse);
      expect(await tokens.readAccessToken(), isNull);
    });
  });

  group('userRoleFromBackend', () {
    test('supervisor wins when both roles present', () {
      expect(userRoleFromBackend(['INTERN', 'SUPERVISOR']),
          UserRole.supervisor);
    });
    test('unknown/staff roles are unsupported on mobile', () {
      expect(userRoleFromBackend(['HR']), UserRole.unsupported);
      expect(userRoleFromBackend(['CANDIDATE']), UserRole.unsupported);
      expect(userRoleFromBackend([]), UserRole.unsupported);
    });
  });
}
