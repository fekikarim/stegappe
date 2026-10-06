import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

/// Central HTTP client. Constructed without auth dependencies so the
/// provider graph stays acyclic; repositories own 401 → refresh → retry.
/// The explicit provider type breaks the static inference cycle with
/// [authControllerProvider] (which transitively depends on this provider).
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    onPasswordChangeRequired: () {
      ref.read(authControllerProvider.notifier).requirePasswordChange();
    },
  ),
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    tokens: ref.watch(tokenStorageProvider),
  ),
);

/// Auth UI state machine.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AppUser user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message});
  final String? message;
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(AuthRepository repo)
    : _repo = repo,
      super(const AuthInitial());

  final AuthRepository _repo;
  ApiException? lastError;

  Future<void> bootstrap() async {
    state = const AuthLoading();
    try {
      final user = await _repo.restoreSession();
      state = user == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(user);
    } on ApiException catch (e) {
      lastError = e;
      state = AuthUnauthenticated(message: e.message);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final user = await _repo.login(email: email, password: password);
      state = AuthAuthenticated(user);
      return true;
    } on ApiException catch (e) {
      lastError = e;
      state = AuthUnauthenticated(message: e.message);
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = state;
    if (current is! AuthAuthenticated) return false;
    try {
      await _repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = AuthAuthenticated(
        AppUser(
          id: current.user.id,
          email: current.user.email,
          roles: current.user.roles,
        ),
      );
      return true;
    } on ApiException catch (e) {
      lastError = e;
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }

  /// T06 §10: sign out after an auth failure during a background flush.
  /// Carries a stable code (not a raw backend string); the login screen
  /// maps it to a localized notice, anything else renders raw as before.
  void signOutExpired() {
    state = const AuthUnauthenticated(message: 'queue-auth-discarded');
  }

  void requirePasswordChange() {
    final current = state;
    if (current is AuthAuthenticated) {
      state = AuthAuthenticated(
        AppUser(
          id: current.user.id,
          email: current.user.email,
          roles: current.user.roles,
          mustChangePassword: true,
        ),
      );
    }
  }
}
