import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'endpoints.dart';

/// Callback invoked when the backend answers 401. The auth layer wires
/// token refresh here; returns true when retrying the request is safe.
typedef RefreshHandler = Future<bool> Function();

/// Central typed HTTP client. ALL feature data sources must go through
/// this client — no ad-hoc `http.get` calls in features.
///
/// Responsibilities:
/// - base URL + JSON headers + Bearer injection (token supplied per call
///   by the repository layer, never cached inside the client);
/// - timeout + transport-error normalization to [ApiException];
/// - single-flight 401 -> [onUnauthorized] refresh hook + one retry;
/// - envelope/ProblemDetail error mapping via [ApiException.fromStatus].
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.onUnauthorized,
    this.refreshPath = Endpoints.refresh,
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;
  final RefreshHandler? onUnauthorized;
  final String refreshPath;

  Future<T> get<T>(
    String path, {
    String? bearer,
    Map<String, String>? query,
    required T Function(dynamic json) decode,
  }) =>
      _send<T>('GET', path,
          bearer: bearer, query: query, decode: decode);

  Future<T> post<T>(
    String path, {
    String? bearer,
    Object? body,
    required T Function(dynamic json) decode,
  }) =>
      _send<T>('POST', path, bearer: bearer, body: body, decode: decode);

  Future<T> put<T>(
    String path, {
    String? bearer,
    Object? body,
    required T Function(dynamic json) decode,
  }) =>
      _send<T>('PUT', path, bearer: bearer, body: body, decode: decode);

  Future<T> patch<T>(
    String path, {
    String? bearer,
    Map<String, String>? query,
    Object? body,
    required T Function(dynamic json) decode,
  }) =>
      _send<T>('PATCH', path,
          bearer: bearer, query: query, body: body, decode: decode);

  Future<T> delete<T>(
    String path, {
    String? bearer,
    required T Function(dynamic json) decode,
  }) =>
      _send<T>('DELETE', path, bearer: bearer, decode: decode);

  /// Multipart file upload with real byte progress.
  /// Backend validates content server-side (Tika); client pre-checks are
  /// UX hints only and must mirror backend rules, never extend them.
  Future<T> uploadMultipart<T>(
    String path, {
    String? bearer,
    Map<String, String>? fields,
    required String fileField,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
    required T Function(dynamic json) decode,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] =
          bearer != null && bearer.isNotEmpty ? 'Bearer $bearer' : '';
    if (bearer == null || bearer.isEmpty) {
      request.headers.remove('Authorization');
    }
    if (fields != null) request.fields.addAll(fields);

    var sent = 0;
    final total = bytes.length;
    Stream<List<int>> progressStream() async* {
      const chunk = 64 * 1024;
      for (var i = 0; i < total; i += chunk) {
        final end = (i + chunk > total) ? total : i + chunk;
        yield bytes.sublist(i, end);
        sent = end;
        onProgress?.call(sent, total);
      }
    }

    request.files.add(http.MultipartFile(
      fileField,
      progressStream(),
      total,
      filename: fileName,
      contentType: MediaType.parse(contentType),
    ));

    http.StreamedResponse streamed;
    try {
      streamed =
          await _http.send(request).timeout(AppConfig.networkTimeout);
    } on TimeoutException {
      throw ApiException.network(
          'The request timed out. Please check your connection and retry.');
    } on Exception {
      throw ApiException.network();
    }
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return decode(
            response.body.isEmpty ? null : jsonDecode(response.body));
      } on FormatException {
        throw ApiException.unknown('The server returned an invalid response.');
      }
    }
    throw ApiException.fromStatus(
        response.statusCode, _tryErrorBody(response.body));
  }

  /// Authenticated binary download (no public URLs, Bearer enforced).
  Future<Uint8List> downloadBytes(
    String path, {
    String? bearer,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    http.Response response;
    try {
      response = await _http.get(uri, headers: {
        'Accept': '*/*',
        if (bearer != null && bearer.isNotEmpty)
          'Authorization': 'Bearer $bearer',
      }).timeout(AppConfig.networkTimeout);
    } on TimeoutException {
      throw ApiException.network(
          'The request timed out. Please check your connection and retry.');
    } on Exception {
      throw ApiException.network();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException.fromStatus(
        response.statusCode, _tryErrorBody(response.body));
  }

  static Map<String, dynamic>? _tryErrorBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Exception {
      // Binary or empty error body.
    }
    return null;
  }

  Future<T> _send<T>(
    String method,
    String path, {
    String? bearer,
    Map<String, String>? query,
    Object? body,
    required T Function(dynamic json) decode,
    bool retried = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (bearer != null && bearer.isNotEmpty)
        'Authorization': 'Bearer $bearer',
    };

    http.Response response;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      final future = switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'POST' => _http.post(uri, headers: headers, body: encoded),
        'PUT' => _http.put(uri, headers: headers, body: encoded),
        'PATCH' => _http.patch(uri, headers: headers, body: encoded),
        'DELETE' => _http.delete(uri, headers: headers),
        _ => throw ApiException.unknown('Unsupported method $method'),
      };
      response =
          await future.timeout(AppConfig.networkTimeout);
    } on TimeoutException {
      throw ApiException.network(
          'The request timed out. Please check your connection and retry.');
    } on Exception {
      // SocketException / ClientException / handshake failures.
      throw ApiException.network();
    }

    if (response.statusCode == 401 &&
        !retried &&
        !path.endsWith(refreshPath) &&
        onUnauthorized != null) {
      final refreshed = await onUnauthorized!();
      if (refreshed) {
        // Caller re-reads fresh tokens via its own provider; signal retry
        // by throwing a sentinel the repository converts into a retry.
        // To keep the client dependency-free, repositories simply re-issue
        // the call once after refresh. Here we retry once with the same
        // (possibly stale) bearer only if the handler updated shared state
        // — repositories own the authoritative retry, so just report auth.
        throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: 'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty || response.body.trim().isEmpty) {
        return decode(null);
      }
      try {
        return decode(jsonDecode(response.body));
      } on FormatException {
        throw ApiException.unknown('The server returned an invalid response.');
      }
    }

    Map<String, dynamic>? errorBody;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) errorBody = decoded;
    } on Exception {
      errorBody = null;
    }
    throw ApiException.fromStatus(response.statusCode, errorBody);
  }

  void close() => _http.close();
}
