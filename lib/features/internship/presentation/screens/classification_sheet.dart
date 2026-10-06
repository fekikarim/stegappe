import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../domain/entities/task_classification.dart';
import '../providers/classification_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/category_chip.dart';

/// Management surface for the student's own classification categories
/// (T03/ST-TASK-03): create, rename, recolor, reorder (explicit up/down
/// buttons for switch/keyboard users — no drag-only interaction), delete
/// with a confirm that explains the tasks become unclassified.
class ClassificationSheet extends ConsumerStatefulWidget {
  const ClassificationSheet({super.key});

  static Future<void> show(BuildContext context) => showStegSheet<void>(
        context,
        title: AppLocalizations.of(context).catTitle,
        builder: (_) => const ClassificationSheet(),
      );

  @override
  ConsumerState<ClassificationSheet> createState() =>
      _ClassificationSheetState();
}

class _ClassificationSheetState
    extends ConsumerState<ClassificationSheet> {
  final TextEditingController _name = TextEditingController();
  String? _color;
  String? _busyId;
  String? _editingId;
  final TextEditingController _rename = TextEditingController();
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _rename.dispose();
    super.dispose();
  }

  Future<void> _run(String id, Future<void> Function() call) async {
    if (_busyId != null) return;
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await call();
      ref.invalidate(classificationBoardProvider);
    } on Exception catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _create(String internshipId) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await _run('create', () async {
      await ref
          .read(internshipRepositoryProvider)
          .createCategory(internshipId, name: name, color: _color);
    });
    if (_error == null && mounted) {
      _name.clear();
      setState(() => _color = null);
    }
  }

  Future<void> _saveRename(TaskCategory category) async {
    final name = _rename.text.trim();
    if (name.isEmpty || name == category.name) {
      setState(() => _editingId = null);
      return;
    }
    await _run('rename-${category.id}', () async {
      await ref
          .read(internshipRepositoryProvider)
          .renameCategory(category.id, name: name);
    });
    if (mounted && _error == null) setState(() => _editingId = null);
  }

  Future<void> _delete(TaskCategory category) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showStegConfirmDialog(
      context,
      title: l10n.catDeleteTitle,
      message: '${l10n.catDeleteConfirm(category.name)}\n\n${l10n.catDeleteHint}',
      confirmLabel: l10n.catDelete,
      destructive: true,
    );
    if (!confirmed) return;
    await _run('delete-${category.id}', () async {
      await ref
          .read(internshipRepositoryProvider)
          .deleteCategory(category.id);
    });
  }

  Future<void> _move(List<TaskCategory> categories, int index, int delta) async {
    final next = index + delta;
    if (next < 0 || next >= categories.length) return;
    final ordered = List<TaskCategory>.of(categories);
    final moved = ordered.removeAt(index);
    ordered.insert(next, moved);
    await _run('reorder', () async {
      await ref
          .read(internshipRepositoryProvider)
          .reorderCategories([for (final c in ordered) c.id]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final internshipId = ref.watch(myInternshipIdProvider).valueOrNull;
    final board = ref.watch(classificationBoardProvider);

    return board.when(
      loading: () => const StegLoading(),
      error: (e, _) => StegErrorView(
        message: context.userError(e).message,
        onRetry: () => ref.invalidate(classificationBoardProvider),
      ),
      data: (data) {
        if (internshipId == null) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: StegSpacing.xs),
                child: Text(
                  context.userError(_error!).message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (data.categories.isEmpty)
              StegEmptyView(
                title: l10n.catEmpty,
                hint: l10n.catEmptyHint,
                icon: Icons.folder_outlined,
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: data.categories.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final category = data.categories[index];
                    final busy = _busyId == 'rename-${category.id}' ||
                        _busyId == 'delete-${category.id}';
                    final editing = _editingId == category.id;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: categoryColor(
                              category.colorToken, Theme.of(context)),
                        ),
                      ),
                      title: editing
                          ? StegTextField(
                              controller: _rename,
                              label: l10n.catNameLabel,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _saveRename(category),
                            )
                          : Text(category.name),
                      subtitle: editing
                          ? null
                          : Text(
                              '${l10n.catColorLabel}: ${category.colorToken ?? l10n.catNoColor}'),
                      trailing: editing
                          ? IconButton(
                              tooltip: l10n.catSave,
                              icon: busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.check),
                              onPressed: busy
                                  ? null
                                  : () => _saveRename(category),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: l10n.catMoveUp,
                                  icon: const Icon(Icons.arrow_upward),
                                  onPressed: _busyId != null || index == 0
                                      ? null
                                      : () => _move(
                                          data.categories, index, -1),
                                ),
                                IconButton(
                                  tooltip: l10n.catMoveDown,
                                  icon: const Icon(Icons.arrow_downward),
                                  onPressed: _busyId != null ||
                                          index == data.categories.length - 1
                                      ? null
                                      : () => _move(
                                          data.categories, index, 1),
                                ),
                                IconButton(
                                  tooltip: l10n.catRename,
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: _busyId != null
                                      ? null
                                      : () {
                                          _rename.text = category.name;
                                          setState(() =>
                                              _editingId = category.id);
                                        },
                                ),
                                IconButton(
                                  tooltip: l10n.catDelete,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: _busyId != null
                                      ? null
                                      : () => _delete(category),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            const SizedBox(height: StegSpacing.sm),
            StegTextField(
              controller: _name,
              label: l10n.catNameLabel,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(internshipId),
            ),
            const SizedBox(height: StegSpacing.xs),
            _ColorPicker(
              selected: _color,
              onSelect: (token) => setState(() => _color = token),
            ),
            const SizedBox(height: StegSpacing.sm),
            StegButton(
              label: l10n.catCreate,
              icon: Icons.add,
              loading: _busyId == 'create',
              onPressed: _busyId != null || _name.text.trim().isEmpty
                  ? null
                  : () => _create(internshipId),
            ),
          ],
        );
      },
    );
  }
}

