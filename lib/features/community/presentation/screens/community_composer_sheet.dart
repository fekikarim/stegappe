import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../messaging/presentation/screens/attachment_sheet.dart'
    show ChatAttachmentRules;
import '../../domain/entities/community.dart';
import '../providers/community_providers.dart';

/// Community composer (T08 / ST-COM-01): text (≤2000, capped) + one
/// optional image/PDF (≤10 MB, server-checked). Submits through the feed
/// controller's optimistic path: the sheet closes, a pending card appears,
/// and a failure becomes a retryable failed card (prefilled on retry).
/// Online-only with an explicit reason when offline.
Future<void> showCommunityComposer(
  BuildContext context, {
  String? initialText,
  Uint8List? initialBytes,
  String? initialFileName,
  String? initialContentType,
  String? idempotencyKey,
}) {
  return showStegSheet<void>(
    context,
    title: AppLocalizations.of(context).communityPublish,
    builder: (_) => _CommunityComposer(
      initialText: initialText,
      initialBytes: initialBytes,
      initialFileName: initialFileName,
      initialContentType: initialContentType,
      idempotencyKey: idempotencyKey,
    ),
  );
}

class _CommunityComposer extends ConsumerStatefulWidget {
  const _CommunityComposer({
    this.initialText,
    this.initialBytes,
    this.initialFileName,
    this.initialContentType,
    this.idempotencyKey,
  });

  final String? initialText;
  final Uint8List? initialBytes;
  final String? initialFileName;
  final String? initialContentType;
  final String? idempotencyKey;

  @override
  ConsumerState<_CommunityComposer> createState() =>
      _CommunityComposerState();
}

class _CommunityComposerState
    extends ConsumerState<_CommunityComposer> {
  late final TextEditingController _text;
  Uint8List? _bytes;
  String? _fileName;
  String? _contentType;
  String? _fileError;
  String? _serverError;
  bool _sending = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText ?? '');
    _bytes = widget.initialBytes;
    _fileName = widget.initialFileName;
    _contentType = widget.initialContentType;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF / JPEG / PNG',
          extensions: ['pdf', 'jpg', 'jpeg', 'png'],
          mimeTypes: [
            'application/pdf',
            'image/jpeg',
            'image/png'
          ],
        ),
      ],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name;
    final problem =
        ChatAttachmentRules.check(name, bytes.length);
    setState(() {
      if (problem == null) {
        _bytes = bytes;
        _fileName = name;
        final ext = name.contains('.')
            ? name.split('.').last.toLowerCase()
            : '';
        _contentType =
            ChatAttachmentRules.mimeForExtension[ext] ??
                'application/octet-stream';
        _fileError = null;
      } else {
        _bytes = null;
        _fileName = null;
        _contentType = null;
        _fileError = problem == 'size'
            ? l10n.msgAttachTooLarge
            : l10n.msgAttachWrongType;
      }
      _serverError = null;
    });
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    if (body.length > CommunityContentRules.maxPostLength) {
      setState(() =>
          _serverError = l10n.errCommunityTooLong);
      return;
    }
    setState(() {
      _sending = true;
      _serverError = null;
    });
    try {
      await ref.read(communityFeedProvider.notifier).createPost(
            body,
            bytes: _bytes,
            fileName: _fileName,
            contentType: _contentType,
            onProgress: (s, t) =>
                setState(() => _progress = t == 0 ? 0 : s / t),
            idempotencyKey: widget.idempotencyKey,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e) {
      // The controller already rolled the optimistic card into `failed`
      // (retry reopens this sheet prefilled); surfacing the sentence here
      // as well would double-report. Close and let the failed card speak.
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessageOf(e, l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOnline = ref.watch(isOnlineProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StegTextField(
          controller: _text,
          label: l10n.communityComposerHint,
          required: true,
        ),
        const SizedBox(height: StegSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file_outlined),
          label: Text(_fileName ?? l10n.communityAttach),
          onPressed: _sending ? null : _pick,
        ),
        if (_fileError != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Semantics(
            liveRegion: true,
            label: _fileError,
            excludeSemantics: true,
            child: Text(_fileError!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
        if (_sending && _bytes != null) ...[
          const SizedBox(height: StegSpacing.sm),
          LinearProgressIndicator(value: _progress),
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
        if (!isOnline) ...[
          const SizedBox(height: StegSpacing.xs),
          Text(l10n.communityNeedsConnection,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: StegSpacing.md),
        StegButton(
          label: l10n.communityPublish,
          icon: Icons.send_outlined,
          loading: _sending,
          onPressed: (_sending || !isOnline) ? null : _send,
        ),
      ],
    );
  }
}
