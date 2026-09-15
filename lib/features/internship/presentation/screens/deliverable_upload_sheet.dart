import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../domain/deliverable_file_rules.dart';
import '../providers/workspace_providers.dart';

/// File selected locally, before upload.
class PickedPdf {
  const PickedPdf({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

Future<PickedPdf?> pickPdf() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions:
        DeliverableFileRules.allowedExtensions.toList(),
    withData: true,
  );
  final file = result == null || result.files.isEmpty
      ? null
      : result.files.first;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return PickedPdf(fileName: file.name, bytes: bytes);
}

enum _UploadPhase { editing, uploading, error }

/// New-version upload sheet (also reused for first creation via
/// [DeliverableUploadSheet.showCreate]). Shows backend-confirmed limits,
/// real progress, and retry without losing the form.
class VersionUploadSheet extends ConsumerStatefulWidget {
  const VersionUploadSheet({
    super.key,
    required this.internshipId,
    this.deliverableId,
    this.createTitle,
    this.createDescription,
  }) : assert((deliverableId == null) == (createTitle != null),
            'create mode needs a title');

  final String internshipId;
  final String? deliverableId;
  final String? createTitle;
  final String? createDescription;

  bool get isCreate => deliverableId == null;

  static Future<void> showNewVersion(
    BuildContext context, {
    required String deliverableId,
  }) =>
      showStegSheet(
        context,
        title: AppLocalizations.of(context).deliverableNewVersion,
        builder: (_) => VersionUploadSheet(
          internshipId: '',
          deliverableId: deliverableId,
        ),
      );

  @override
  ConsumerState<VersionUploadSheet> createState() =>
      _VersionUploadSheetState();
}

class _VersionUploadSheetState
    extends ConsumerState<VersionUploadSheet> {
  final _note = TextEditingController();
  PickedPdf? _file;
  String? _fileError;
  String? _serverError;
  _UploadPhase _phase = _UploadPhase.editing;
  double _progress = 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final picked = await pickPdf();
    if (picked == null) return; // user cancelled
    final rejection = DeliverableFileRules.check(
        picked.fileName, picked.bytes.length);
    setState(() {
      if (rejection == null) {
        _file = picked;
        _fileError = null;
      } else {
        _file = null;
        _fileError = rejection == FileRejection.tooLarge
            ? l10n.deliverableTooLarge
            : l10n.deliverableWrongType;
      }
      _serverError = null;
    });
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null || _phase == _UploadPhase.uploading) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _phase = _UploadPhase.uploading;
      _progress = 0;
      _serverError = null;
    });
    try {
      final repo = ref.read(internshipRepositoryProvider);
      if (widget.isCreate) {
        await repo.createDeliverable(widget.internshipId,
            title: widget.createTitle!,
            description: widget.createDescription,
            fileName: file.fileName,
            fileBytes: file.bytes,
            onProgress: (s, t) => setState(
                () => _progress = t == 0 ? 0 : s / t));
      } else {
        await repo.uploadNewVersion(widget.deliverableId!,
            fileName: file.fileName,
            fileBytes: file.bytes,
            changeSummary: _note.text.trim().isEmpty
                ? null
                : _note.text.trim(),
            onProgress: (s, t) => setState(
                () => _progress = t == 0 ? 0 : s / t));
      }
      refreshDeliverables(ref, widget.deliverableId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isCreate
              ? l10n.deliverableUploaded
              : l10n.deliverableVersionUploaded),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _UploadPhase.error;
        _serverError = e.message;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _UploadPhase.error;
        _serverError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uploading = _phase == _UploadPhase.uploading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.deliverablesSubtitle,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: StegSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_file == null
              ? l10n.deliverablePickFile
              : l10n.deliverableChangeFile),
          onPressed: uploading ? null : _pick,
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
        if (_file != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Text(
            '${_file!.fileName} • ${DeliverableFileRules.formatBytes(_file!.bytes.length)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (!widget.isCreate) ...[
          const SizedBox(height: StegSpacing.sm),
          StegTextField(
            controller: _note,
            label: l10n.deliverableChangeNote,
          ),
        ],
        if (uploading) ...[
          const SizedBox(height: StegSpacing.sm),
          Semantics(
            label:
                '${(_progress * 100).round()} %',
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
          label: l10n.deliverableUpload,
          icon: Icons.cloud_upload_outlined,
          loading: uploading,
          onPressed:
              (_file == null || uploading) ? null : _upload,
        ),
      ],
    );
  }
}

/// First-creation sheet: title + optional description + PDF.
/// Backend creates the deliverable as DRAFT with v1.
class DeliverableUploadSheet extends ConsumerStatefulWidget {
  const DeliverableUploadSheet({
    super.key,
    required this.internshipId,
  });

  final String internshipId;

  static Future<void> showCreate(
    BuildContext context, {
    required String internshipId,
  }) =>
      showStegSheet(
        context,
        title: AppLocalizations.of(context).deliverableNew,
        builder: (_) =>
            DeliverableUploadSheet(internshipId: internshipId),
      );

  @override
  ConsumerState<DeliverableUploadSheet> createState() =>
      _DeliverableUploadSheetState();
}

class _DeliverableUploadSheetState
    extends ConsumerState<DeliverableUploadSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  PickedPdf? _file;
  String? _titleError;
  String? _fileError;
  String? _serverError;
  bool _uploading = false;
  double _progress = 0;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final picked = await pickPdf();
    if (picked == null) return;
    final rejection = DeliverableFileRules.check(
        picked.fileName, picked.bytes.length);
    setState(() {
      if (rejection == null) {
        _file = picked;
        _fileError = null;
      } else {
        _file = null;
        _fileError = rejection == FileRejection.tooLarge
            ? l10n.deliverableTooLarge
            : l10n.deliverableWrongType;
      }
      _serverError = null;
    });
  }

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      setState(() => _titleError = l10n.taskTitleRequired);
      return;
    }
    final file = _file;
    if (file == null || _uploading) {
      if (file == null) {
        setState(() => _fileError = l10n.deliverableNoFile);
      }
      return;
    }
    setState(() {
      _uploading = true;
      _titleError = null;
      _serverError = null;
      _progress = 0;
    });
    try {
      await ref.read(internshipRepositoryProvider).createDeliverable(
          widget.internshipId,
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          fileName: file.fileName,
          fileBytes: file.bytes,
          onProgress: (s, t) =>
              setState(() => _progress = t == 0 ? 0 : s / t));
      refreshDeliverables(ref, null);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deliverableUploaded)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _titleError = e.fieldMessage('title');
        _serverError =
            _titleError == null ? e.message : null;
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
        Text(l10n.deliverablesSubtitle,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: StegSpacing.sm),
        StegTextField(
          controller: _title,
          label: l10n.deliverableTitleLabel,
          required: true,
          error: _titleError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: StegSpacing.sm),
        StegTextField(
          controller: _description,
          label: l10n.deliverableDescLabel,
        ),
        const SizedBox(height: StegSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_file == null
              ? l10n.deliverablePickFile
              : l10n.deliverableChangeFile),
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
        if (_file != null) ...[
          const SizedBox(height: StegSpacing.xs),
          Text(
            '${_file!.fileName} • ${DeliverableFileRules.formatBytes(_file!.bytes.length)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
          label: l10n.deliverableUpload,
          icon: Icons.cloud_upload_outlined,
          loading: _uploading,
          onPressed:
              (_file == null || _uploading) ? null : _upload,
        ),
      ],
    );
  }
}
