/// Mobile-supported roles. The backend owns authorization; this enum is
/// navigation convenience only (UI_UX.md §13).
///
/// Staff roles that exist on the backend but have no mobile surface
/// (HR/FINANCE/DIRECTOR/…) are mapped to [unsupported] so the app shows an
/// explicit access-denied state instead of guessing a shell.
///
/// [adminSupervisor] implements decision **D1**: the back office models the
/// Admin as also being a supervisor under a *single* account and role
/// (`todo/AGENTS.md` §3.2 — `ADMIN` ⊇ all `SUPERVISOR` permissions). On mobile
/// that means the Admin gets the Supervisor experience for the students he
/// actually supervises. It does **not** grant any admin-only staff module
/// (validation queue, certificates, supervisors, audit) — those stay in the
/// back office (BR-07).
enum UserRole { intern, supervisor, adminSupervisor, unsupported }

extension UserRoleCapabilities on UserRole {
  /// True for every role that gets the supervisor experience (the dedicated
  /// Supervisor role and the Admin-as-supervisor).
  bool get hasSupervisorExperience =>
      this == UserRole.supervisor || this == UserRole.adminSupervisor;

  /// True only for the Admin-as-supervisor account.
  bool get isAdminSupervisor => this == UserRole.adminSupervisor;
}

UserRole userRoleFromBackend(List<String> roles) {
  // Live backend issues Spring-style authorities ("ROLE_SUPERVISOR").
  // Strip the prefix before matching (verified against /api/auth/login).
  final upper = roles
      .map(
        (r) => r.toUpperCase().startsWith('ROLE_')
            ? r.toUpperCase().substring(5)
            : r.toUpperCase(),
      )
      .toSet();
  // Deterministic precedence for the (should-not-exist) dual-role case:
  // ADMIN wins because the Admin also supervises (D1); then SUPERVISOR; then
  // INTERN. Everything else is explicitly unsupported.
  if (upper.contains('ADMIN')) return UserRole.adminSupervisor;
  if (upper.contains('SUPERVISOR')) return UserRole.supervisor;
  if (upper.contains('INTERN')) return UserRole.intern;
  return UserRole.unsupported;
}

/// Authenticated user (minimal claims decoded from JWT for routing only).
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.roles,
    this.mustChangePassword = false,
  });

  final String id;
  final String email;
  final List<String> roles;
  final bool mustChangePassword;

  UserRole get mobileRole => userRoleFromBackend(roles);
}
