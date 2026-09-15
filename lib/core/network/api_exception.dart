// Centralized, typed API error model.
//
// Maps (in priority order):
//  1. STEG error envelope `{timestamp,status,error,message,path,traceId,fieldErrors[]}`
//     (see backend Phase A0 global exception handling).
//  2. Spring Boot RFC-7807 ProblemDetail `{title,status,detail,instance}`.
//  3. Transport failures (no connectivity, timeout) -> [ApiErrorKind.network].
//
// UI layers must switch on [kind], never on raw HTTP codes or string contains.
enum ApiErrorKind {
  validation,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
  network,
  unknown,
}

/// Single field-level validation failure from `fieldErrors[]`.
class FieldError {
  const FieldError({required this.field, required this.message});

  final String field;
  final String message;

  factory FieldError.fromJson(Map<String, dynamic> json) => FieldError(
        field: (json['field'] ?? json['objectName'] ?? '').toString(),
        message: (json['message'] ?? json['defaultMessage'] ?? '').toString(),
      );
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.path,
    this.traceId,
    this.fieldErrors = const [],
  });

  final ApiErrorKind kind;
  final String message;

  /// Backend `error` string or ProblemDetail `title`.
  final String? code;
  final int? statusCode;
  final String? path;
  final String? traceId;
  final List<FieldError> fieldErrors;

  /// Field message lookup for form mapping, e.g. `error.fieldMessage('email')`.
  String? fieldMessage(String field) {
    for (final e in fieldErrors) {
      if (e.field == field || e.field.endsWith('.$field')) return e.message;
    }
    return null;
  }

  bool get isAuthError =>
      kind == ApiErrorKind.unauthorized || kind == ApiErrorKind.forbidden;

  factory ApiException.fromStatus(int status, Map<String, dynamic>? body) {
    final map = body ?? const <String, dynamic>{};
    final message = _string(map, ['message', 'detail', 'error']) ??
        _defaultMessage(status);
    final code = _string(map, ['error', 'title', 'code']);
    final path = _string(map, ['path', 'instance']);
    final traceId = _string(map, ['traceId', 'trace_id']);
    final fieldErrors = _fieldErrors(map);

    return ApiException(
      kind: _kindOf(status, fieldErrors),
      message: message,
      statusCode: status,
      code: code,
      path: path,
      traceId: traceId,
      fieldErrors: fieldErrors,
    );
  }

  factory ApiException.network([String? detail]) => ApiException(
        kind: ApiErrorKind.network,
        message: detail ??
            'No internet connection. Please check your network and retry.',
      );

  factory ApiException.unknown([String? detail]) => ApiException(
        kind: ApiErrorKind.unknown,
        message: detail ?? 'Something went wrong. Please try again.',
      );

  static ApiErrorKind _kindOf(int status, List<FieldError> fields) {
    if (status == 400 && fields.isNotEmpty) return ApiErrorKind.validation;
    return switch (status) {
      400 => ApiErrorKind.badRequest,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
  }

  static String? _string(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static List<FieldError> _fieldErrors(Map<String, dynamic> map) {
    final raw = map['fieldErrors'] ?? map['errors'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>) FieldError.fromJson(e),
    ];
  }

  static String _defaultMessage(int status) => switch (status) {
        400 => 'The request was invalid.',
        401 => 'Your session has expired. Please sign in again.',
        403 => 'You do not have permission to perform this action.',
        404 => 'The requested item was not found.',
        409 => 'This action conflicts with the current state. Please refresh.',
        >= 500 => 'The server is temporarily unavailable. Please try again.',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  String toString() =>
      'ApiException(kind: $kind, status: $statusCode, code: $code, message: $message)';
}
