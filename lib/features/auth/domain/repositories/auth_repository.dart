import '../entities/app_user.dart';

/// Auth repository contract (domain layer — pure Dart, no Flutter imports).
abstract class AuthRepository {
  Future<AppUser> login({required String email, required String password});
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    throw UnimplementedError(
      'Password change is not available in this repository.',
    );
  }

  Future<void> logout();
  Future<AppUser?> restoreSession();
  Future<bool> refreshSession();
}
