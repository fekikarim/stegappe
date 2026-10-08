/// T01/D11 — visuals for the notification catalogue.
///
/// Every mapping is an exhaustive `switch` over `NotificationType`: adding a
/// catalogue key (or a new backend value) without a label, an icon and a
/// semantic kind is a compile error, never a silently generic row. The colour
/// always travels with an icon *and* the localized label
/// (`StegStatusChip` + `notificationTypeLabel`), so a row is never classified
/// by colour alone (UX_UI.md §2.3).
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/notification_item.dart';

/// Distinct localized label per catalogue key; [NotificationType.unknown]
/// (legacy row / newer backend value) renders generically instead of guessing.
String notificationTypeLabel(NotificationType type, AppLocalizations l10n) =>
    switch (type) {
      NotificationType.taskAssigned => l10n.notifTypeTaskAssigned,
      NotificationType.taskUpdated => l10n.notifTypeTaskUpdated,
      NotificationType.taskDeleted => l10n.notifTypeTaskDeleted,
      NotificationType.taskStatusChanged => l10n.notifTypeTaskStatusChanged,
      NotificationType.scheduledTaskVisible =>
        l10n.notifTypeScheduledTaskVisible,
      NotificationType.documentRejected => l10n.notifTypeDocumentRejected,
      NotificationType.documentVerified => l10n.notifTypeDocumentVerified,
      NotificationType.applicationSubmitted =>
        l10n.notifTypeApplicationSubmitted,
      NotificationType.applicationResubmitted =>
        l10n.notifTypeApplicationResubmitted,
      NotificationType.applicationAccepted =>
        l10n.notifTypeApplicationAccepted,
      NotificationType.applicationRejected =>
        l10n.notifTypeApplicationRejected,
      NotificationType.applicationModificationRequested =>
        l10n.notifTypeApplicationModification,
      NotificationType.candidateValidated => l10n.notifTypeCandidateValidated,
      NotificationType.internshipAssigned => l10n.notifTypeInternshipAssigned,
      NotificationType.internshipStatusChanged =>
        l10n.notifTypeInternshipStatusChanged,
      NotificationType.internshipReportSubmitted =>
        l10n.notifTypeInternshipReportSubmitted,
      NotificationType.journalEntryValidated =>
        l10n.notifTypeJournalValidated,
      NotificationType.finalEvaluationRequired =>
        l10n.notifTypeFinalEvaluationRequired,
      NotificationType.paymentApproved => l10n.notifTypePaymentApproved,
      NotificationType.certificateAvailable =>
        l10n.notifTypeCertificateAvailable,
      NotificationType.messageReceived => l10n.notifTypeMessageReceived,
      NotificationType.welcome => l10n.notifTypeWelcome,
      NotificationType.communityComment =>
        l10n.notifTypeCommunityComment,
      NotificationType.communityPostRemoved =>
        l10n.notifTypeCommunityPostRemoved,
      NotificationType.communityCommentRemoved =>
        l10n.notifTypeCommunityCommentRemoved,
      NotificationType.documentsPreparationRequested =>
        l10n.notifTypeDocumentsPreparation,
      NotificationType.unknown => l10n.notifTypeGeneric,
    };

/// Distinct icon per catalogue key (acceptance 1: recognizable at a glance).
IconData notificationTypeIcon(NotificationType type) => switch (type) {
      NotificationType.taskAssigned => Icons.add_task,
      NotificationType.taskUpdated => Icons.edit_note,
      NotificationType.taskDeleted => Icons.delete_outline,
      NotificationType.taskStatusChanged => Icons.sync_alt,
      NotificationType.scheduledTaskVisible => Icons.schedule_outlined,
      NotificationType.documentRejected => Icons.cancel_outlined,
      NotificationType.documentVerified => Icons.verified_outlined,
      NotificationType.applicationSubmitted => Icons.send_outlined,
      NotificationType.applicationResubmitted => Icons.refresh,
      NotificationType.applicationAccepted => Icons.thumb_up_outlined,
      NotificationType.applicationRejected => Icons.thumb_down_outlined,
      NotificationType.applicationModificationRequested =>
        Icons.rate_review_outlined,
      NotificationType.candidateValidated => Icons.how_to_reg_outlined,
      NotificationType.internshipAssigned => Icons.work_outline,
      NotificationType.internshipStatusChanged => Icons.timeline,
      NotificationType.internshipReportSubmitted => Icons.upload_file_outlined,
      NotificationType.journalEntryValidated => Icons.menu_book_outlined,
      NotificationType.finalEvaluationRequired =>
        Icons.assignment_turned_in_outlined,
      NotificationType.paymentApproved => Icons.payments_outlined,
      NotificationType.certificateAvailable => Icons.workspace_premium_outlined,
      NotificationType.messageReceived => Icons.forum_outlined,
      NotificationType.welcome => Icons.waving_hand_outlined,
      // T08/D7 community keys must stay pairwise-distinct, so the
      // removals reuse neither taskDeleted's delete_outline nor each other.
      NotificationType.communityComment => Icons.reply_outlined,
      NotificationType.communityPostRemoved =>
        Icons.delete_forever_outlined,
      NotificationType.communityCommentRemoved =>
        Icons.comments_disabled_outlined,
      // T14/D14 preparation request: incoming supervisor ask, distinct
      // from every key above (pairwise-distinctness is test-guarded).
      NotificationType.documentsPreparationRequested =>
        Icons.inbox_outlined,
      NotificationType.unknown => Icons.notifications_outlined,
    };

/// Semantic tone of a catalogue key, rendered through the shared
/// [StegStatusChip] palette (info / success / warning / error / neutral).
StegStatusKind notificationTypeKind(NotificationType type) => switch (type) {
      // Community removals are moderation facts: warning tone, never
  // error-red alarm (the user did nothing wrong by reading them).
  NotificationType.communityPostRemoved ||
  NotificationType.communityCommentRemoved =>
    StegStatusKind.warning,
  NotificationType.documentRejected ||
      NotificationType.taskDeleted ||
      NotificationType.applicationRejected =>
        StegStatusKind.error,
      NotificationType.applicationModificationRequested ||
      NotificationType.finalEvaluationRequired =>
        StegStatusKind.warning,
      NotificationType.documentVerified ||
      NotificationType.journalEntryValidated ||
      NotificationType.taskStatusChanged ||
      NotificationType.applicationAccepted ||
      NotificationType.candidateValidated ||
      NotificationType.paymentApproved ||
      NotificationType.certificateAvailable =>
        StegStatusKind.success,
      NotificationType.taskAssigned ||
      NotificationType.taskUpdated ||
      NotificationType.scheduledTaskVisible ||
      NotificationType.applicationSubmitted ||
      NotificationType.applicationResubmitted ||
      NotificationType.internshipAssigned ||
      NotificationType.internshipStatusChanged ||
      NotificationType.internshipReportSubmitted ||
      NotificationType.messageReceived ||
      NotificationType.communityComment ||
      NotificationType.documentsPreparationRequested ||
      NotificationType.welcome =>
        StegStatusKind.info,
      NotificationType.unknown => StegStatusKind.neutral,
    };
