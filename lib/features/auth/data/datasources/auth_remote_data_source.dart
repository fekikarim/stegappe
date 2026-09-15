import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/auth_models.dart';

/// Remote data source: thin HTTP wrapper. No business logic, no storage.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<AuthTokens> login(LoginRequest request) => _client.post(
        Endpoints.login,
        body: request.toJson(),
        decode: (json) =>
            AuthTokens.fromJson(json as Map<String, dynamic>),
      );

  Future<AuthTokens> refresh(String refreshToken) => _client.post(
        Endpoints.refresh,
        body: {'refreshToken': refreshToken},
        decode: (json) =>
            AuthTokens.fromJson(json as Map<String, dynamic>),
      );

  Future<void> logout(String? accessToken) => _client.post(
        Endpoints.logout,
        bearer: accessToken,
        decode: (_) {},
      );
}
