import 'dart:convert';

import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_models.dart';

/// Repository implementation: coordinates remote DS + secure storage.
/// Role claims are decoded client-side for ROUTING ONLY; the backend
/// re-authorizes every request server-side.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.tokens,
  });

  final AuthRemoteDataSource remote;
  final TokenStorage tokens;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final authTokens = await remote.login(
      LoginRequest(email: email, password: password),
    );
    await tokens.saveTokens(
      accessToken: authTokens.accessToken,
      refreshToken: authTokens.refreshToken,
    );
    return _userFromAccessToken(authTokens.accessToken, email);
  }

  @override
  Future<void> logout() async {
    final access = await tokens.readAccessToken();
    try {
      await remote.logout(access);
    } on ApiException {
      // Logout is best-effort remotely; local tokens are always cleared.
    }
    await tokens.clear();
  }

  @override
  Future<AppUser?> restoreSession() async {
    final access = await tokens.readAccessToken();
    if (access == null || access.isEmpty) return null;
    if (_isExpired(access)) {
      final ok = await refreshSession();
      if (!ok) return null;
      final fresh = await tokens.readAccessToken();
      if (fresh == null || fresh.isEmpty) return null;
      return _userFromAccessToken(fresh, null);
    }
    return _userFromAccessToken(access, null);
  }

  @override
  Future<bool> refreshSession() async {
    final refresh = await tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final authTokens = await remote.refresh(refresh);
      await tokens.saveTokens(
        accessToken: authTokens.accessToken,
        refreshToken: authTokens.refreshToken,
      );
      return true;
    } on ApiException {
      await tokens.clear();
      return false;
    }
  }

  // --- JWT helpers (routing convenience only, no signature verification) ---

  static Map<String, dynamic> decodePayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return const {};
    try {
      final normalized = base64.normalize(parts[1]);
      final json =
          utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(json);
      return map is Map<String, dynamic> ? map : const {};
    } on Exception {
      return const {};
    }
  }

  static AppUser _userFromAccessToken(String jwt, String? emailFallback) {
    final payload = decodePayload(jwt);
    final roles = _rolesOf(payload);
    final id = (payload['sub'] ?? payload['userId'] ?? '').toString();
    final email = (payload['email'] ?? emailFallback ?? '').toString();
    return AppUser(id: id, email: email, roles: roles);
  }

  static List<String> _rolesOf(Map<String, dynamic> payload) {
    final raw = payload['roles'] ?? payload['authorities'];
    if (raw is List) return [for (final r in raw) r.toString()];
    if (raw is String) return [raw];
    return const [];
  }

  static bool _isExpired(String jwt) {
    final payload = decodePayload(jwt);
    final exp = payload['exp'];
    if (exp is! num) return false; // no claim => let backend decide
    final expiry =
        DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    return DateTime.now().isAfter(
      expiry.subtract(const Duration(seconds: 30)),
    );
  }
}
