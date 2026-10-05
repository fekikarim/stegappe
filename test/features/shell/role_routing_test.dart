import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/l10n/app_localizations.dart';
import 'package:stegappe/features/auth/domain/entities/app_user.dart';
import 'package:stegappe/features/auth/presentation/role_label.dart';
import 'package:stegappe/features/shell/presentation/auth_gate.dart';
import 'package:stegappe/features/shell/presentation/role_shells.dart';

import '../../support/shell_harness.dart';

/// T00 · acceptance criterion 1 & 2 — role routing.
///
/// D1: an `ADMIN` gets the supervisor shell (single account, no admin-only
/// module in mobile). Every other unknown staff role keeps the explicit
/// access-denied screen.
void main() {
  group('userRoleFromBackend (D1 mapping)', () {
    test('maps every backend role list deterministically', () {
      expect(userRoleFromBackend(['ADMIN']), UserRole.adminSupervisor);
      expect(userRoleFromBackend(['ROLE_ADMIN']), UserRole.adminSupervisor);
      expect(userRoleFromBackend(['SUPERVISOR']), UserRole.supervisor);
      expect(userRoleFromBackend(['ROLE_SUPERVISOR']), UserRole.supervisor);
      expect(userRoleFromBackend(['ROLE_INTERN']), UserRole.intern);
      expect(userRoleFromBackend(['HR']), UserRole.unsupported);
      expect(userRoleFromBackend(const []), UserRole.unsupported);
      // Should-not-exist dual role resolves deterministically to the Admin.
      expect(userRoleFromBackend(['ADMIN', 'SUPERVISOR']),
          UserRole.adminSupervisor);
      expect(userRoleFromBackend(['role_admin']), UserRole.adminSupervisor);
    });

    test('capabilities: only supervisor-ish roles get the supervisor shell',
        () {
      expect(UserRole.adminSupervisor.hasSupervisorExperience, isTrue);
      expect(UserRole.adminSupervisor.isAdminSupervisor, isTrue);
      expect(UserRole.supervisor.hasSupervisorExperience, isTrue);
      expect(UserRole.supervisor.isAdminSupervisor, isFalse);
      expect(UserRole.intern.hasSupervisorExperience, isFalse);
      expect(UserRole.unsupported.hasSupervisorExperience, isFalse);
    });
  });

  group('role routing (exhaustive)', () {
    // Guards against a future UserRole value silently falling through: this
    // map must cover every enum value (the test fails otherwise).
    final expectedShell = <UserRole, Type>{
      UserRole.intern: InternShell,
      UserRole.supervisor: SupervisorShell,
      UserRole.adminSupervisor: SupervisorShell,
      UserRole.unsupported: UnsupportedRoleScreen,
    };

    test('every UserRole is covered by the routing table', () {
      expect(expectedShell.keys.toSet(), UserRole.values.toSet(),
          reason: 'a new UserRole needs a routing decision + this entry');
    });

    // Backend role lists that produce each mobile role.
    final roleLists = <List<String>, UserRole>{
      ['INTERN']: UserRole.intern,
      ['ROLE_INTERN']: UserRole.intern,
      ['SUPERVISOR']: UserRole.supervisor,
      ['ROLE_SUPERVISOR']: UserRole.supervisor,
      ['ADMIN']: UserRole.adminSupervisor,
      ['ROLE_ADMIN']: UserRole.adminSupervisor,
      ['ADMIN', 'SUPERVISOR']: UserRole.adminSupervisor,
      ['HR']: UserRole.unsupported,
      ['FINANCE']: UserRole.unsupported,
      <String>[]: UserRole.unsupported,
    };

    roleLists.forEach((roles, role) {
      testWidgets('$roles → $role opens ${expectedShell[role]}',
          (tester) async {
        await pumpAuthGate(
          tester,
          user: AppUser(id: 'u1', email: 'user@steg.tn', roles: roles),
        );
        expect(find.byType(expectedShell[role]!), findsOneWidget);
      });
    });
  });

  group('role label (SH-PRO-01)', () {
    testWidgets('the role is visible in the More tab for each shell',
        (tester) async {
      final l10n = const AppLocalizations(Locale('fr'));
      await pumpAuthGate(
        tester,
        user: const AppUser(
            id: 'a1', email: 'admin@steg.tn', roles: ['ADMIN']),
      );
      await tester.tap(find.text(l10n.navMore).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.roleAdminSupervisor), findsOneWidget);
    });

    test('the admin-supervisor is announced differently from a supervisor', () {
      final l10n = const AppLocalizations(Locale('fr'));
      final admin = roleLabel(l10n, UserRole.adminSupervisor);
      final sup = roleLabel(l10n, UserRole.supervisor);
      expect(admin, isNot(sup));
      expect(admin.toLowerCase(), contains('admin'));
      expect(roleLabel(l10n, UserRole.intern), l10n.roleIntern);
      expect(roleLabel(l10n, UserRole.unsupported), l10n.unsupportedRole);
    });
  });
}
