import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_colors.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../domain/entities/conversation.dart';
import '../screens/attachment_sheet.dart'
    show showAttachmentDocumentActions, showAttachmentPreview;

/// One message bubble: Messenger-grade sender side, redaction for
/// soft-deleted history, per-message attachments, WhatsApp-style ticks for
/// own messages and an optional Seen receipt under the newest own message.
///
/// Markers reflect backend-reported status only (SENT/DELIVERED/READ),
/// updated live via topic broadcasts. Edit/delete surface through a
/// long-press sheet on the viewer's own messages in 1-to-1 threads.
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.canRegisterDocuments = false,
    this.onDocumentRegistered,
    this.onEdit,
    this.onDelete,
    this.seen = false,
  });

  final ChatMessage message;

  /// Supervisor/admin of the internship: the attachment "…" menu offers
  /// "set as journal" / "set as report" (server enforces the real scope).
  final bool canRegisterDocuments;

  /// Called after a successful registration (refresh the thread so the
  /// kind label on the chip stays honest).
  final VoidCallback? onDocumentRegistered;

  /// 1-to-1 message actions (null hides the long-press menu).
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;

  /// True on the newest own message once the peer read it (Messenger Seen).
  final bool seen;

  bool get _actionsAllowed =>
      message.mine &&
      !message.isDeleted &&
      (onEdit != null || onDelete != null);

  Future<void> _showActions(BuildContext context) async {
    if (!_actionsAllowed) return;
    final l10n = AppLocalizations.of(context);
    await showStegSheet<void>(
      context,
      title: l10n.msgEditTitle,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onEdit != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.msgEdit),
              onTap: () {
                Navigator.of(ctx).pop();
                onEdit!();
              },
            ),
          if (onDelete != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text(l10n.msgDeleteTitle,
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete!();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mine = message.mine;
    final deleted = message.isDeleted;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final bubble = Container(
      margin: EdgeInsetsDirectional.only(
        start: mine ? 64 : StegSpacing.sm,
        end: mine ? StegSpacing.sm : 64,
        top: 3,
        bottom: seen && mine && !deleted ? 1 : 3,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: StegSpacing.md, vertical: StegSpacing.sm),
      decoration: BoxDecoration(
        gradient: mine
            ? const LinearGradient(
                colors: [Color(0xFF0B61A0), Color(0xFF1478C8)],
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
              )
            : null,
        color:
            mine ? null : (dark ? StegColors.darkElevated : Colors.white),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 5),
          bottomRight: Radius.circular(mine ? 5 : 18),
        ),
        border: mine
            ? null
            : Border.all(
                color: dark
                    ? StegColors.darkBorder
                    : StegColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: (mine
                    ? const Color(0xFF0B61A0)
                    : Colors.black)
                .withValues(
                    alpha: mine ? 0.25 : (dark ? 0.3 : 0.07)),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: deleted ? l10n.msgDeleted : message.content,
            child: Text(
              deleted ? l10n.msgDeleted : message.content,
              style: (deleted
                      ? Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic)
                      : Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                      color: mine
                          ? (deleted
                              ? Colors.white.withValues(alpha: 0.75)
                              : Colors.white)
                          : (deleted
                              ? Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                              : null),
                      height: 1.45),
            ),
          ),
          if (!deleted)
            for (final a in message.attachments)
              _AttachmentChip(
                  attachment: a,
                  mine: mine,
                  conversationId: message.conversationId,
                  canRegister: canRegisterDocuments,
                  onRegistered: onDocumentRegistered),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _clock(message.sentAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.8)
                        : null),
              ),
              if (mine && !deleted) ...[
                const SizedBox(width: 4),
                _StatusMark(status: message.status, onBlue: true),
              ],
              if (message.status == MessageStatus.edited && !deleted)
                Text(' • ${l10n.msgEdited}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            fontSize: 11,
                            color: mine
                                ? Colors.white.withValues(alpha: 0.8)
                                : null)),
            ],
          ),
        ],
      ),
    );

    final withGesture = _actionsAllowed
        ? GestureDetector(
            onLongPress: () => _showActions(context),
            child: bubble,
          )
        : bubble;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: mine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: withGesture,
        ),
        // Messenger Seen receipt under the newest own read message.
        if (seen && mine && !deleted)
          Padding(
            padding: EdgeInsetsDirectional.only(
                end: StegSpacing.md, top: 1, bottom: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.done_all_rounded,
                    size: 13, color: Color(0xFF53BDEB)),
                const SizedBox(width: 3),
                Text(l10n.msgSeen,
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: const Color(0xFF53BDEB),
                              fontWeight: FontWeight.w600,
                            )),
              ],
            ),
          ),
      ],
    );
  }

  String _clock(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Backend-reported marker for own messages (WhatsApp-style ticks:
/// single grey = sent, double grey = delivered, double blue = read).
class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.status, this.onBlue = false});

  final MessageStatus status;
  final bool onBlue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, label, color) = switch (status) {
      MessageStatus.read => (
          Icons.done_all_rounded,
          l10n.msgRead,
          onBlue ? Colors.white : const Color(0xFF53BDEB),
        ),
      MessageStatus.delivered => (
          Icons.done_all_outlined,
          l10n.msgDelivered,
          onBlue
              ? Colors.white.withValues(alpha: 0.75)
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      _ => (
          Icons.done_outlined,
          l10n.msgSent,
          onBlue
              ? Colors.white.withValues(alpha: 0.75)
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };
    return Semantics(
      label: label,
      child: Icon(icon, size: 15, color: color),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    required this.conversationId,
    this.mine = false,
    this.canRegister = false,
    this.onRegistered,
  });

  final MessageAttachment attachment;
  final String conversationId;
  final bool mine;
  final bool canRegister;
  final VoidCallback? onRegistered;

  void _openActions(BuildContext context) {
    showAttachmentDocumentActions(
      context,
      attachment: attachment,
      canRegister: canRegister,
      onRegistered: onRegistered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kindLabel = attachment.sourceDocumentKind == 'JOURNAL'
        ? l10n.deliverableKindJournal
        : attachment.sourceDocumentKind == 'REPORT'
            ? l10n.deliverableKindReport
            : null;
    final border =
        mine ? Colors.white.withValues(alpha: 0.45) : Theme.of(context).dividerColor;
    final fg = mine ? Colors.white : null;
    return Padding(
      padding: const EdgeInsets.only(top: StegSpacing.xs),
      child: Semantics(
        button: true,
        label: '${attachment.fileName}'
            '${kindLabel == null ? '' : ', $kindLabel'}'
            ', ${l10n.msgDownload}',
        child: InkWell(
          onTap: () =>
              showAttachmentPreview(context, attachment: attachment),
          // Long-press reaches the same actions sheet as
          // the explicit "…" menu below (gesture alone is inaccessible).
          onLongPress: () => _openActions(context),
          borderRadius: BorderRadius.circular(StegSpacing.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: StegSpacing.sm, vertical: StegSpacing.xs),
            decoration: BoxDecoration(
              color: mine
                  ? Colors.white.withValues(alpha: 0.14)
                  : null,
              border: Border.all(color: border),
              borderRadius:
                  BorderRadius.circular(StegSpacing.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    attachment.isImage
                        ? Icons.image_outlined
                        : Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: fg),
                const SizedBox(width: StegSpacing.xs),
                Flexible(
                  // Filenames are LTR technical values.
                  child: BidiText(attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: fg)),
                ),
                if (kindLabel != null) ...[
                  const SizedBox(width: StegSpacing.xs),
                  Text(kindLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: fg ??
                                  Theme.of(context)
                                      .colorScheme
                                      .primary,
                              fontWeight: FontWeight.w700)),
                ],
                const SizedBox(width: StegSpacing.xs),
                Icon(Icons.download_outlined, size: 18, color: fg),
                IconButton(
                  icon: Icon(Icons.more_vert_outlined,
                      size: 18, color: fg),
                  tooltip: l10n.msgDocMenu,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                      minWidth: 40, minHeight: 40),
                  onPressed: () => _openActions(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
