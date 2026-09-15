import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paged.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/status_labels.dart';
import 'evaluation_detail_screen.dart';

/// Supervisor evaluation form. Every field is generated from the
/// backend-selected template + criteria + actual tasks — no hard-coded
/// official criteria anywhere.
///
/// Flow: template → per-criterion scores (0..maxScore) → type/date →
/// task reviews linked to real tasks → feedback/advice → indicative
/// estimate → explicit confirmation → sequential submit → the SERVER
/// response (authoritative total) is displayed afterwards.
class EvaluationFormScreen extends ConsumerStatefulWidget {
  const EvaluationFormScreen({super.key, required this.internshipId});

  final String internshipId;

  @override
  ConsumerState<EvaluationFormScreen> createState() =>
      _EvaluationFormScreenState();
}

class _TaskReviewDraft {
  bool included = false;
  bool completed = true;
  final TextEditingController score = TextEditingController();
  final TextEditingController comment = TextEditingController();

  void dispose() {
    score.dispose();
    comment.dispose();
  }
}

class _EvaluationFormScreenState
    extends ConsumerState<EvaluationFormScreen> {
  String? _templateId;
  EvaluationKind _kind = EvaluationKind.weekly;
  DateTime _date = DateTime.now();
  final _feedback = TextEditingController();
  final Map<String, TextEditingController> _scores = {};
  final Map<String, TextEditingController> _scoreComments = {};
  final Map<String, _TaskReviewDraft> _reviews = {};
  bool _submitting = false;
  String? _formError;

  @override
  void dispose() {
    _feedback.dispose();
    for (final c in _scores.values) {
      c.dispose();
    }
    for (final c in _scoreComments.values) {
      c.dispose();
    }
    for (final r in _reviews.values) {
      r.dispose();
    }
    super.dispose();
  }

  double? _parseScore(String raw, double max) {
    final v =
        double.tryParse(raw.trim().replaceAll(',', '.'));
    if (v == null || v < 0 || v > max) return null;
    return v;
  }

  /// Live estimate from currently valid inputs (UX only).
  double? _estimate(List<EvaluationCriterion> criteria) {
    final valid = <String, double>{};
    for (final c in criteria) {
      final raw = _scores[c.id]?.text ?? '';
      if (raw.trim().isEmpty) continue;
      final v = _parseScore(raw, c.maxScore);
      if (v == null) return null; // invalid input: no estimate
      valid[c.id] = v;
    }
    if (valid.isEmpty) return null;
    return estimateTotal(valid, criteria);
  }

  bool _validate(
      List<EvaluationCriterion> criteria, AppLocalizations l10n) {
    var ok = true;
    var anyScore = false;
    for (final c in criteria) {
      final raw = _scores[c.id]?.text ?? '';
      if (raw.trim().isEmpty) continue;
      anyScore = true;
      if (_parseScore(raw, c.maxScore) == null) ok = false;
    }
    if (!anyScore) ok = false;
    for (final entry in _reviews.entries) {
      if (!entry.value.included) continue;
      final raw = entry.value.score.text.trim();
      if (raw.isEmpty) continue;
      final v = double.tryParse(raw.replaceAll(',', '.'));
      if (v == null || v < 0) ok = false;
    }
    return ok;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit(List<EvaluationCriterion> criteria) async {
    final l10n = AppLocalizations.of(context);
    if (!_validate(criteria, l10n)) {
      setState(() => _formError = l10n.evalNoScores);
      return;
    }
    final confirmed = await showStegConfirmDialog(
      context,
      title: l10n.evalConfirmTitle,
      message: l10n.evalConfirmMessage,
      confirmLabel: l10n.evalSubmit,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      final repo = ref.read(internshipRepositoryProvider);
      final created = await repo.createEvaluation(widget.internshipId,
          templateId: _templateId,
          kind: _kind,
          date: _date,
          feedback: _feedback.text.trim().isEmpty
              ? null
              : _feedback.text.trim());
      final scorePayloads = <Map<String, dynamic>>[];
      for (final c in criteria) {
        final raw = _scores[c.id]?.text ?? '';
        if (raw.trim().isEmpty) continue;
        scorePayloads.add({
          'criterionId': c.id,
          'score': _parseScore(raw, c.maxScore),
          if ((_scoreComments[c.id]?.text ?? '').trim().isNotEmpty)
            'comment': _scoreComments[c.id]!.text.trim(),
        });
      }
      if (scorePayloads.isNotEmpty) {
        await repo.submitScores(created.id, scorePayloads);
      }
      for (final entry in _reviews.entries) {
        final draft = entry.value;
        if (!draft.included) continue;
        final raw = draft.score.text.trim();
        await repo.addTaskReview(created.id, {
          'taskId': entry.key,
          'completed': draft.completed,
          if (raw.isNotEmpty)
            'score': double.parse(raw.replaceAll(',', '.')),
          if (draft.comment.text.trim().isNotEmpty)
            'comment': draft.comment.text.trim(),
        });
      }
      refreshSupervisor(ref, widget.internshipId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EvaluationDetailScreen(
              evaluationId: created.id, created: true),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError =
            e is ApiException ? e.message : e.toString();
      });
    }
  }

  void _syncControllers(List<EvaluationCriterion> criteria) {
    for (final c in criteria) {
      _scores.putIfAbsent(c.id, () => TextEditingController());
      _scoreComments.putIfAbsent(c.id, () => TextEditingController());
    }
  }

  void _syncReviews(Paged<InternTask>? tasks) {
    final ids = <String>{if (tasks != null) for (final t in tasks.items) t.id};
    for (final stale in _reviews.keys
        .where((k) => !ids.contains(k))
        .toList()) {
      _reviews.remove(stale)?.dispose();
    }
    for (final id in ids) {
      _reviews.putIfAbsent(id, () => _TaskReviewDraft());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final templatesAsync = ref.watch(evaluationTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.evalNew)),
      body: templatesAsync.when(
        loading: () => const StegLoading(),
        error: (e, _) => StegErrorView(
          message: e is ApiException ? e.message : e.toString(),
          onRetry: () =>
              ref.invalidate(evaluationTemplatesProvider),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return StegEmptyView(
              title: l10n.evalNoTemplate,
              icon: Icons.star_outline,
            );
          }
          _templateId ??= templates.first.id;
          final criteriaAsync =
              ref.watch(templateCriteriaProvider(_templateId!));
          final tasksAsync = ref.watch(
              internshipTasksProvider(widget.internshipId));
          return criteriaAsync.when(
            loading: () => const StegLoading(),
            error: (e, _) => StegErrorView(
              message:
                  e is ApiException ? e.message : e.toString(),
              onRetry: () => ref.invalidate(
                  templateCriteriaProvider(_templateId!)),
            ),
            data: (criteria) {
              _syncControllers(criteria);
              _syncReviews(tasksAsync.valueOrNull);
              final estimate = _estimate(criteria);
              return ListView(
                padding: StegSpacing.screenPadding,
                children: [
                  Text(l10n.evalTemplate,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge),
                  const SizedBox(height: StegSpacing.xs),
                  DropdownButtonFormField<String>(
                    initialValue: _templateId,
                    items: [
                      for (final t in templates)
                        DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name,
                                overflow:
                                    TextOverflow.ellipsis)),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() {
                              _templateId = v;
                            }),
                  ),
                  Text(l10n.evalTemplateHint,
                      style:
                          Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: StegSpacing.md),

                  // --- Criteria (backend-generated) ---
                  for (final c in criteria) ...[
                    _CriterionInput(
                      criterion: c,
                      scoreController: _scores[c.id]!,
                      commentController:
                          _scoreComments[c.id]!,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: StegSpacing.sm),
                  ],

                  // --- Type + date ---
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<
                            EvaluationKind>(
                          initialValue: _kind,
                          decoration: InputDecoration(
                              labelText: l10n.evalType),
                          items: EvaluationKind.values
                              .map((k) =>
                                  DropdownMenuItem(
                                      value: k,
                                      child: Text(
                                          evaluationKindLabel(
                                              k, l10n))))
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (v) => setState(
                                  () => _kind = v ?? _kind),
                        ),
                      ),
                      const SizedBox(width: StegSpacing.sm),
                      Expanded(
                        child: InkWell(
                          onTap:
                              _submitting ? null : _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                                labelText: l10n.evalDate),
                            child: Text(
                                formatDay(_date, locale)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: StegSpacing.md),

                  // --- Task reviews (real tasks only) ---
                  Text(l10n.evalTaskReviews,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium),
                  Text(l10n.evalTaskReviewsHint,
                      style:
                          Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: StegSpacing.xs),
                  tasksAsync.when(
                    loading: () => const Center(
                        child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2),
                    )),
                    error: (e, _) => Text(
                        e is ApiException
                            ? e.message
                            : e.toString(),
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error)),
                    data: (page) => Column(
                      children: [
                        for (final t in page.items)
                          _TaskReviewTile(
                            task: t,
                            draft: _reviews[t.id]!,
                            onChanged: () =>
                                setState(() {}),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: StegSpacing.md),

                  // --- Feedback / advice (not journal text) ---
                  StegTextField(
                    controller: _feedback,
                    label: l10n.evalFeedback,
                    hint: l10n.evalFeedbackHint,
                  ),
                  const SizedBox(height: StegSpacing.md),

                  // --- Indicative estimate (UX only) ---
                  if (estimate != null)
                    Semantics(
                      label: l10n.evalEstimate(
                          estimate.toStringAsFixed(2)),
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.evalEstimate(estimate
                                .toStringAsFixed(2)),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                          Text(l10n.evalEstimateNote,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                        ],
                      ),
                    ),
                  if (_formError != null) ...[
                    const SizedBox(height: StegSpacing.sm),
                    Semantics(
                      liveRegion: true,
                      label: _formError,
                      excludeSemantics: true,
                      child: Text(_formError!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error)),
                    ),
                  ],
                  const SizedBox(height: StegSpacing.md),
                  StegButton(
                    label: l10n.evalSubmit,
                    icon: Icons.send_outlined,
                    loading: _submitting,
                    onPressed: _submitting
                        ? null
                        : () => _submit(criteria),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CriterionInput extends StatelessWidget {
  const _CriterionInput({
    required this.criterion,
    required this.scoreController,
    required this.commentController,
    required this.onChanged,
  });

  final EvaluationCriterion criterion;
  final TextEditingController scoreController;
  final TextEditingController commentController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              label: criterion.name,
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(criterion.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium),
                  if (criterion.description?.isNotEmpty ==
                      true)
                    Text(criterion.description!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall),
                  Text(
                    '${l10n.evalScoreOf(criterion.maxScore.toStringAsFixed(0))} • ${criterion.weight.toStringAsFixed(0)} %',
                    style:
                        Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: StegSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: scoreController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.evalScoreOf(criterion
                          .maxScore
                          .toStringAsFixed(0)),
                      helperText: l10n.evalScoreInvalid(
                          criterion.maxScore
                              .toStringAsFixed(0)),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: StegSpacing.xs),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                  labelText: l10n.evalCriterionComment),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskReviewTile extends StatelessWidget {
  const _TaskReviewTile({
    required this.task,
    required this.draft,
    required this.onChanged,
  });

  final InternTask task;
  final _TaskReviewDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StegSpacing.sm),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: draft.included,
                  onChanged: (v) {
                    draft.included = v ?? false;
                    onChanged();
                  },
                ),
                Expanded(
                  child: Text(task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            if (draft.included) ...[
              Row(
                children: [
                  Expanded(
                      child:
                          Text(l10n.evalIncludeTask)),
                  Switch(
                    value: draft.completed,
                    onChanged: (v) {
                      draft.completed = v;
                      onChanged();
                    },
                  ),
                  Text(draft.completed
                      ? l10n.evalTaskDone
                      : l10n.evalTaskNotDone),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: draft.score,
                      keyboardType: const TextInputType
                          .numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: l10n.evalOptionalScore),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: StegSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: draft.comment,
                      decoration: InputDecoration(
                          labelText:
                              l10n.evalCriterionComment),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
