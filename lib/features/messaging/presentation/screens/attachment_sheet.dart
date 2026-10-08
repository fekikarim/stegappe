import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/services/share_files.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../internship/domain/deliverable_file_rules.dart'
    show DeliverableFileRules;
import '../../../internship/domain/entities/work_items.dart'
    show DeliverableSummary;
import '../../../internship/presentation/providers/workspace_providers.dart'
    show internshipRepositoryProvider, refreshValidations;
import '../../../internship/presentation/widgets/status_labels.dart'
    show deliverableStatusLabel;
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
///
/// T07 (ST-MSG-02, ST-VAL-02): when [internshipId] is known (resolved from
/// the conversation by the caller — the list is server-filtered, never
/// client-filtered), the sheet also offers "send an internship document":
/// an existing deliverable (journal/report) downloaded and re-sent as a
/// chat attachment. The 10 MB chat cap still applies; oversize files name
/// the deliverables/validation path instead.
class AttachmentSheet extends ConsumerStatefulWidget {
  const AttachmentSheet(
      {super.key, required this.conversationId, this.internshipId});

  final String conversationId;

  /// The conversation's internship, when the caller could resolve it.
  /// Null hides the deliverable picker (device pick still works).
  final String? internshipId;

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
  // T07 deliverable picker state (ST-MSG-02): list toggle, rows future,
  // in-flight download, picker-scoped error (never mixed into send state).
  bool _showDocs = false;
  Future<List<DeliverableSummary>>? _docsFuture;
  String? _loadingDocId;
  String? _docError;

  /// T10/SU-VAL-01: set when the staged file came from a deliverable, so
  /// the send carries the source link (null for device-picked files).
  String? _stagedDeliverableId;

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
        // A fresh device file is not linked to any internship document.
        _stagedDeliverableId = null;
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
          deliverableId: _stagedDeliverableId,
          onProgress: (s, t) =>
              setState(() => _progress = t == 0 ? 0 : s / t));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _serverError = userMessageOf(e, l10n);
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _serverError = userMessageOf(e, l10n);
      });
    }
  }

  /// T07 (ST-MSG-02): loads the internship's deliverables for the picker.
  /// Server-scoped list; failures surface honestly with retry.
  void _toggleDocs() {
    final internshipId = widget.internshipId;
    if (internshipId == null) return;
    setState(() {
      _showDocs = !_showDocs;
      _docError = null;
      if (_showDocs && _docsFuture == null) {
        final repo = ref.read(internshipRepositoryProvider);
        _docsFuture = repo
            .listDeliverables(internshipId, size: 50)
            .then((page) => page.items);
      }
    });
  }

  /// Downloads one deliverable version's bytes and stages them as the
  /// attachment (caption prefilled with the document title, still editable
  /// — the contract requires a caption). Oversize files are refused with
  /// the alternative path, never sent partially.
  Future<void> _stageDoc(DeliverableSummary doc) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loadingDocId = doc.id;
      _docError = null;
    });
    try {
      final repo = ref.read(internshipRepositoryProvider);
      final detail = await repo.getDeliverable(doc.id);
      final fileName = detail.versions.isEmpty
          ? null
          : detail.versions.first.fileName;
      if (fileName == null || fileName.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingDocId = null;
          _docError = l10n.msgDocLoadFailed;
        });
        return;
      }
      final bytes = await repo.downloadDeliverable(doc.id);
      if (!mounted) return;
      final problem =
          ChatAttachmentRules.check(fileName, bytes.length);
      setState(() {
        _loadingDocId = null;
        if (problem == null) {
          _bytes = bytes;
          _fileName = fileName;
          _fileError = null;
          _showDocs = false;
          // T10/SU-VAL-01: staged FROM a document → the sent attachment
          // carries the source link so the supervisor can register its kind.
          _stagedDeliverableId = doc.id;
          if (_caption.text.trim().isEmpty) {
            _caption.text = doc.title;
          }
        } else if (problem == 'size') {
          _docError = l10n.msgDocTooLarge;
        } else {
          _docError = l10n.msgAttachWrongType;
        }
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDocId = null;
        _docError = userMessageOf(e, l10n);
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
        // T07 (ST-MSG-02): send journal/report from the chat. Hidden when
        // the caller could not resolve the conversation's internship
        // (device pick above still works).
        if (widget.internshipId != null) ...[
          const SizedBox(height: StegSpacing.xs),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.msgFromDocs),
            onPressed: _uploading ? null : _toggleDocs,
          ),
          if (_showDocs) _DocsPicker(
            future: _docsFuture,
            loadingDocId: _loadingDocId,
            error: _docError,
            onRetry: () => setState(() {
              final repo = ref.read(internshipRepositoryProvider);
              _docsFuture = repo
                  .listDeliverables(widget.internshipId!, size: 50)
                  .then((page) => page.items);
              _docError = null;
            }),
            onPick: _uploading ? null : _stageDoc,
          ),
        ],
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
    {required String conversationId, String? internshipId}) {
  return showStegSheet(
    context,
    title: AppLocalizations.of(context).msgAttach,
    builder: (_) => AttachmentSheet(
        conversationId: conversationId, internshipId: internshipId),
  );
}

