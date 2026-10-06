import 'package:equatable/equatable.dart';

/// T03 student task classification (ST-TASK-03/04/05, D5/D5b).
///
/// Categories are **student-defined** records (id, name, optional colour
/// token, order) stored server-side per student. A task carries at most one
/// category id — and classification is independent of the workflow status:
/// assigning or clearing it never changes a task's status (BR-19).
///
/// Parsing is tolerant (unknown colour tokens survive as raw strings, unknown
/// future fields are ignored) while the values the app persists back are
/// strongly typed — never `dynamic` maps across the feature.
class TaskCategory extends Equatable {
  const TaskCategory({
    required this.id,
    required this.name,
    this.colorToken,
    this.position = 0,
  });

  final String id;
  final String name;

  /// Optional colour token from the closed backend vocabulary
  /// (`red`, `orange`, …). Unknown future tokens are kept verbatim and
  /// rendered with the default swatch — never a crash.
  final String? colorToken;
  final int position;

  TaskCategory copyWith({String? name, String? colorToken, int? position}) =>
      TaskCategory(
        id: id,
        name: name ?? this.name,
        colorToken: colorToken ?? this.colorToken,
        position: position ?? this.position,
      );

  @override
  List<Object?> get props => [id, name, colorToken, position];
}

/// One AI classification proposal (ST-TASK-04): advisory only, nothing is
/// persisted until the student accepts it.
class CategoryProposal extends Equatable {
  const CategoryProposal({
    required this.taskId,
    this.categoryId,
    this.newCategoryName,
    this.confidence = 0.5,
  });

  final String taskId;

  /// Existing category id, or null when proposing a new name.
  final String? categoryId;

  /// Proposed new category name (shown as "new", created only on accept).
  final String? newCategoryName;
  final double confidence;

  bool get isNewCategory => newCategoryName != null;

  /// Display name: the existing category's name, or the proposed new one.
  String displayName(List<TaskCategory> categories) {
    if (newCategoryName != null) return newCategoryName!;
    for (final c in categories) {
      if (c.id == categoryId) return c.name;
    }
    return categoryId ?? '';
  }

  @override
  List<Object?> get props => [taskId, categoryId, newCategoryName, confidence];
}

/// Result line of an accept batch: per-item, never all-or-nothing.
class ApplyCategoryResult extends Equatable {
  const ApplyCategoryResult({
    required this.taskId,
    required this.status,
    this.categoryId,
  });

  final String taskId;

  /// `APPLIED`, `SKIPPED_ALREADY_CLASSIFIED`, `SKIPPED_CHANGED`,
  /// `NOT_FOUND`, `INVALID_CATEGORY`. Unknown future values degrade to
  /// `UNKNOWN` — never a crash, never a silent success.
  final String status;
  final String? categoryId;

  bool get applied => status == 'APPLIED';

  @override
  List<Object?> get props => [taskId, status, categoryId];
}

/// The student's classification board: categories plus the task→category
/// assignment map for one internship.
class ClassificationBoard extends Equatable {
  const ClassificationBoard({
    this.categories = const [],
    this.assignments = const {},
  });

  final List<TaskCategory> categories;

  /// taskId → categoryId. Absent = unclassified.
  final Map<String, String> assignments;

  static const empty = ClassificationBoard();

  String? categoryOf(String taskId) => assignments[taskId];

  TaskCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Ids of [taskIds] carrying no classification — the only tasks eligible
  /// for an AI proposal (existing manual classifications are never touched).
  List<String> unclassifiedIds(Iterable<String> taskIds) =>
      [for (final id in taskIds) if (!assignments.containsKey(id)) id];

  /// Proposals pointing at tasks the student still owns in this board.
  /// Foreign/unknown task ids are ignored (never trusted blindly).
  List<CategoryProposal> validProposals(
      List<CategoryProposal> proposals, Set<String> ownTaskIds) =>
      [
        for (final p in proposals)
          if (ownTaskIds.contains(p.taskId)) p,
      ];

  @override
  List<Object?> get props => [categories, assignments];
}

/// AI suggestion answer: proposals only, nothing persisted.
class ClassificationSuggestion extends Equatable {
  const ClassificationSuggestion({
    this.proposals = const [],
    this.unclassifiedCount = 0,
    this.capped = false,
  });

  final List<CategoryProposal> proposals;
  final int unclassifiedCount;
  final bool capped;

  @override
  List<Object?> get props => [proposals, unclassifiedCount, capped];
}

/// Accept-batch answer: per-item results plus the batch id used for undo
/// (null when nothing was applied).
class ApplyCategoriesResult extends Equatable {
  const ApplyCategoriesResult({this.batchId, this.items = const []});

  final String? batchId;
  final List<ApplyCategoryResult> items;

  int get appliedCount => items.where((i) => i.applied).length;

  @override
  List<Object?> get props => [batchId, items];
}

/// Closed colour-token vocabulary shared with the backend (`COLOR_TOKENS`).
/// The UI always pairs colour with an icon + label — never colour alone.
const Set<String> kCategoryColorTokens = {
  'red',
  'orange',
  'amber',
  'lime',
  'green',
  'teal',
  'cyan',
  'blue',
  'indigo',
  'violet',
  'pink',
  'slate',
};
