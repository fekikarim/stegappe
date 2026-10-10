import '../../../auth/domain/entities/app_user.dart';
import '../../../internship/domain/dashboard.dart';
import '../../../internship/domain/entities/evaluation.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../domain/entities/conversation.dart';

/// Friendly display name for a conversation row / chat title.
///
/// 1-to-1 threads are named after the OTHER participant — never the raw
/// backend thread title (`"Internship STG-… — private thread"`) and never
/// the viewer's own internship reference:
/// - an intern sees his supervisor's name;
/// - a supervisor sees his intern's (candidate's) name.
/// Group threads keep their backend title. Anything unknown falls back to
/// the localized kind label, never to a reference.
String resolveConversationName({
  required Conversation conversation,
  required UserRole role,
  required AppLocalizations l10n,
  DashboardData? dashboard,
  List<SupervisedIntern>? supervised,
}) {
  if (!conversation.isPrivate) {
    return conversation.title.isEmpty
        ? l10n.convGroup
        : conversation.title;
  }
  String? peer;
  if (role == UserRole.intern) {
    peer = dashboard?.activeAssignment?.supervisorName;
  } else if (role.hasSupervisorExperience) {
    if (conversation.internshipId != null && supervised != null) {
      for (final s in supervised) {
        if (s.internshipId == conversation.internshipId) {
          peer = s.internName;
          break;
        }
      }
    }
  }
  if (peer != null && peer.trim().isNotEmpty) return peer.trim();
  final raw = conversation.title.trim();
  if (raw.isEmpty || raw.startsWith('Internship ')) {
    return l10n.convPrivate;
  }
  return raw;
}
