import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../domain/entities/task_classification.dart';
import '../providers/classification_providers.dart';
import '../providers/workspace_providers.dart';
import '../widgets/category_chip.dart';

/// Explicit AI classification flow (T03/ST-TASK-04): the student invokes the
/// suggestion, reviews every proposal (existing vs "new" is visually
/// distinct), accepts one or all, and can undo the accepted batch.
///
/// AI proposals are visually distinguishable from applied classifications
/// (dashed border + "AI" marker, never color alone). AI requires
/// connectivity: the action is disabled offline with an honest sentence.
class SuggestSheet extends ConsumerWidget {
  const SuggestSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showStegSheet<void>(
      context,
      title: AppLocalizations.of(context).catProposals,
      builder: (_) => const SuggestSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final flow = ref.watch(suggestionFlowProvider);
    final controller = ref.read(suggestionFlowProvider.notifier);
    final isOnline = ref.watch(isOnlineProvider);
    final board = ref.watch(classificationBoardProvider).valueOrNull ??
        ref.watch(lastClassificationProvider);
    final categories = board?.categories ?? const <TaskCategory>[];
    final busy = flow.loading || flow.accepting || flow.undoing;

    if (flow.error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StegErrorView(
            message: context.userError(flow.error!).message,
            onRetry: controller.load,
          ),
          const SizedBox(height: StegSpacing.sm),
          _SuggestButton(
              busy: busy, isOnline: isOnline, hasCategories: true),
        ],
      );
    }

    if (flow.loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StegLoading(),
          const SizedBox(height: StegSpacing.xs),
          Text(l10n.catSuggesting),
        ],
      );
    }

    if (!flow.hasProposals) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (flow.lastApply != null)
            _ApplySummary(flow: flow, categories: categories),
          StegEmptyView(
            title: flow.lastApply != null
                ? l10n.catUndone
                : (categories.isEmpty
                    ? l10n.catEmpty
                    : l10n.catSuggestEmpty),
            hint: categories.isEmpty ? l10n.catNoCategoriesHint : null,
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: StegSpacing.sm),
          _SuggestButton(
              busy: busy,
              isOnline: isOnline,
              hasCategories: categories.isNotEmpty),
          if (flow.lastBatchId != null) ...[
            const SizedBox(height: StegSpacing.xs),
            _UndoButton(flow: flow),
          ],
        ],
      );
    }

    final tasks = ref.watch(taskListProvider).valueOrNull?.items ??
        ref.watch(lastTasksProvider)?.items ??
        const [];
    String taskTitle(String taskId) {
      for (final t in tasks) {
        if (t.id == taskId) return t.title;
      }
      return taskId;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (flow.lastApply != null) _ApplySummary(flow: flow, categories: categories),
        Text(l10n.catProposalNote,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: StegSpacing.xs),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: flow.proposals.length,
            separatorBuilder: (_, _) => const SizedBox(height: StegSpacing.xs),
            itemBuilder: (context, index) {
              final proposal = flow.proposals[index];
              final accepted =
                  flow.acceptedTaskIds.contains(proposal.taskId);
              return _ProposalRow(
                proposal: proposal,
                taskTitle: taskTitle(proposal.taskId),
                categories: categories,
                accepted: accepted,
                busy: busy,
              );
            },
          ),
        ),
        const SizedBox(height: StegSpacing.sm),
        StegButton(
          label: l10n.catAcceptAll,
          icon: Icons.done_all_outlined,
          loading: flow.accepting,
          onPressed: busy || !isOnline
              ? null
              : () => controller.acceptAll(),
        ),
        if (!isOnline)
          Padding(
            padding: const EdgeInsets.only(top: StegSpacing.xs),
            child: Text(l10n.catNeedsConnection,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        if (flow.lastBatchId != null) ...[
          const SizedBox(height: StegSpacing.xs),
          _UndoButton(flow: flow),
        ],
      ],
    );
  }
}

class _SuggestButton extends ConsumerWidget {
  const _SuggestButton(
      {required this.busy, required this.isOnline, required this.hasCategories});

  final bool busy;
  final bool isOnline;
  final bool hasCategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(suggestionFlowProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StegButton(
          label: l10n.catSuggest,
          icon: Icons.auto_awesome_outlined,
          loading: busy,
          onPressed: busy || !isOnline || !hasCategories
              ? null
              : () => controller.load(),
        ),
        if (!isOnline)
          Padding(
            padding: const EdgeInsets.only(top: StegSpacing.xs),
            child: Text(l10n.catNeedsConnection,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        if (!hasCategories && isOnline)
          Padding(
            padding: const EdgeInsets.only(top: StegSpacing.xs),
            child: Text(l10n.catNoCategoriesHint,
                style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _UndoButton extends ConsumerWidget {
  const _UndoButton({required this.flow});

  final SuggestionFlowState flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return StegButton(
      label: l10n.catUndo,
      icon: Icons.undo_outlined,
      variant: StegButtonVariant.secondary,
      loading: flow.undoing,
      onPressed: flow.undoing || flow.accepting
          ? null
          : () => ref.read(suggestionFlowProvider.notifier).undo(),
    );
  }
}

/// Per-item apply result summary (applied vs skipped) with undo.
class _ApplySummary extends StatelessWidget {
  const _ApplySummary({required this.flow, required this.categories});

  final SuggestionFlowState flow;
  final List<TaskCategory> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final applied = flow.lastApply?.appliedCount ?? 0;
    final skipped = (flow.lastApply?.items.length ?? 0) - applied;
    final undoneCount =
        flow.lastUndo?.where((r) => r.status == 'REVERTED').length;
    return Padding(
      padding: const EdgeInsets.only(bottom: StegSpacing.xs),
      child: Text(
        [
          if (applied > 0) l10n.catApplied(applied),
          if (skipped > 0) l10n.catApplySkipped(skipped),
          if (undoneCount != null && undoneCount > 0) l10n.catUndone,
        ].join(' '),
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// One proposal row: task title, proposed category (existing chip vs "new"
/// badge with dashed border), per-item accept. Accepted rows show a check —
/// never color alone.
class _ProposalRow extends ConsumerWidget {
  const _ProposalRow({
    required this.proposal,
    required this.taskTitle,
    required this.categories,
    required this.accepted,
    required this.busy,
  });

  final CategoryProposal proposal;
  final String taskTitle;
  final List<TaskCategory> categories;
  final bool accepted;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final existing = proposal.isNewCategory
        ? null
        : _findCategory(categories, proposal.categoryId);
    return Semantics(
      label: '$taskTitle → ${proposal.displayName(categories)}',
      child: Container(
        padding: const EdgeInsets.all(StegSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StegSpacing.radiusSm),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 18),
            const SizedBox(width: StegSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(taskTitle,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (existing != null)
                    CategoryChip(category: existing)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: StegSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(StegSpacing.radiusSm),
                        border: Border.all(
                            style: BorderStyle.solid,
                            color: theme.colorScheme.tertiary),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              size: 14,
                              color: theme.colorScheme.tertiary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${proposal.newCategoryName} • ${l10n.catNewBadge}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: StegSpacing.xs),
            accepted
                ? const Icon(Icons.check_circle_outline,
                    color: Colors.green)
                : StegButton(
                    label: l10n.catAccept,
                    variant: StegButtonVariant.secondary,
                    loading: busy,
                    onPressed: busy
                        ? null
                        : () => ref
                            .read(suggestionFlowProvider.notifier)
                            .acceptOne(proposal),
                  ),
          ],
        ),
      ),
    );
  }

  TaskCategory? _findCategory(List<TaskCategory> categories, String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}