/// T10/SU-VAL-01: attachment actions — open/download plus, for the
/// supervisor of the internship, "set as journal" / "set as report" on an
/// attachment sent from a document (both the long-press gesture and the
/// explicit "…" menu land here; the menu exists because long-press alone is
/// undiscoverable and inaccessible). Registration is first-level (D2/BR-28):
/// the administration takes the final decision — the feedback says so.
Future<void> showAttachmentDocumentActions(
  BuildContext context, {
  required MessageAttachment attachment,
  required bool canRegister,
  VoidCallback? onRegistered,
}) {
  return showStegSheet(
    context,
    title: attachment.fileName,
    builder: (_) => _AttachmentActionsBody(
        attachment: attachment,
        canRegister: canRegister,
        onRegistered: onRegistered),
  );
}

class _AttachmentActionsBody extends ConsumerStatefulWidget {
  const _AttachmentActionsBody({
    required this.attachment,
    required this.canRegister,
    this.onRegistered,
  });

  final MessageAttachment attachment;
  final bool canRegister;
  final VoidCallback? onRegistered;

  @override
  ConsumerState<_AttachmentActionsBody> createState() =>
      _AttachmentActionsBodyState();
}

class _AttachmentActionsBodyState
    extends ConsumerState<_AttachmentActionsBody> {
  bool _working = false;
  String? _error;

  Future<void> _register(String kind) async {
    final l10n = AppLocalizations.of(context);
    final sourceId = widget.attachment.sourceDeliverableId;
    if (sourceId == null || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await ref
          .read(internshipRepositoryProvider)
          .registerDocumentKind(sourceId, kind);
      if (!mounted) return;
      Navigator.of(context).pop();
      refreshValidations(ref);
      widget.onRegistered?.call();
      final kindLabel = kind == 'JOURNAL'
          ? l10n.deliverableKindJournal
          : l10n.deliverableKindReport;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.msgDocRegistered(kindLabel))));
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = userMessageOf(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final a = widget.attachment;
    final source = a.sourceDeliverableId;
    final current = a.sourceDocumentKind;
    final currentLabel = current == 'JOURNAL'
        ? l10n.deliverableKindJournal
        : l10n.deliverableKindReport;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(a.isImage
              ? Icons.image_outlined
              : Icons.picture_as_pdf_outlined),
          title: Text(a.fileName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              DeliverableFileRules.formatBytes(a.size)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.msgDownload),
          enabled: !_working,
          onTap: () {
            Navigator.of(context).pop();
            showAttachmentPreview(context, attachment: a);
          },
        ),
        if (widget.canRegister) ...[
          const Divider(),
          if (source == null)
            Text(l10n.msgDocNotLinked,
                style: Theme.of(context).textTheme.bodySmall),
          if (source != null) ...[
            if (current != null)
              Text(
                  '${l10n.deliverableKindLabel} : $currentLabel',
                  style:
                      Theme.of(context).textTheme.bodySmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.menu_book_outlined),
              title: Text(l10n.msgSetAsJournal),
              trailing: current == 'JOURNAL'
                  ? const Icon(Icons.check_outlined)
                  : null,
              enabled: !_working && current != 'JOURNAL',
              onTap: current == 'JOURNAL'
                  ? null
                  : () => _register('JOURNAL'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.description_outlined),
              title: Text(l10n.msgSetAsReport),
              trailing: current == 'REPORT'
                  ? const Icon(Icons.check_outlined)
                  : null,
              enabled: !_working && current != 'REPORT',
              onTap: current == 'REPORT'
                  ? null
                  : () => _register('REPORT'),
            ),
          ],
        ],
        if (_working) ...[
          const SizedBox(height: StegSpacing.sm),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Semantics(
            liveRegion: true,
            label: _error,
            excludeSemantics: true,
            child: Text(_error!,
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.error)),
          ),
        ],
      ],
    );
  }
}

/// Inline deliverable picker rows (T07): loading / error+retry / empty
/// (with the next action) / tappable documents with server status.
class _DocsPicker extends StatelessWidget {
  const _DocsPicker({
    required this.future,
    required this.loadingDocId,
    required this.error,
    required this.onRetry,
    required this.onPick,
  });

  final Future<List<DeliverableSummary>>? future;
  final String? loadingDocId;
  final String? error;
  final VoidCallback onRetry;
  final Future<void> Function(DeliverableSummary doc)? onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: StegSpacing.xs),
        Text(l10n.msgPickDoc,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: StegSpacing.xs),
        FutureBuilder<List<DeliverableSummary>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(StegSpacing.sm),
                child:
                    Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              final message = snapshot.hasError
                  ? context.userError(snapshot.error!).message
                  : l10n.msgDocLoadFailed;
              return Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      label: message,
                      excludeSemantics: true,
                      child: Text(message,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error)),
                    ),
                  ),
                  TextButton(
                      onPressed: onRetry,
                      child: Text(l10n.retry)),
                ],
              );
            }
            final docs = snapshot.data!;
            if (docs.isEmpty) {
              return Text(l10n.msgNoDocs,
                  style:
                      Theme.of(context).textTheme.bodySmall);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final doc in docs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: loadingDocId == doc.id
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.picture_as_pdf_outlined),
                    title: Text(doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${deliverableStatusLabel(doc.status, l10n)} • v${doc.currentVersion}'),
                    enabled: onPick != null &&
                        loadingDocId == null,
                    onTap: onPick == null
                        ? null
                        : () => onPick!(doc),
                  ),
              ],
            );
          },
        ),
        if (error != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Semantics(
            liveRegion: true,
            label: error,
            excludeSemantics: true,
            child: Text(error!,
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.error)),
          ),
        ],
      ],
    );
  }
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
          _error = context.userError(e).message;
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
