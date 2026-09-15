import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/network/api_exception.dart';

void main() {
  group('ApiException.fromStatus', () {
    test('maps STEG envelope with fieldErrors to validation', () {
      final e = ApiException.fromStatus(400, {
        'timestamp': '2026-09-15T00:00:00Z',
        'status': 400,
        'error': 'Bad Request',
        'message': 'Validation failed',
        'path': '/api/auth/login',
        'traceId': 'abc-123',
        'fieldErrors': [
          {'field': 'email', 'message': 'must be a valid email'},
        ],
      });
      expect(e.kind, ApiErrorKind.validation);
      expect(e.fieldMessage('email'), 'must be a valid email');
      expect(e.traceId, 'abc-123');
      expect(e.path, '/api/auth/login');
    });

    test('maps Spring ProblemDetail shape', () {
      final e = ApiException.fromStatus(403, {
        'title': 'Forbidden',
        'status': 403,
        'detail': 'Access denied',
        'instance': '/api/finance-cases/1/approve',
      });
      expect(e.kind, ApiErrorKind.forbidden);
      expect(e.message, 'Access denied');
      expect(e.code, 'Forbidden');
    });

    test('maps status codes without body', () {
      expect(ApiException.fromStatus(401, null).kind,
          ApiErrorKind.unauthorized);
      expect(
          ApiException.fromStatus(404, null).kind, ApiErrorKind.notFound);
      expect(
          ApiException.fromStatus(409, null).kind, ApiErrorKind.conflict);
      expect(
          ApiException.fromStatus(500, null).kind, ApiErrorKind.server);
    });

    test('network factory', () {
      expect(ApiException.network().kind, ApiErrorKind.network);
    });
  });
}
