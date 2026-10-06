import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/internship.dart';
import '../../domain/entities/logbook.dart';
import '../../domain/entities/work_items.dart';
import '../../domain/task_board.dart';

/// Localized labels for backend-owned enums. Centralized so no screen
/// hard-codes status wording (UI_UX.md §8.1, §9.4).
String internshipTypeLabel(InternshipType? type, AppLocalizations l10n) =>
    switch (type) {
      InternshipType.observation => l10n.typeObservation,
      InternshipType.perfectionnement => l10n.typePerfectionnement,
      InternshipType.pfe => l10n.typePFE,
      null => '—',
    };

String internshipStatusLabel(
        InternshipStatus status, AppLocalizations l10n) =>
    switch (status) {
      InternshipStatus.approved => l10n.stApproved,
      InternshipStatus.inProgress => l10n.stInProgress,
      InternshipStatus.reportSubmitted => l10n.stReportSubmitted,
      InternshipStatus.underValidation => l10n.stUnderValidation,
      InternshipStatus.validated => l10n.stValidated,
      InternshipStatus.receiptIssued => l10n.stReceiptIssued,
      InternshipStatus.cancelled => l10n.stCancelled,
      InternshipStatus.archived => l10n.stArchived,
    };

StegStatusKind internshipStatusKind(InternshipStatus status) =>
    switch (status) {
      InternshipStatus.approved => StegStatusKind.neutral,
      InternshipStatus.inProgress => StegStatusKind.info,
      InternshipStatus.reportSubmitted => StegStatusKind.info,
      InternshipStatus.underValidation => StegStatusKind.info,
      InternshipStatus.validated => StegStatusKind.success,
      InternshipStatus.receiptIssued => StegStatusKind.success,
      InternshipStatus.cancelled => StegStatusKind.error,
      InternshipStatus.archived => StegStatusKind.neutral,
    };

/// Localized status wording. `COMPLETED` reads "awaiting approval", never
/// "done" (BR-11/D6); an unknown value says so instead of guessing.
String taskStatusLabel(TaskStatus status, AppLocalizations l10n) =>
    switch (status) {
      TaskStatus.todo => l10n.tsTodo,
      TaskStatus.inProgress => l10n.tsInProgress,
      TaskStatus.awaitingApproval => l10n.tsAwaitingApproval,
      TaskStatus.approved => l10n.tsApproved,
      TaskStatus.denied => l10n.tsDenied,
      TaskStatus.cancelled => l10n.tsCancelled,
      TaskStatus.unknown => l10n.tsUnknown,
    };

/// Semantic tone per status (the chip always carries the label too, so the
/// meaning never depends on colour alone). Overdue only tints tasks that are
/// still the student's to do.
StegStatusKind taskStatusKind(TaskStatus status, {required bool overdue}) {
  if (overdue &&
      (status == TaskStatus.todo || status == TaskStatus.inProgress)) {
    return StegStatusKind.error;
  }
  return switch (status) {
    TaskStatus.todo => StegStatusKind.neutral,
    TaskStatus.inProgress => StegStatusKind.info,
    // Work is finished but not accepted: a decision is pending.
    TaskStatus.awaitingApproval => StegStatusKind.warning,
    TaskStatus.approved => StegStatusKind.success,
    // Denied carries the supervisor's reason: the student must act.
    TaskStatus.denied => StegStatusKind.error,
    TaskStatus.cancelled => StegStatusKind.neutral,
    TaskStatus.unknown => StegStatusKind.warning,
  };
}

/// Board section wording (ST-TASK-01): the attention section is the one the
/// app used to hide entirely.
String taskGroupLabel(TaskGroup group, AppLocalizations l10n) =>
    switch (group) {
      TaskGroup.todo => l10n.tsTodo,
      TaskGroup.inProgress => l10n.tsInProgress,
      TaskGroup.attention => l10n.taskGroupAttention,
      TaskGroup.done => l10n.filterDone,
      TaskGroup.cancelled => l10n.tsCancelled,
      TaskGroup.unknown => l10n.tsUnknown,
    };

StegStatusKind taskGroupKind(TaskGroup group) => switch (group) {
      TaskGroup.todo => StegStatusKind.neutral,
      TaskGroup.inProgress => StegStatusKind.info,
      TaskGroup.attention => StegStatusKind.warning,
      TaskGroup.done => StegStatusKind.success,
      TaskGroup.cancelled => StegStatusKind.neutral,
      TaskGroup.unknown => StegStatusKind.warning,
    };

