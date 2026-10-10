import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_colors.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../data/cache/composer_draft_store.dart';
import '../../domain/entities/work_items.dart';
import '../providers/journal_calendar_providers.dart';
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
  late final ComposerDraftStore _draftStore;
  DateTime? _draftSavedAt;
  bool _loaded = false;
  bool _working = false;
  bool _persisted = false;
  String? _titleError;
  String? _descError;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    // Captured here: `ref` must not be touched in dispose (the element is
    // already unmounting by then).
    _draftStore = ref.read(composerDraftStoreProvider);
    _title.addListener(_onChanged);
    _description.addListener(_onChanged);
    _loadDraft();
  }

  @override
  void dispose() {
    // Flush keystrokes that arrived inside the 600 ms debounce window so a
    // quick back-navigation never silently drops the tail of the input.
    // Fire-and-forget: the store write is best-effort, and the next open
    // reloads whatever landed. Skipped once the content reached the server
    // (the store was cleared on success — re-saving would resurrect a
    // stale draft over the authoritative server copy).
    _debounce?.cancel();
    if (!_persisted &&
        (_title.text.isNotEmpty || _description.text.isNotEmpty)) {
      _draftStore.save(
            widget.internshipId,
            widget.day,
            ComposerDraft(
              title: _title.text,
              description: _description.text,
              updatedAt: DateTime.now(),
            ),
          );
    }
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
    } else if (_title.text.trim().length > kJournalTitleMaxLength) {
      // Mirrors the server column (`journal_entries.title VARCHAR(255)`):
      // UX-only, the backend remains authoritative.
      _titleError = l10n.journalTitleTooLong(kJournalTitleMaxLength);
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
      if (mounted) setState(() => _persisted = true);
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
        _serverError = (_titleError == null && _descError == null)
            ? userMessageOf(e, l10n)
            : null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _serverError = userMessageOf(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    // T15/BR-58: the composer persists server-side (draft or submit) — a
    // write outside the D12 queue, so offline it disables with a reason
    // instead of failing after the tap.
    final isOnline = ref.watch(isOnlineProvider);
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
      appBar: AppBar(
        title: Text(l10n.journalNew),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF042843), Color(0xFF0B61A0)],
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
            ),
          ),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: StegSpacing.screenPadding,
                    children: [
                      // ── Day hero: which day am I writing about? ──
                      _DayHero(
                        day: widget.day,
                        accent: ref.watch(journalAccentProvider),
                        savedAt: _draftSavedAt,
                      ),
                      const SizedBox(height: StegSpacing.md),
                      StegTextField(
                        controller: _title,
                        label: l10n.journalTitleLabel,
                        hint: l10n.journalTitlePlaceholder,
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
                            Row(
                              children: [
                                Expanded(
                                  child: RichText(
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
                                ),
                                // Live counter: the server caps the title, the
                                // day should never feel like a surprise.
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _description,
                                  builder: (context, value, _) => Text(
                                    '${value.text.trim().length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _description,
                              maxLines: 10,
                              minLines: 6,
                              textInputAction:
                                  TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: l10n.journalWritePlaceholder,
                                errorText: _descError,
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      if (!isOnline) ...[
                        const SizedBox(height: StegSpacing.sm),
                        Text(
                          l10n.submitNeedsConnection,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error),
                        ),
                      ],
                    ],
                  ),
                ),
                // ── Sticky actions: always reachable, never scrolled away ──
                _ActionBar(
                  working: _working,
                  online: isOnline,
                  savedAt: savedAt,
                  onSubmit: () => _persist(submit: true),
                  onSaveDraft: () => _persist(submit: false),
                ),
              ],
            ),
    );
  }
}

/// Hero header of the composer: the day being written about, in the period
/// colour, plus the local-draft receipt so the student always knows their
/// words are safe.
class _DayHero extends StatelessWidget {
  const _DayHero({required this.day, required this.accent, this.savedAt});

  final DateTime day;
  final JournalAccent accent;
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = JournalPalette.of(
        accent, Theme.of(context).brightness);

    String full, weekday;
    try {
      full = DateFormat.yMMMMEEEEd(locale.languageCode).format(day);
      weekday = DateFormat.EEEE(locale.languageCode).format(day);
    } on Exception {
      full = DateFormat.yMMMMEEEEd().format(day);
      weekday = DateFormat.EEEE().format(day);
    }

    return Semantics(
      header: true,
      label: full,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(StegSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? [
                    palette.seed.withValues(alpha: 0.35),
                    const Color(0xFF10293F)
                  ]
                : [palette.seed, palette.tint],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
          borderRadius: BorderRadius.circular(StegSpacing.radiusLg),
          boxShadow: [
            BoxShadow(
              color: palette.seed.withValues(alpha: dark ? 0.25 : 0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45), width: 1.5),
              ),
              child: Text(
                '${day.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: StegSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    weekday,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    full,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom action bar: submit + save draft, with the draft receipt.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.working,
    required this.online,
    required this.savedAt,
    required this.onSubmit,
    required this.onSaveDraft,
  });

  final bool working;
  final bool online;
  final String savedAt;
  final VoidCallback onSubmit;
  final VoidCallback onSaveDraft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? StegColors.darkBorder
                  : StegColors.lightBorder,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(StegSpacing.md, StegSpacing.sm,
            StegSpacing.md, StegSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (savedAt.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 14, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      savedAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StegSpacing.xs),
            ],
            Row(
              children: [
                Expanded(
                  child: StegButton(
                    label: l10n.journalSaveDraft,
                    variant: StegButtonVariant.secondary,
                    icon: Icons.save_outlined,
                    onPressed: (working || !online) ? null : onSaveDraft,
                  ),
                ),
                const SizedBox(width: StegSpacing.sm),
                Expanded(
                  child: StegButton(
                    label: l10n.journalSubmitAction,
                    icon: Icons.send_rounded,
                    loading: working,
                    onPressed: (working || !online) ? null : onSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
