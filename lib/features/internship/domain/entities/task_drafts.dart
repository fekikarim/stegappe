import 'package:equatable/equatable.dart';

/// T05 supervisor AI task draft (SU-TASK-02).
///
/// A draft is a server-side **proposal**, never a real task: it becomes one
/// only through an explicit bulk-add. Parsing is tolerant (unknown future
/// fields ignored, malformed rows skipped by the list parser); values the
/// app sends back are strongly typed.
class TaskDraft extends Equatable {
  const TaskDraft({
    required this.id,
    required this.referenceInternshipId,
    required this.title,
    this.description,
    this.dueDate,
    this.createdAt,
  });

  final String id;

  /// The internship anchoring the period used to validate due dates.
  final String referenceInternshipId;
  final String title;
  final String? description;

  /// yyyy-MM-dd inside the reference internship's period (server-validated).
  final DateTime? dueDate;
  final DateTime? createdAt;

  TaskDraft copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
  }) =>
      TaskDraft(
        id: id,
        referenceInternshipId: referenceInternshipId,
        title: title ?? this.title,
        description: description ?? this.description,
        dueDate: dueDate ?? this.dueDate,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, referenceInternshipId, title, description, dueDate, createdAt];
}

/// Per-pair result of a draft bulk-add, in request order (backend
/// `DraftBulkItemResult`). Every entry of a success response is `OK`; any
/// failure rolls back everything and arrives as a typed error instead.
class DraftBulkItem extends Equatable {
  const DraftBulkItem({
    required this.index,
    required this.draftId,
    required this.internshipId,
    this.taskId,
    required this.status,
  });

  final int index;
  final String draftId;
  final String internshipId;
  final String? taskId;
  final String status;

  bool get ok => status == 'OK';

  @override
  List<Object?> get props => [index, draftId, internshipId, taskId, status];
}

class DraftBulkResult extends Equatable {
  const DraftBulkResult({this.items = const []});

  final List<DraftBulkItem> items;

  int get okCount => items.where((i) => i.ok).length;

  @override
  List<Object?> get props => [items];
}
