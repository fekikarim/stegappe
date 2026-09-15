import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../data/cache/composer_draft_store.dart';
import '../providers/workspace_providers.dart';

/// Journal composer: records what the intern ACTUALLY did on [day].
/// Separate by design from planned tasks (different tab, explicit
/// microcopy, no auto-generation from tasks).
///
/// Draft safety: keystrokes autosave to a LOCAL draft (debounced);
/// the backend becomes authoritative only after server create
/// (entries are server-immutable — no update endpoint exists).
class JournalComposerScreen extends ConsumerStatefulWidget {
  const JournalComposerScreen({
    super.key,
    required this.internshipId,
    required this.day,
  });

  final String internshipId;
  final DateTime day;

  @override
  ConsumerState<JournalComposerScreen> createState() =>
      _JournalComposerScreenState();
}

class _JournalComposerScreenState
    extends ConsumerState<JournalComposerScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  Timer? _debounce;
  DateTime? _draftSavedAt;
  bool _loaded = false;
  bool _working = false;
  String? _titleError;
  String? _descError;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onChanged);
    _description.addListener(_onChanged);
    _loadDraft();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final draft = await ref
        .read(composerDraftStoreProvider)
        .load(widget.internshipId, widget.day);
    if (!mounted) return;
    setState(() {
      if (draft != null) {
        _title.text = draft.title;
        _description.text = draft.description;
        _draftSavedAt = draft.updatedAt;
      }
      _loaded = true;
    });
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(composerDraftStoreProvider).save(
            widget.internshipId,
            widget.day,
            ComposerDraft(
              title: _title.text,
              description: _description.text,
              updatedAt: DateTime.now(),
            ),
          );
      if (mounted &&
          (_title.text.isNotEmpty ||
              _description.text.isNotEmpty)) {
        setState(() => _draftSavedAt = DateTime.now());
      }
    });
  }

  bool get _valid {
    var ok = true;
    final l10n = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      _titleError = l10n.journalFieldRequired;
      ok = false;
    } else {
      _titleError = null;
    }
    if (_description.text.trim().isEmpty) {
      _descError = l10n.journalFieldRequired;
      ok = false;
    } else {
      _descError = null;
    }
    setState(() {});
    return ok;
  }

  /// Create the server DRAFT entry, then optionally submit it.
  /// Local draft clears only after a successful create (the server
  /// then holds the content — nothing is lost on a submit failure).
  Future<void> _persist({required bool submit}) async {
    if (!_valid || _working) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _working = true;
      _serverError = null;
    });
    final repo = ref.read(internshipRepositoryProvider);
    final store = ref.read(composerDraftStoreProvider);
    try {
      final entry = await repo.createJournal(widget.internshipId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          entryDate: widget.day);
      await store.clear(widget.internshipId, widget.day);
      if (submit) {
        try {
          await repo.submitJournal(entry.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.journalSubmittedOk)),
          );
        } on Exception {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.journalSubmitFailKept)),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.journalCreated)),
        );
      }
      ref
        ..invalidate(journalListProvider)
        ..invalidate(dashboardProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _titleError = e.fieldMessage('title');
        _descError = e.fieldMessage('description') ??
            e.fieldMessage('entryDate');
        _serverError =
            (_titleError == null && _descError == null) ? e.message : null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _serverError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    String dayTitle;
    try {
      dayTitle = DateFormat.yMMMMEEEEd(locale.languageCode)
          .format(widget.day);
    } on Exception {
      dayTitle = DateFormat.yMMMMEEEEd().format(widget.day);
    }
    String savedAt = '';
    if (_draftSavedAt != null) {
      try {
        savedAt = l10n.journalDraftSavedAt(
            DateFormat.Hm(locale.languageCode).format(_draftSavedAt!));
      } on Exception {
        savedAt =
            l10n.journalDraftSavedAt(DateFormat.Hm().format(_draftSavedAt!));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.journalNew)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: StegSpacing.screenPadding,
              children: [
                Semantics(
                  header: true,
                  label: dayTitle,
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Text(dayTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                      const SizedBox(height: StegSpacing.xs),
                      Text(l10n.journalWhatDid,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: StegSpacing.md),
                StegTextField(
                  controller: _title,
                  label: l10n.journalTitleLabel,
                  hint: l10n.journalTitleHint,
                  required: true,
                  error: _titleError,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: StegSpacing.md),
                Semantics(
                  textField: true,
                  label: l10n.journalDescLabel,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: l10n.journalDescLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge,
                          children: const [
                            TextSpan(
                                text: ' *',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _description,
                        maxLines: 8,
                        minLines: 5,
                        textInputAction:
                            TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: l10n.journalDescHint,
                          errorText: _descError,
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (savedAt.isNotEmpty) ...[
                  const SizedBox(height: StegSpacing.xs),
                  Text(savedAt,
                      style:
                          Theme.of(context).textTheme.bodySmall),
                ],
                if (_serverError != null) ...[
                  const SizedBox(height: StegSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    label: _serverError,
                    excludeSemantics: true,
                    child: Text(_serverError!,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error)),
                  ),
                ],
                const SizedBox(height: StegSpacing.lg),
                StegButton(
                  label: l10n.journalSubmitAction,
                  icon: Icons.send_outlined,
                  loading: _working,
                  onPressed:
                      _working ? null : () => _persist(submit: true),
                ),
                const SizedBox(height: StegSpacing.xs),
                StegButton(
                  label: l10n.journalSaveDraft,
                  variant: StegButtonVariant.secondary,
                  icon: Icons.save_outlined,
                  onPressed:
                      _working ? null : () => _persist(submit: false),
                ),
              ],
            ),
    );
  }
}
