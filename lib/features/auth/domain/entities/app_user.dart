/// Mobile-supported roles. The backend owns authorization; this enum is
/// navigation convenience only (UI_UX.md §13). Staff roles that exist on
/// the backend (HR/FINANCE/DIRECTOR/ADMIN/CANDIDATE) are mapped to
/// [unsupported] so the app shows an explicit access-denied state.
enum UserRole { intern, supervisor, unsupported }

UserRole userRoleFromBackend(List<String> roles) {
  // Live backend issues Spring-style authorities ("ROLE_SUPERVISOR").
  // Strip the prefix before matching (verified against /api/auth/login).
  final upper = roles
      .map((r) => r.toUpperCase().startsWith('ROLE_')
          ? r.toUpperCase().substring(5)
          : r.toUpperCase())
      .toSet();
  // SUPERVISOREmployees may carry both; supervisor shell wins for staff UX.
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
  });

  final String id;
  final String email;
  final List<String> roles;

  UserRole get mobileRole => userRoleFromBackend(roles);
}
