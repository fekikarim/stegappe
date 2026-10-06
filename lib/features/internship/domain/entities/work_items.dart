import 'package:equatable/equatable.dart';

/// Task = PLANNED work (discussed with supervisor, then executed).
/// Distinct from JournalEntry (what actually happened) and Evaluation
/// (assessment of performance). Statuses are backend-owned
/// (`companion/domain/model/TaskStatus.java`, six values).
///
/// T02/D6 (BR-10, BR-11): every backend value is mapped explicitly and
/// `COMPLETED` is **not** done — the student finished his part and the
/// supervisor's review is pending ([TaskStatus.awaitingApproval]). Only
/// [TaskStatus.approved] counts as done; [TaskStatus.denied] carries the
/// supervisor's reason and is actionable again (BR-12/BR-13). A value this
/// app does not know (a newer backend) maps to [TaskStatus.unknown] and is
/// never silently displayed as "To do".
enum TaskStatus {
  todo,
  inProgress,
  awaitingApproval,
  approved,
  denied,
  cancelled,
  unknown,
}

/// Wire decode for `TaskResponse.status`. Never falls back to `todo`: an
/// unrecognised or missing value is [TaskStatus.unknown].
TaskStatus taskStatusFrom(String? raw) => switch (raw?.trim().toUpperCase()) {
      'TODO' => TaskStatus.todo,
      'IN_PROGRESS' => TaskStatus.inProgress,
      'COMPLETED' => TaskStatus.awaitingApproval,
      'APPROVED' => TaskStatus.approved,
      'DENIED' => TaskStatus.denied,
      'CANCELLED' => TaskStatus.cancelled,
      _ => TaskStatus.unknown,
    };

/// Wire encode for a status query/body, or null when nothing must be sent
/// ([TaskStatus.unknown] is not part of the backend vocabulary).
String? taskStatusToApi(TaskStatus s) => switch (s) {
      TaskStatus.todo => 'TODO',
      TaskStatus.inProgress => 'IN_PROGRESS',
      TaskStatus.awaitingApproval => 'COMPLETED',
      TaskStatus.approved => 'APPROVED',
      TaskStatus.denied => 'DENIED',
      TaskStatus.cancelled => 'CANCELLED',
      TaskStatus.unknown => null,
    };

/// Status a **student** may write (D6/BR-11): his own progress only.
/// `APPROVED`/`DENIED` are the supervisor's review decision
/// (`POST /tasks/{id}/review`, staff-only) and `CANCELLED` is a staff action,
/// so the board never offers them to the student — and the backend refuses
/// them for a participant (see `CompanionService`).
bool isStudentStatusTarget(TaskStatus s) =>
    s == TaskStatus.todo ||
    s == TaskStatus.inProgress ||
    s == TaskStatus.awaitingApproval;

/// The single source of the student's own transitions (ST-TASK-02, D6/BR-13).
/// Started work is never sent back to "To do": a denied task — or a completion
/// the student withdraws — returns to **In progress**. Approved, cancelled and
/// unknown tasks expose no student transition at all.
List<TaskStatus> studentTransitionsFrom(TaskStatus from) => switch (from) {
      TaskStatus.todo => const [TaskStatus.inProgress],
      TaskStatus.inProgress => const [TaskStatus.awaitingApproval],
      TaskStatus.awaitingApproval => const [TaskStatus.inProgress],
      TaskStatus.denied => const [TaskStatus.inProgress],
      TaskStatus.approved ||
      TaskStatus.cancelled ||
      TaskStatus.unknown =>
        const [],
    };

/// Target of the row's single optimistic control ("my part is done"): todo and
/// in-progress work is submitted for review, a completion under review or a
/// denial is withdrawn back to in-progress. `null` = the student has no action
/// (approved, cancelled, unknown) and the control is disabled.
TaskStatus? studentToggleTarget(TaskStatus from) => switch (from) {
      TaskStatus.todo || TaskStatus.inProgress => TaskStatus.awaitingApproval,
      TaskStatus.awaitingApproval || TaskStatus.denied => TaskStatus.inProgress,
      TaskStatus.approved ||
      TaskStatus.cancelled ||
      TaskStatus.unknown =>
        null,
    };

/// BR-14: the student edits/deletes only tasks **he** authored. A task whose
/// authorship is unknown (legacy row, absent `createdById`) is treated as
/// supervisor-authored: the safe answer is "not editable by the student".
bool studentOwnsTask(InternTask task, String? userId) =>
    userId != null && userId.isNotEmpty && task.createdById == userId;

class InternTask extends Equatable {
  const InternTask({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
    this.completedAt,
    this.createdById,
    this.assignedToId,
    this.reviewReason,
    this.reviewedAt,
  });

  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;

  /// `TaskResponse.createdById` — who authored the task (BR-14).
  final String? createdById;

  /// `TaskResponse.assignedToId` — who must do it.
  final String? assignedToId;

  /// `TaskResponse.reviewReason` — the supervisor's denial reason (BR-12).
  final String? reviewReason;

  /// `TaskResponse.reviewedAt` — when the supervisor decided.
  final DateTime? reviewedAt;

  /// BR-11: only an approved task is done. A completion under review is
  /// [awaitsReview], never done.
  bool get isDone => status == TaskStatus.approved;

  /// The student finished his part; the supervisor has not decided yet.
  bool get awaitsReview => status == TaskStatus.awaitingApproval;

  /// A denial the student must see (reason + next step, BR-12/BR-13).
  bool get needsAttention => status == TaskStatus.denied;

  bool get isOpen =>
      status == TaskStatus.todo || status == TaskStatus.inProgress;

  /// Denial reason trimmed for display; null when there is nothing to show.
  String? get denialReason {
    final reason = reviewReason?.trim();
    return (reason == null || reason.isEmpty) ? null : reason;
  }

  /// The transitions this student may apply right now (empty for approved,
  /// cancelled and unknown tasks).
  List<TaskStatus> get studentTransitions => studentTransitionsFrom(status);

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

  InternTask copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? completedAt,
    String? createdById,
    String? assignedToId,
    String? reviewReason,
    DateTime? reviewedAt,
  }) =>
      InternTask(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        dueDate: dueDate ?? this.dueDate,
        completedAt: completedAt ?? this.completedAt,
        createdById: createdById ?? this.createdById,
        assignedToId: assignedToId ?? this.assignedToId,
        reviewReason: reviewReason ?? this.reviewReason,
        reviewedAt: reviewedAt ?? this.reviewedAt,
      );

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        status,
        dueDate,
        completedAt,
        createdById,
        assignedToId,
        reviewReason,
        reviewedAt,
      ];
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
