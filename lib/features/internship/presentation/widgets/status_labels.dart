import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/internship.dart';
import '../../domain/entities/work_items.dart';

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
      InternshipStatus.planned => l10n.stPlanned,
      InternshipStatus.active => l10n.stActive,
      InternshipStatus.completed => l10n.stCompleted,
      InternshipStatus.cancelled => l10n.stCancelled,
      InternshipStatus.archived => l10n.stArchived,
    };

StegStatusKind internshipStatusKind(InternshipStatus status) =>
    switch (status) {
      InternshipStatus.planned => StegStatusKind.neutral,
      InternshipStatus.active => StegStatusKind.info,
      InternshipStatus.completed => StegStatusKind.success,
      InternshipStatus.cancelled => StegStatusKind.error,
      InternshipStatus.archived => StegStatusKind.neutral,
    };

String taskStatusLabel(TaskStatus status, AppLocalizations l10n) =>
    switch (status) {
      TaskStatus.todo => l10n.tsTodo,
      TaskStatus.inProgress => l10n.tsInProgress,
      TaskStatus.completed => l10n.tsCompleted,
      TaskStatus.cancelled => l10n.tsCancelled,
    };

StegStatusKind taskStatusKind(TaskStatus status, {required bool overdue}) {
  if (overdue && status != TaskStatus.completed) {
    return StegStatusKind.error;
  }
  return switch (status) {
    TaskStatus.todo => StegStatusKind.neutral,
    TaskStatus.inProgress => StegStatusKind.info,
    TaskStatus.completed => StegStatusKind.success,
    TaskStatus.cancelled => StegStatusKind.neutral,
  };
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
