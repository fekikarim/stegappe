import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stegappe/core/network/api_client.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/storage/token_storage.dart';
import 'package:stegappe/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stegappe/features/auth/data/models/auth_models.dart';
import 'package:stegappe/features/auth/data/repositories/auth_repository_impl.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

String _jwt({required int expOffsetSeconds}) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + expOffsetSeconds;
  return '${enc({'alg': 'HS512'})}.${enc({
    'sub': 'u1',
    'email': 'i@u.tn',
    'roles': ['INTERN'],
    'exp': exp,
  })}.sig';
}

void main() {
  group('token refresh + logout (D7 gate)', () {
    test('expired access token refreshes silently on restore',
        () async {
      final remote = _MockRemote();
      final tokens = InMemoryTokenStorage();
      await tokens.saveTokens(
          accessToken: _jwt(expOffsetSeconds: -60),
          refreshToken: 'refresh-1');
      final fresh = _jwt(expOffsetSeconds: 900);
      when(() => remote.refresh(any())).thenAnswer((_) async =>
          AuthTokens(accessToken: fresh, refreshToken: 'refresh-2'));
      final repo =
          AuthRepositoryImpl(remote: remote, tokens: tokens);

      final user = await repo.restoreSession();
      expect(user?.id, 'u1');
      expect(await tokens.readAccessToken(), fresh);
      expect(await tokens.readRefreshToken(), 'refresh-2');
      verify(() => remote.refresh('refresh-1')).called(1);
    });

    test('dead refresh wipes tokens (clean re-login required)',
        () async {
      final remote = _MockRemote();
      final tokens = InMemoryTokenStorage();
      await tokens.saveTokens(
          accessToken: _jwt(expOffsetSeconds: -60),
          refreshToken: 'bad');
      when(() => remote.refresh(any())).thenThrow(
          const ApiException(
              kind: ApiErrorKind.unauthorized,
              message: 'expired'));
      final repo =
          AuthRepositoryImpl(remote: remote, tokens: tokens);

      expect(await repo.restoreSession(), isNull);
      expect(await tokens.readAccessToken(), isNull);
    });

    test('logout revokes remotely then always clears locally',
        () async {
      final remote = _MockRemote();
      final tokens = InMemoryTokenStorage();
      await tokens.saveTokens(accessToken: 'a', refreshToken: 'r');
      when(() => remote.logout(any()))
          .thenAnswer((_) async {});
      final repo =
          AuthRepositoryImpl(remote: remote, tokens: tokens);

      await repo.logout();
      verify(() => remote.logout('a')).called(1);
      expect(await tokens.readAccessToken(), isNull);
    });

    test('logout clears locally even when revocation fails',
        () async {
      final remote = _MockRemote();
      final tokens = InMemoryTokenStorage();
      await tokens.saveTokens(accessToken: 'a', refreshToken: 'r');
      when(() => remote.logout(any()))
          .thenThrow(ApiException.network());
      final repo =
          AuthRepositoryImpl(remote: remote, tokens: tokens);

      await repo.logout();
      expect(await tokens.readAccessToken(), isNull);
      expect(await tokens.readRefreshToken(), isNull);
    });
  });

  group('GET retry/backoff (idempotent reads only)', () {
    test('retries transport failures, then succeeds', () async {
      var calls = 0;
      final client = ApiClient(
        baseUrl: 'http://x',
        httpClient: MockClient((_) async {
          calls++;
          if (calls < 3) {
            throw http.ClientException('flaky');
          }
          return http.Response('{"ok":true}', 200);
        }),
      );
      final ok = await client.get('/ping',
          decode: (j) => (j as Map)['ok'] as bool,
          retry: const ReadRetryPolicy(
              maxAttempts: 3,
              baseDelay: Duration(milliseconds: 1)));
      expect(ok, isTrue);
      expect(calls, 3);
    });

    test('auth/validation errors never retry', () async {
      var calls = 0;
      final client = ApiClient(
        baseUrl: 'http://x',
        httpClient: MockClient((_) async {
          calls++;
          return http.Response(
              '{"status":403,"error":"Denied","message":"nope"}',
              403);
        }),
      );
      await expectLater(
          client.get('/x',
              decode: (_) {},
              retry:
                  const ReadRetryPolicy(baseDelay: Duration.zero)),
          throwsA(isA<ApiException>()));
      expect(calls, 1);
    });

    test('no policy means single attempt (writes unaffected)',
        () async {
      var calls = 0;
      final client = ApiClient(
        baseUrl: 'http://x',
        httpClient: MockClient((_) async {
          calls++;
          throw http.ClientException('down');
        }),
      );
      await expectLater(client.get('/x', decode: (_) {}),
          throwsA(isA<ApiException>()));
      expect(calls, 1);
    });
  });

  group('multipart upload streams with progress', () {
    test('progress climbs to total and server JSON decodes',
        () async {
      final seen = <int>[];
      final client = ApiClient(
        baseUrl: 'http://x',
        httpClient: MockClient.streaming((request, bodyStream) async {
          // Drain the multipart body like a real server would; this
          // drives the chunked progress callbacks under test.
          await bodyStream.drain();
          final body = jsonEncode({'id': 'd1'});
          return http.StreamedResponse(
              Stream.value(utf8.encode(body)), 200,
              contentLength: body.length);
        }),
      );
      final bytes =
          Uint8List.fromList(List.filled(200 * 1024, 7));
      final id = await client.uploadMultipart(
        '/up',
        fileField: 'file',
        fileName: 'a.pdf',
        contentType: 'application/pdf',
        bytes: bytes,
        onProgress: (s, t) {
          expect(t, bytes.length);
          seen.add(s);
        },
        decode: (j) => (j as Map)['id'] as String,
      );
      expect(id, 'd1');
      expect(seen, isNotEmpty);
      expect(seen.last, bytes.length);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });
  });
}
