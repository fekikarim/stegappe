import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/network/endpoints.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/shell/presentation/role_shells.dart';

import '../../support/shell_harness.dart';

/// T00 · acceptance criterion 1 — BR-07 enforcement.
///
/// Admin-only staff capabilities (validation queue, certificates, supervisors,
/// audit, intern-account management, applications) must never be reachable
/// from the mobile shell, including the Admin-as-supervisor shell.
void main() {
  // Base paths of the back-office-only modules (verified against the backend
  // controllers on 2026-10-05). A mobile build must reference none of them.
  const adminOnlyPaths = <String>[
    '/api/applications',
    '/api/audit',
    '/api/intern-accounts',
    '/api/internship-validation',
    '/api/supervisors',
    '/api/certificates',
    '/certificates',
  ];

  group('mobile source never references an admin-only endpoint', () {
    test('no file under lib/ contains an admin-only API path', () {
      final offenders = <String>[];
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue,
          reason: 'run `flutter test` from the stegappe package root');
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final path in adminOnlyPaths) {
          if (source.contains(path)) {
            offenders.add('${entity.path} → $path');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'BR-07: admin-only endpoints must not be reachable '
              'from the mobile app:\n${offenders.join('\n')}');
    });

    test('the mobile endpoint catalogue exposes no admin-only module', () {
      // Positive control: the participant endpoints really are present.
      expect(Endpoints.internships, '/api/internships');
      expect(Endpoints.conversations, '/api/conversations');
      expect(Endpoints.notifications, '/api/notifications');
      expect(Endpoints.aiAssistant, '/api/ai/assistant/query');

      final catalogue =
          File('lib/core/network/endpoints.dart').readAsStringSync();
      for (final path in adminOnlyPaths) {
        expect(catalogue.contains(path), isFalse,
            reason: 'the endpoint catalogue must not declare $path');
      }
    });
  });

  group('shells render no admin-only module', () {
    Future<void> assertNoAdminModule(WidgetTester tester, List<String> roles,
        Type shell) async {
      await pumpAuthGate(
        tester,
        user: AppUser(id: 'u1', email: 'user@steg.tn', roles: roles),
      );
      expect(find.byType(shell), findsOneWidget);
      // Five participant destinations only — no extra admin tab.
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      for (final label in const [
        'Certificats',
        'Audit',
        'Candidatures',
        'Superviseurs',
        'Validation du stage',
        'Comptes stagiaires',
      ]) {
        expect(find.text(label), findsNothing,
            reason: 'admin-only module "$label" leaked into mobile');
      }
    }

    testWidgets('supervisor shell has no admin module', (tester) async {
      await assertNoAdminModule(tester, ['SUPERVISOR'], SupervisorShell);
    });

    testWidgets('admin-supervisor shell has no admin module', (tester) async {
      await assertNoAdminModule(tester, ['ADMIN'], SupervisorShell);
    });
  });
}
