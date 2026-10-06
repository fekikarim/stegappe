import 'package:equatable/equatable.dart';

/// T04 supervisor bulk result (SU-HOME-01, BR-16).
///
/// The backend executes a bulk request atomically: a success response means
/// every item applied (each entry echoes its request position via [index]);
/// any failure rolls back everything and arrives as a typed error instead —
/// never a silent partial.
class SupervisorBulkItem extends Equatable {
  const SupervisorBulkItem({
    required this.index,
    required this.action,
    this.taskId,
    this.internshipId,
    required this.status,
  });

  final int index;

  /// `CREATE`, `UPDATE` or `DELETE` (backend `BulkTaskAction`).
  final String action;
  final String? taskId;
  final String? internshipId;

  /// `OK` on every entry of a success response.
  final String status;

  bool get ok => status == 'OK';

  @override
  List<Object?> get props => [index, action, taskId, internshipId, status];
}

class SupervisorBulkResult extends Equatable {
  const SupervisorBulkResult({this.items = const [], this.deletedCount = 0});

  final List<SupervisorBulkItem> items;
  final int deletedCount;

  int get okCount => items.where((i) => i.ok).length;

  @override
  List<Object?> get props => [items, deletedCount];
}
