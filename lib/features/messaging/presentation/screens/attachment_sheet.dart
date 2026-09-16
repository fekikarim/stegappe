import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/share_files.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../internship/domain/deliverable_file_rules.dart'
    show DeliverableFileRules;
import '../../domain/entities/conversation.dart';
import '../providers/messaging_providers.dart';

/// Backend-confirmed attachment rules (contract summary on
/// `sendWithAttachment`): PDF/JPEG/PNG, 10 MB max, Tika-verified.
abstract final class ChatAttachmentRules {
  static const int maxBytes = 10 * 1024 * 1024;
  static const Set<String> allowedExtensions = {
    'pdf',
    'jpg',
    'jpeg',
    'png'
  };
  static const Map<String, String> mimeForExtension = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };

  static String? check(String fileName, int sizeBytes) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    if (!allowedExtensions.contains(ext)) return 'type';
    if (sizeBytes > maxBytes) return 'size';
    if (sizeBytes <= 0) return 'empty';
    return null;
  }
}

/// Attachment send sheet: caption (REQUIRED by contract query param),
/// file pick with pre-check, real progress, retry without losing state.
class AttachmentSheet extends ConsumerStatefulWidget {
  const AttachmentSheet({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<AttachmentSheet> createState() =>
      _AttachmentSheetState();
}

class _AttachmentSheetState
    extends ConsumerState<AttachmentSheet> {
  final _caption = TextEditingController();
  Uint8List? _bytes;
  String? _fileName;
  String? _fileError;
  String? _captionError;
  String? _serverError;
  bool _uploading = false;
  double _progress = 0;

  @override
  void dispose() {
    _caption.dispose();
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
    if (file == null) return; // user cancelled
    final bytes = await file.readAsBytes();
    final name = file.name;
    final problem =
        ChatAttachmentRules.check(name, bytes.length);
    setState(() {
      if (problem == null) {
        _bytes = bytes;
        _fileName = name;
        _fileError = null;
      } else {
        _bytes = null;
        _fileName = null;
        _fileError = problem == 'size'
            ? l10n.msgAttachTooLarge
            : l10n.msgAttachWrongType;
      }
      _serverError = null;
    });
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final bytes = _bytes;
    final name = _fileName;
    if (_caption.text.trim().isEmpty) {
      setState(
          () => _captionError = l10n.journalFieldRequired);
      return;
    }
    if (bytes == null || name == null || _uploading) {
      if (bytes == null) {
        setState(() => _fileError = l10n.deliverableNoFile);
      }
      return;
    }
    setState(() {
      _uploading = true;
      _captionError = null;
      _serverError = null;
      _progress = 0;
    });
    try {
      final ext = name.split('.').last.toLowerCase();
      await ref.read(messagingRepositoryProvider).sendWithAttachment(
          widget.conversationId,
          content: _caption.text.trim(),
          fileName: name,
          contentType: ChatAttachmentRules.mimeForExtension[ext] ??
              'application/octet-stream',
          bytes: bytes,
          onProgress: (s, t) =>
              setState(() => _progress = t == 0 ? 0 : s / t));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _serverError = e.message;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _serverError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.msgAttachTypes,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: StegSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file_outlined),
          label: Text(_fileName ?? l10n.msgAttach),
          onPressed: _uploading ? null : _pick,
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
        if (_bytes != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Text(
            '$_fileName • ${DeliverableFileRules.formatBytes(_bytes!.length)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: StegSpacing.sm),
        StegTextField(
          controller: _caption,
          label: l10n.msgAttachCaption,
          required: true,
          error: _captionError,
        ),
        if (_uploading) ...[
          const SizedBox(height: StegSpacing.sm),
          Semantics(
            label: '${(_progress * 100).round()} %',
            excludeSemantics: true,
            child: LinearProgressIndicator(value: _progress),
          ),
        ],
        if (_serverError != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Semantics(
            liveRegion: true,
            label: _serverError,
            excludeSemantics: true,
            child: Text(
              '${l10n.uploadFailedRetry}\n$_serverError',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: StegSpacing.md),
        StegButton(
          label: l10n.msgSend,
          icon: Icons.send_outlined,
          loading: _uploading,
          onPressed:
              (_bytes == null || _uploading) ? null : _send,
        ),
      ],
    );
  }
}

Future<void> showAttachmentSheet(BuildContext context,
    {required String conversationId}) {
  return showStegSheet(
    context,
    title: AppLocalizations.of(context).msgAttach,
    builder: (_) =>
        AttachmentSheet(conversationId: conversationId),
  );
}

/// Attachment preview: downloads via the audited member-only endpoint,
/// shows images inline, offers share for any type.
Future<void> showAttachmentPreview(BuildContext context,
    {required MessageAttachment attachment,
    Future<void> Function(Uint8List bytes, String fileName)?
        shareFn}) {
  return showStegSheet(
    context,
    title: attachment.fileName,
    builder: (_) => _AttachmentPreviewBody(
        attachment: attachment,
        shareFn: shareFn ?? shareBytes),
  );
}

class _AttachmentPreviewBody extends ConsumerStatefulWidget {
  const _AttachmentPreviewBody(
      {required this.attachment, required this.shareFn});

  final MessageAttachment attachment;
  final Future<void> Function(Uint8List bytes, String fileName) shareFn;

  @override
  ConsumerState<_AttachmentPreviewBody> createState() =>
      _AttachmentPreviewBodyState();
}

class _AttachmentPreviewBodyState
    extends ConsumerState<_AttachmentPreviewBody> {
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(messagingRepositoryProvider);
      final bytes = await repo.downloadAttachment(
          widget.attachment.id, widget.attachment.fileName);
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              e is ApiException ? e.message : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(StegSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _bytes == null) {
      return Padding(
        padding: const EdgeInsets.all(StegSpacing.sm),
        child: Semantics(
          liveRegion: true,
          label: _error,
          excludeSemantics: true,
          child: Text(_error ?? '',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error)),
        ),
      );
    }
    final bytes = _bytes!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.attachment.isImage)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                  StegSpacing.radiusSm),
              // Downscale at decode time: chat images can be 10 MB;
              // full-resolution decode would spike memory (D7).
              child: Image(
                image: ResizeImage(
                  MemoryImage(bytes),
                  width: 1080,
                ),
                fit: BoxFit.contain,
              ),
            ),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.picture_as_pdf_outlined),
            title: Text(widget.attachment.fileName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(DeliverableFileRules.formatBytes(
                widget.attachment.size)),
          ),
        const SizedBox(height: StegSpacing.sm),
        StegButton(
          label: l10n.msgDownload,
          icon: Icons.share_outlined,
          loading: _sharing,
          onPressed: _sharing
              ? null
              : () async {
                  setState(() => _sharing = true);
                  try {
                    await widget.shareFn(
                        bytes, widget.attachment.fileName);
                  } finally {
                    if (mounted) {
                      setState(() => _sharing = false);
                    }
                  }
                },
        ),
      ],
    );
  }
}
