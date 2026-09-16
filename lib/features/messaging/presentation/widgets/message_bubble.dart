import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../domain/entities/conversation.dart';
import '../screens/attachment_sheet.dart' show showAttachmentPreview;

/// One message bubble: sender side, redaction for soft-deleted history,
/// per-message attachments, and read/delivery markers for own messages.
///
/// Markers reflect backend-reported status only (SENT/DELIVERED/READ),
/// updated live via topic broadcasts.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mine = message.mine;
    final deleted = message.isDeleted;

    final bubble = Container(
      margin: EdgeInsetsDirectional.only(
        start: mine ? 64 : StegSpacing.sm,
        end: mine ? StegSpacing.sm : 64,
        top: 2,
        bottom: 2,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: StegSpacing.sm,
          vertical: StegSpacing.xs),
      decoration: BoxDecoration(
        color: mine
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!mine && !deleted)
            Text(
              message.senderId.length > 8
                  ? message.senderId.substring(0, 8)
                  : message.senderId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          Semantics(
            label: deleted
                ? l10n.msgDeleted
                : message.content,
            child: Text(
              deleted
                  ? l10n.msgDeleted
                  : message.content,
              style: deleted
                  ? Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)
                  : null,
            ),
          ),
          if (!deleted)
            for (final a in message.attachments)
              _AttachmentChip(
                  attachment: a,
                  conversationId: message.conversationId),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _clock(message.sentAt),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11),
              ),
              if (mine && !deleted) ...[
                const SizedBox(width: 4),
                _StatusMark(status: message.status),
              ],
              if (message.status == MessageStatus.edited &&
                  !deleted)
                Text(' • ${l10n.msgEdited}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: bubble,
    );
  }

  String _clock(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Backend-reported marker for own messages.
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, label) = switch (status) {
      MessageStatus.read =>
        (Icons.done_all_outlined, l10n.msgRead),
      MessageStatus.delivered =>
        (Icons.done_all_outlined, l10n.msgDelivered),
      _ => (Icons.done_outlined, l10n.msgSent),
    };
    return Semantics(
      label: label,
      child: Icon(icon, size: 14),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip(
      {required this.attachment, required this.conversationId});

  final MessageAttachment attachment;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: StegSpacing.xs),
      child: Semantics(
        button: true,
        label: '${attachment.fileName}, ${l10n.msgDownload}',
        child: InkWell(
          onTap: () => showAttachmentPreview(context,
              attachment: attachment),
          borderRadius:
              BorderRadius.circular(StegSpacing.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: StegSpacing.sm,
                vertical: StegSpacing.xs),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(
                  StegSpacing.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    attachment.isImage
                        ? Icons.image_outlined
                        : Icons.picture_as_pdf_outlined,
                    size: 20),
                const SizedBox(width: StegSpacing.xs),
                Flexible(
                  child: Text(attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall),
                ),
                const SizedBox(width: StegSpacing.xs),
                const Icon(Icons.download_outlined, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
