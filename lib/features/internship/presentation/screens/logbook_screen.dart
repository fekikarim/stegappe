import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/logbook.dart';
import '../providers/workspace_providers.dart';

/// Advisory logbook draft screen.
///
/// Safety properties (acceptance-critical):
/// - clearly labeled AI, advisory only, human review required;
/// - draft is REVIEW-ONLY: editable locally, never auto-submitted or
///   turned into an official record by the app;
/// - the client sends only the internship id; CIN/restricted documents
///   structurally cannot reach the model from here (server assembles
///   inputs through its restricted-excluding query + asserts
///   `cinExcluded`; the flag is displayed as evidence);
/// - AI outage/rate-limit/timeout degrades to a retry card and NEVER
///   blocks core internship operations.
class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  final _editor = TextEditingController();
  String? _seededFor;

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(logbookDraftProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.logbookTitle)),
      body: async.when(
        loading: () => const StegLoading(),
        error: (e, _) => Center(
          child: Padding(
            padding: StegSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  label: l10n.aiBadge,
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_outlined),
                      const SizedBox(width: StegSpacing.xs),
                      Text(l10n.aiBadge,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium),
                    ],
                  ),
                ),
                const SizedBox(height: StegSpacing.sm),
                Text(l10n.logbookUnavailable,
                    textAlign: TextAlign.center),
                if (e is ApiException && e.traceId != null) ...[
                  const SizedBox(height: StegSpacing.xs),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText('trace: ${e.traceId}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall),
                  ),
                ],
                const SizedBox(height: StegSpacing.md),
                StegButton(
                  label: l10n.logbookRegenerate,
                  icon: Icons.refresh_outlined,
                  onPressed: () =>
                      ref.invalidate(logbookDraftProvider),
                ),
              ],
            ),
          ),
        ),
        data: (draft) {
          if (_seededFor != draft.analysisId) {
            _editor.text = draft.draftText;
            _seededFor = draft.analysisId;
            // Persist the review copy across rebuilds only.
            Future.microtask(() => ref
                .read(logbookEditProvider.notifier)
                .state = draft.draftText);
          }
          return _DraftReview(draft: draft, editor: _editor);
        },
      ),
    );
  }
}

class _DraftReview extends ConsumerWidget {
  const _DraftReview({required this.draft, required this.editor});

  final LogbookDraft draft;
  final TextEditingController editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: StegSpacing.screenPadding,
      children: [
        Semantics(
          label: l10n.aiAdvisoryNote,
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined),
                  const SizedBox(width: StegSpacing.xs),
                  Expanded(
                    child: Text(l10n.aiBadge,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: StegSpacing.xs),
              Wrap(
                spacing: StegSpacing.xs,
                runSpacing: StegSpacing.xs,
                children: [
                  const StegStatusChip(
                      label: 'AI',
                      kind: StegStatusKind.info),
                  if (draft.cinExcluded)
                    StegStatusChip(
                        label: l10n.aiCinExcluded,
                        kind: StegStatusKind.success),
                ],
              ),
              const SizedBox(height: StegSpacing.xs),
              Text(l10n.logbookExplain,
                  style:
                      Theme.of(context).textTheme.bodyMedium),
              Text(l10n.aiAdvisoryNote,
                  style: Theme.of(context).textTheme.bodySmall),
              if (draft.modelUsed.isNotEmpty)
                Text(l10n.logbookModel(draft.modelUsed),
                    style:
                        Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: StegSpacing.md),
        Semantics(
          textField: true,
          label: l10n.logbookTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.logbookEditHint,
                  style:
                      Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: StegSpacing.xs),
              TextField(
                controller: editor,
                maxLines: null,
                minLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                onChanged: (v) => ref
                    .read(logbookEditProvider.notifier)
                    .state = v,
              ),
            ],
          ),
        ),
        if (draft.recommendations.isNotEmpty) ...[
          const SizedBox(height: StegSpacing.md),
          Text(l10n.logbookSuggestions,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StegSpacing.xs),
          for (final r in draft.recommendations)
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.lightbulb_outline),
                title: Text(r),
              ),
            ),
        ],
        const SizedBox(height: StegSpacing.md),
        StegButton(
          label: l10n.logbookRegenerate,
          variant: StegButtonVariant.secondary,
          icon: Icons.refresh_outlined,
          onPressed: () {
            ref.invalidate(logbookEditProvider);
            ref.invalidate(logbookDraftProvider);
          },
        ),
      ],
    );
  }
}