/// Label of the button that applies [to] from [from] — the single place that
/// says what a student action is called. Completion is offered as "submit for
/// review", never as a final done (BR-11); withdrawing a completion, resuming a
/// denied task and starting a to-do each have their own wording.
String taskTransitionLabel(
        TaskStatus from, TaskStatus to, AppLocalizations l10n) {
  if (to == TaskStatus.awaitingApproval) return l10n.taskSubmitForReview;
  if (to == TaskStatus.inProgress) {
    return switch (from) {
      TaskStatus.awaitingApproval => l10n.taskReopen,
      TaskStatus.denied => l10n.taskBackToProgress,
      _ => l10n.taskSetInProgress,
    };
  }
  return taskStatusLabel(to, l10n);
}

String journalStatusLabel(JournalStatus status, AppLocalizations l10n) =>
    switch (status) {
      JournalStatus.draft => l10n.jsDraft,
      JournalStatus.submitted => l10n.jsSubmitted,
      JournalStatus.validated => l10n.jsValidated,
      JournalStatus.rejected => l10n.jsRejected,
    };

StegStatusKind journalStatusKind(JournalStatus status) =>
    switch (status) {
      JournalStatus.draft => StegStatusKind.neutral,
      JournalStatus.submitted => StegStatusKind.info,
      JournalStatus.validated => StegStatusKind.success,
      JournalStatus.rejected => StegStatusKind.warning,
    };

String deliverableStatusLabel(
        DeliverableStatus status, AppLocalizations l10n) =>
    switch (status) {
      DeliverableStatus.draft => l10n.jsDraft,
      DeliverableStatus.submitted => l10n.jsSubmitted,
      DeliverableStatus.validated => l10n.jsValidated,
      DeliverableStatus.rejected => l10n.jsRejected,
    };

StegStatusKind deliverableStatusKind(DeliverableStatus status) =>
    switch (status) {
      DeliverableStatus.draft => StegStatusKind.neutral,
      DeliverableStatus.submitted => StegStatusKind.info,
      DeliverableStatus.validated => StegStatusKind.success,
      DeliverableStatus.rejected => StegStatusKind.warning,
    };

String logbookStatusLabel(LogbookStatus status, AppLocalizations l10n) =>
    switch (status) {
      LogbookStatus.draft => l10n.jsDraft,
      LogbookStatus.submitted => l10n.logbookStatusSubmitted,
      LogbookStatus.validated => l10n.logbookStatusValidated,
      LogbookStatus.rejected => l10n.logbookStatusRejected,
      LogbookStatus.official => l10n.logbookStatusOfficial,
      LogbookStatus.unknown => l10n.jsDraft,
    };

StegStatusKind logbookStatusKind(LogbookStatus status) =>
    switch (status) {
      LogbookStatus.draft => StegStatusKind.neutral,
      LogbookStatus.submitted => StegStatusKind.info,
      LogbookStatus.validated => StegStatusKind.success,
      LogbookStatus.rejected => StegStatusKind.warning,
      LogbookStatus.official => StegStatusKind.success,
      LogbookStatus.unknown => StegStatusKind.neutral,
    };

String priorityLabel(String priority, AppLocalizations l10n) =>
    switch (priority.toUpperCase()) {
      'LOW' => l10n.prLow,
      'HIGH' => l10n.prHigh,
      'URGENT' => l10n.prUrgent,
      _ => l10n.prNormal,
    };

StegStatusKind priorityKind(String priority) =>
    switch (priority.toUpperCase()) {
      'URGENT' => StegStatusKind.error,
      'HIGH' => StegStatusKind.warning,
      _ => StegStatusKind.neutral,
    };

String evaluationKindLabel(EvaluationKind kind, AppLocalizations l10n) =>
    switch (kind) {
      EvaluationKind.daily => l10n.evalTypeDaily,
      EvaluationKind.weekly => l10n.evalTypeWeekly,
      EvaluationKind.midTerm => l10n.evalTypeMid,
      EvaluationKind.final_ => l10n.evalTypeFinal,
      EvaluationKind.custom => l10n.evalTypeCustom,
    };

/// Localized short date, e.g. `15 sept. 2026` / `Sep 15, 2026` /
/// Arabic equivalent. Uses the active locale — never hard-coded format.
String formatDay(DateTime date, Locale locale) {
  try {
    return DateFormat.yMMMd(locale.languageCode).format(date);
  } on Exception {
    return DateFormat.yMMMd().format(date);
  }
}