/// Color picker over the closed backend token vocabulary.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.catColorLabel, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        Wrap(
          spacing: StegSpacing.xs,
          runSpacing: StegSpacing.xs,
          children: [
            ChoiceChip(
              label: Text(l10n.catNoColor),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
            for (final token in kCategoryColorTokens)
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: categoryColor(token, theme),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(token),
                  ],
                ),
                selected: selected == token,
                onSelected: (_) =>
                    onSelect(selected == token ? null : token),
              ),
          ],
        ),
      ],
    );
  }
}

/// Per-task category picker used by the task detail sheet (T03).
///
/// Shows the student's categories plus "unclassified"; assigning uses the
/// board's known value as the compare-and-set expectation so a task
/// classified meanwhile is refused (409) instead of overwritten. The
/// conflict surfaces the localized reload sentence; an explicit "force"
/// retry is offered only after that refusal.
Future<void> showCategoryPicker(
  BuildContext context,
  WidgetRef ref, {
  required String taskId,
  required String? currentCategoryId,
  required List<TaskCategory> categories,
}) async {
  final l10n = AppLocalizations.of(context);
  final picked = await showDialog<String?>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.catTitle),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.of(ctx).pop(''),
          child: Row(
            children: [
              const Icon(Icons.folder_open_outlined),
              const SizedBox(width: StegSpacing.xs),
              Text(l10n.catUnclassified),
              if (currentCategoryId == null) ...[
                const SizedBox(width: StegSpacing.xs),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        ),
        for (final category in categories)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(category.id),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: categoryColor(
                        category.colorToken, Theme.of(ctx)),
                  ),
                ),
                const SizedBox(width: StegSpacing.xs),
                Expanded(child: Text(category.name)),
                if (currentCategoryId == category.id)
                  const Icon(Icons.check, size: 18),
              ],
            ),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  final target = picked.isEmpty ? null : picked;
  if (target == currentCategoryId) return;
  try {
    await ref.read(internshipRepositoryProvider).assignTaskCategory(
          taskId,
          categoryId: target,
          expectedCategoryId: currentCategoryId,
        );
    ref.invalidate(classificationBoardProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.catAssigned)),
      );
    }
  } on Exception catch (e) {
    if (!context.mounted) return;
    final repo = ref.read(internshipRepositoryProvider);
    final conflict = e is ApiException && e.code == kCodeCategoryChanged;
    final retry = conflict &&
        await showStegConfirmDialog(
          context,
          title: l10n.catTitle,
          message: context.userError(e).message,
          confirmLabel: l10n.retry,
        );
    if (retry && context.mounted) {
      try {
        await repo.assignTaskCategory(taskId,
            categoryId: target, force: true);
        ref.invalidate(classificationBoardProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.catAssigned)),
          );
        }
      } on Exception catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.userError(e2).message)),
          );
        }
      }
    } else if (!retry && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.userError(e).message)),
      );
    }
  }
}
