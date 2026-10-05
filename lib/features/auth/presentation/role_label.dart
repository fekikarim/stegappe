import '../../../core/l10n/app_localizations.dart';
import '../domain/entities/app_user.dart';

/// Localized role label — the single source of truth for the shell semantics
/// and the More tab, so a role can never be announced incorrectly (SH-PRO-01).
///
/// Lives outside `role_shells.dart` so `more_tab.dart` can use it without a
/// circular import.
String roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
      UserRole.intern => l10n.roleIntern,
      UserRole.supervisor => l10n.roleSupervisor,
      UserRole.adminSupervisor => l10n.roleAdminSupervisor,
      UserRole.unsupported => l10n.unsupportedRole,
    };
