import 'entities/work_items.dart';

/// Board section vocabulary (ST-TASK-01, D6).
///
/// `attention` is the group the app used to hide entirely: a completion the
/// supervisor has not reviewed yet ([TaskStatus.awaitingApproval]) and a
/// denial with its reason ([TaskStatus.denied]). Keeping them together is what
/// makes "waiting for review" and "needs action" impossible to miss.
enum TaskGroup { todo, inProgress, attention, done, cancelled, unknown }

TaskGroup taskGroupOf(TaskStatus status) => switch (status) {
      TaskStatus.todo => TaskGroup.todo,
      TaskStatus.inProgress => TaskGroup.inProgress,
      TaskStatus.awaitingApproval || TaskStatus.denied => TaskGroup.attention,
      TaskStatus.approved => TaskGroup.done,
      TaskStatus.cancelled => TaskGroup.cancelled,
      TaskStatus.unknown => TaskGroup.unknown,
    };

/// Sections always present on the board, even when empty: an empty group must
/// still explain itself instead of disappearing (T02 §Edge cases).
const List<TaskGroup> kBoardPrimaryGroups = [
  TaskGroup.todo,
  TaskGroup.inProgress,
  TaskGroup.attention,
  TaskGroup.done,
];

/// Client-side search over the loaded page (the list is bounded server-side).
/// Case-insensitive `contains` on title and description; a blank query matches
/// everything. Deliberately simple and predictable on a phone keyboard.
bool taskMatchesQuery(InternTask task, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (task.title.toLowerCase().contains(q)) return true;
  final description = task.description;
  return description != null && description.toLowerCase().contains(q);
}

/// One board section: its group and the matching tasks (newest first — the
/// server's `createdAt DESC` page order is preserved, never re-sorted here).
class TaskBoardSection {
  const TaskBoardSection({required this.group, required this.tasks});

  final TaskGroup group;
  final List<InternTask> tasks;

  int get count => tasks.length;
  bool get isEmpty => tasks.isEmpty;
}

/// Groups a server page into the board, applying the search query.
///
/// `cancelled` is hidden by default (T02 §Edge cases) and only rendered when
/// the caller asks for it (an explicit filter) or when nothing else matched.
/// `unknown` (a value from a newer backend) is never dropped silently: it gets
/// its own group as soon as one exists, so a task can never appear "To do" by
/// accident.
List<TaskBoardSection> buildTaskBoard(
  List<InternTask> tasks, {
  String query = '',
  bool includeCancelled = false,
}) {
  final matching = [
    for (final task in tasks)
      if (taskMatchesQuery(task, query)) task,
  ];
  final sections = <TaskBoardSection>[];
  for (final group in kBoardPrimaryGroups) {
    sections.add(TaskBoardSection(
      group: group,
      tasks: [for (final t in matching) if (taskGroupOf(t.status) == group) t],
    ));
  }
  final unknown = [
    for (final t in matching) if (t.status == TaskStatus.unknown) t,
  ];
  if (unknown.isNotEmpty) {
    sections.add(TaskBoardSection(group: TaskGroup.unknown, tasks: unknown));
  }
  final cancelled = [
    for (final t in matching) if (t.status == TaskStatus.cancelled) t,
  ];
  // A cancelled task is only shown on explicit request — or when it is all
  // there is, because silently hiding every task would look like data loss.
  final hasOtherSections = sections.any((s) => s.tasks.isNotEmpty);
  if (includeCancelled || (cancelled.isNotEmpty && !hasOtherSections)) {
    sections.add(TaskBoardSection(group: TaskGroup.cancelled, tasks: cancelled));
  }
  return sections;
}
