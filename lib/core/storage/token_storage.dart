import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for JWT access/refresh tokens.
///
/// SECURITY: tokens live ONLY here. Never in SharedPreferences,
/// never in logs, never in analytics. SharedPreferences ([PrefsStore])
/// is restricted to non-sensitive UI prefs (locale, theme).
abstract class TokenStorage {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _kAccess = 'steg.access_token.v1';
  static const _kRefresh = 'steg.refresh_token.v1';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) =>
      Future.wait([
        _storage.write(key: _kAccess, value: accessToken),
        _storage.write(key: _kRefresh, value: refreshToken),
      ]);

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccess);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  @override
  Future<void> clear() => Future.wait([
        _storage.delete(key: _kAccess),
        _storage.delete(key: _kRefresh),
      ]);
}

/// In-memory fake for widget/unit tests. Never used in production.
class InMemoryTokenStorage implements TokenStorage {
  String? access;
  String? refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}
