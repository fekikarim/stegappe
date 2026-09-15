import 'package:equatable/equatable.dart';

/// Task = PLANNED work (discussed with supervisor, then executed).
/// Distinct from JournalEntry (what actually happened) and Evaluation
/// (assessment of performance). Statuses are backend-owned.
enum TaskStatus { todo, inProgress, completed, cancelled }

TaskStatus taskStatusFrom(String? raw) => switch (raw?.toUpperCase()) {
      'IN_PROGRESS' => TaskStatus.inProgress,
      'COMPLETED' => TaskStatus.completed,
      'CANCELLED' => TaskStatus.cancelled,
      _ => TaskStatus.todo,
    };

String taskStatusToApi(TaskStatus s) => switch (s) {
      TaskStatus.todo => 'TODO',
      TaskStatus.inProgress => 'IN_PROGRESS',
      TaskStatus.completed => 'COMPLETED',
      TaskStatus.cancelled => 'CANCELLED',
    };

class InternTask extends Equatable {
  const InternTask({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;

  bool get isDone => status == TaskStatus.completed;
  bool get isOpen =>
      status == TaskStatus.todo || status == TaskStatus.inProgress;

  bool isOverdue(DateTime now) {
    if (!isOpen || dueDate == null) return false;
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final n = DateTime(now.year, now.month, now.day);
    return d.isBefore(n);
  }

  bool isDueToday(DateTime now) {
    if (dueDate == null) return false;
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  @override
  List<Object?> get props =>
      [id, title, description, status, dueDate, completedAt];
}

/// JournalEntry = record of what ACTUALLY happened (backend-owned status).
enum JournalStatus { draft, submitted, validated, rejected }

JournalStatus journalStatusFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'SUBMITTED' => JournalStatus.submitted,
      'VALIDATED' => JournalStatus.validated,
      'REJECTED' => JournalStatus.rejected,
      _ => JournalStatus.draft,
    };

String journalStatusToApi(JournalStatus s) => switch (s) {
      JournalStatus.draft => 'DRAFT',
      JournalStatus.submitted => 'SUBMITTED',
      JournalStatus.validated => 'VALIDATED',
      JournalStatus.rejected => 'REJECTED',
    };

class JournalEntry extends Equatable {
  const JournalEntry({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.entryDate,
    this.validatedByName,
    this.submittedAt,
    this.validatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final JournalStatus status;
  final DateTime entryDate;
  final String? validatedByName;
  final DateTime? submittedAt;
  final DateTime? validatedAt;

  bool get needsAttention =>
      status == JournalStatus.draft || status == JournalStatus.rejected;

  /// Server-created entries are immutable (no update endpoint exists):
  /// only DRAFT/REJECTED entries accept the submit transition.
  bool get canSubmit =>
      status == JournalStatus.draft || status == JournalStatus.rejected;

  bool get awaitsSupervisor => status == JournalStatus.submitted;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        status,
        entryDate,
        validatedByName,
        submittedAt,
        validatedAt,
      ];
}

/// Deliverable status (backend-owned; versioned in D3).
enum DeliverableStatus { draft, submitted, validated, rejected }

DeliverableStatus deliverableStatusFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'SUBMITTED' => DeliverableStatus.submitted,
      'VALIDATED' => DeliverableStatus.validated,
      'REJECTED' => DeliverableStatus.rejected,
      _ => DeliverableStatus.draft,
    };

/// Deliverable summary (versioned on backend; full flows in D3).
class DeliverableSummary extends Equatable {
  const DeliverableSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.currentVersion,
  });

  final String id;
  final String title;
  final DeliverableStatus status;
  final int currentVersion;

  bool get canSubmit =>
      status == DeliverableStatus.draft ||
      status == DeliverableStatus.rejected;
  bool get awaitsSupervisor => status == DeliverableStatus.submitted;

  /// Backend rejects new versions once validated (append-only history).
  bool get canUploadNewVersion => status != DeliverableStatus.validated;

  @override
  List<Object?> get props => [id, title, status, currentVersion];
}

/// One immutable file version. Versions are never overwritten —
/// re-uploading appends and bumps `currentVersion` server-side.
class DeliverableVersionInfo extends Equatable {
  const DeliverableVersionInfo({
    required this.id,
    required this.versionNumber,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.uploadedByEmail,
    this.changeSummary,
    required this.uploadedAt,
  });

  final String id;
  final int versionNumber;
  final String fileName;
  final String mimeType;
  final int size;
  final String uploadedByEmail;
  final String? changeSummary;
  final DateTime uploadedAt;

  @override
  List<Object?> get props => [
        id,
        versionNumber,
        fileName,
        mimeType,
        size,
        uploadedByEmail,
        changeSummary,
        uploadedAt,
      ];
}

/// Full deliverable with its version history (latest first for display).
class DeliverableDetail extends Equatable {
  const DeliverableDetail({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.currentVersion,
    this.submittedAt,
    this.validatedAt,
    this.validatedByName,
    this.versions = const [],
  });

  final String id;
  final String title;
  final String? description;
  final DeliverableStatus status;
  final int currentVersion;
  final DateTime? submittedAt;
  final DateTime? validatedAt;
  final String? validatedByName;
  final List<DeliverableVersionInfo> versions;

  bool get canSubmit =>
      status == DeliverableStatus.draft ||
      status == DeliverableStatus.rejected;
  bool get awaitsSupervisor => status == DeliverableStatus.submitted;
  bool get canUploadNewVersion => status != DeliverableStatus.validated;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        status,
        currentVersion,
        submittedAt,
        validatedAt,
        validatedByName,
        versions,
      ];
}

/// Evaluation = supervisor ASSESSMENT (backend-computed totalScore).
class EvaluationSummary extends Equatable {
  const EvaluationSummary({
    required this.id,
    required this.type,
    required this.evaluationDate,
    this.totalScore,
    this.feedback,
  });

  final String id;
  final String type;
  final DateTime evaluationDate;
  final double? totalScore;
  final String? feedback;

  @override
  List<Object?> get props => [id, type, evaluationDate, totalScore, feedback];
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final String priority;
  final DateTime createdAt;
  final bool isRead;

  bool get isUrgent =>
      priority.toUpperCase() == 'URGENT' ||
      priority.toUpperCase() == 'HIGH';

  @override
  List<Object?> get props =>
      [id, title, message, priority, createdAt, isRead];
}

/// Supervisor/intern feedback attached to a journal entry.
/// Participant-visible; fetched separately from the entry itself.
class JournalComment extends Equatable {
  const JournalComment({
    required this.id,
    required this.content,
    required this.authorEmail,
    required this.createdAt,
  });

  final String id;
  final String content;
  final String authorEmail;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, content, authorEmail, createdAt];
}
