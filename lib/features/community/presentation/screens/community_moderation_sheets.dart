import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../domain/entities/community.dart';

/// Report sheet: reason (required, ≤500, moderators-only visibility).
/// Online-only with an explicit reason when offline (T08 edge: posting
/// disabled with a reason — reports likewise need connectivity).
Future<void> showCommunityReportSheet(
  BuildContext context, {
  required String targetLabel,
  required Future<void> Function(String reason) onSubmit,
}) {
  final l10n = AppLocalizations.of(context);
  return showStegSheet<void>(
    context,
    title: '${l10n.communityReport} • $targetLabel',
    builder: (_) => _ReasonSheet(
      hint: l10n.communityReportHint,
      actionLabel: l10n.communityReport,
      requireOnline: true,
      onSubmit: onSubmit,
      doneLabel: l10n.communityReportSent,
    ),
  );
}

/// Moderator remove sheet: reason mandatory (server-enforced).
Future<void> showCommunityRemoveSheet(
  BuildContext context, {
  required Future<void> Function(String reason) onSubmit,
}) {
  final l10n = AppLocalizations.of(context);
  return showStegSheet<void>(
    context,
    title: l10n.communityRemove,
    builder: (_) => _ReasonSheet(
      hint: l10n.communityRemoveReason,
      actionLabel: l10n.communityRemove,
      destructive: true,
      requireOnline: true,
      onSubmit: onSubmit,
    ),
  );
}

/// Moderator mute sheet: preset durations (5 min .. 30 days server bounds)
/// + mandatory reason (shown to the student; moderator stays anonymous).
Future<void> showCommunityMuteSheet(
  BuildContext context, {
  required String userLabel,
  required Future<void> Function(int minutes, String reason) onSubmit,
}) {
  final l10n = AppLocalizations.of(context);
  return showStegSheet<void>(
    context,
    title: '${l10n.communityMute} • $userLabel',
    builder: (_) => _MuteSheet(onSubmit: onSubmit),
  );
}

class _ReasonSheet extends ConsumerStatefulWidget {
  const _ReasonSheet({
    required this.hint,
    required this.actionLabel,
    required this.onSubmit,
    this.doneLabel,
    this.destructive = false,
    this.requireOnline = false,
  });

  final String hint;
  final String actionLabel;
  final Future<void> Function(String reason) onSubmit;
  final String? doneLabel;
  final bool destructive;
  final bool requireOnline;

  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  final _reason = TextEditingController();
  String? _error;
  String? _serverError;
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_reason.text.trim().isEmpty || _sending) {
      if (_reason.text.trim().isEmpty) {
        setState(() => _error = l10n.journalFieldRequired);
      }
      return;
    }
    if (_reason.text.trim().length >
        CommunityContentRules.maxReasonLength) {
      setState(() => _error = l10n.errBadRequest);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _serverError = null;
    });
    try {
      await widget.onSubmit(_reason.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.doneLabel != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.doneLabel!)));
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _serverError = userMessageOf(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final disabled =
        _sending || (widget.requireOnline && !isOnline);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.hint,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: StegSpacing.sm),
        StegTextField(
          controller: _reason,
          label: l10n.communityReportHint,
          required: true,
          error: _error,
        ),
        if (widget.requireOnline && !isOnline) ...[
          const SizedBox(height: StegSpacing.xs),
          Text(l10n.communityNeedsConnection,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error)),
        ],
        if (_serverError != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Semantics(
            liveRegion: true,
            label: _serverError,
            excludeSemantics: true,
            child: Text(_serverError!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
        const SizedBox(height: StegSpacing.md),
        StegButton(
          label: widget.actionLabel,
          variant: widget.destructive
              ? StegButtonVariant.destructive
              : StegButtonVariant.primary,
          loading: _sending,
          onPressed: disabled ? null : _send,
        ),
      ],
    );
  }
}

class _MuteSheet extends ConsumerStatefulWidget {
  const _MuteSheet({required this.onSubmit});

  final Future<void> Function(int minutes, String reason) onSubmit;

  @override
  ConsumerState<_MuteSheet> createState() => _MuteSheetState();
}

class _MuteSheetState extends ConsumerState<_MuteSheet> {
  final _reason = TextEditingController();
  int _minutes = 60;
  String? _error;
  String? _serverError;
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_reason.text.trim().isEmpty || _sending) {
      if (_reason.text.trim().isEmpty) {
        setState(() => _error = l10n.journalFieldRequired);
      }
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _serverError = null;
    });
    try {
      await widget.onSubmit(_minutes, _reason.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _serverError = userMessageOf(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    final durations = <int, String>{
      60: l10n.communityMuteHour,
      1440: l10n.communityMuteDay,
      10080: l10n.communityMuteWeek,
      43200: l10n.communityMuteMonth,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.communityMuteDuration,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: StegSpacing.xs),
        Wrap(
          spacing: StegSpacing.xs,
          children: [
            for (final entry in durations.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _minutes == entry.key,
                onSelected: (_) =>
                    setState(() => _minutes = entry.key),
              ),
          ],
        ),
        const SizedBox(height: StegSpacing.sm),
        StegTextField(
          controller: _reason,
          label: l10n.communityMuteReason,
          required: true,
          error: _error,
        ),
        if (!isOnline) ...[
          const SizedBox(height: StegSpacing.xs),
          Text(l10n.communityNeedsConnection,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error)),
        ],
        if (_serverError != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Semantics(
            liveRegion: true,
            label: _serverError,
            excludeSemantics: true,
            child: Text(_serverError!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
        const SizedBox(height: StegSpacing.md),
        StegButton(
          label: l10n.communityMute,
          variant: StegButtonVariant.destructive,
          loading: _sending,
          onPressed:
              (_sending || !isOnline) ? null : _send,
        ),
      ],
    );
  }
}
