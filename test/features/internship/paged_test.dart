import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/network/api_exception.dart';
import 'package:stegappe/core/network/paged.dart';

void main() {
  group('Paged.fromJson', () {
    test('parses the real Spring shape (content + page.*)', () {
      final page = Paged.fromJson(
        {
          'content': [
            {'id': 'a'},
            {'id': 'b'},
          ],
          'page': {
            'size': 5,
            'number': 0,
            'totalElements': 12,
            'totalPages': 3,
          },
        },
        (m) => m['id'] as String,
      );
      expect(page.items, ['a', 'b']);
      expect(page.totalElements, 12);
      expect(page.totalPages, 3);
      expect(page.isLast, isFalse);
    });

    test('falls back to the flat OpenAPI-documented shape', () {
      final page = Paged.fromJson(
        {
          'content': [
            {'id': 'a'},
          ],
          'totalElements': 1,
          'totalPages': 1,
          'number': 0,
        },
        (m) => m['id'] as String,
      );
      expect(page.items, ['a']);
      expect(page.totalElements, 1);
      expect(page.isLast, isTrue);
    });

    test('accepts bare lists (unread counts, conversations)', () {
      final page = Paged.fromJson(
        [
          {'unreadCount': 2},
          {'unreadCount': 3},
        ],
        (m) => (m['unreadCount'] as num).toInt(),
      );
      expect(page.items, [2, 3]);
      expect(page.isLast, isTrue);
    });
  });

  group('ApiException live-shape regressions', () {
    test('422 envelope maps to validation (bad login)', () {
      final e = ApiException.fromStatus(422, {
        'timestamp': '2026-09-15T22:19:27Z',
        'status': 422,
        'error': 'AUTHENTICATION_FAILED',
        'message': 'E-mail ou mot de passe incorrect.',
        'path': '/api/auth/login',
        'traceId': 't-1',
        'fieldErrors': [],
      });
      expect(e.kind, ApiErrorKind.validation);
      expect(e.traceId, 't-1');
    });

    test('403 envelope maps to forbidden', () {
      final e = ApiException.fromStatus(403, {
        'status': 403,
        'error': 'Access Denied',
        'message': 'You do not possess sufficient permissions.',
        'path': '/x',
        'traceId': 't-2',
        'fieldErrors': [],
      });
      expect(e.kind, ApiErrorKind.forbidden);
    });
  });
}
