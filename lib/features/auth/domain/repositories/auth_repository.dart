import '../entities/app_user.dart';

/// Auth repository contract (domain layer — pure Dart, no Flutter imports).
abstract class AuthRepository {
  Future<AppUser> login({required String email, required String password});
  Future<void> logout();
  Future<AppUser?> restoreSession();
  Future<bool> refreshSession();
}
