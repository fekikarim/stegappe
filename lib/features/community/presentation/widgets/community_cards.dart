import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_colors.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../internship/presentation/widgets/status_labels.dart'
    show formatDay;
import '../../domain/entities/community.dart';

/// Timestamp label for community rows: time-today, Yesterday, else the
/// locale date (same rhythm as the chat day separators).
String communityTimeLabel(
    DateTime sentAt, AppLocalizations l10n, Locale locale) {
  final local = sentAt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) {
    return '${l10n.msgToday} · ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return l10n.msgYesterday;
  }
  return formatDay(local, locale);
}

/// One feed post card: display name (never email — server-derived),
/// timestamp, body, optional attachment chip, comment count, overflow menu.
///
/// No role logic lives here: the caller passes exactly the actions the
/// caller's role may attempt (UX only — the server decides).
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onRetry,
    this.menuItems = const [],
    this.failed = false,
  });

  final CommunityPost post;
  final VoidCallback? onOpen;
  final VoidCallback? onRetry;
  final List<CommunityMenuAction> menuItems;

  /// Failed send: error-toned card with retry (never a spinner — spinners
  /// never settle and hide the failure, cf. chat failed bubbles).
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: failed ? scheme.errorContainer : null,
      child: InkWell(
        onTap: failed ? null : onOpen,
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        child: Padding(
          padding: StegSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: StegColors.communityAccent
                        .withValues(alpha: 0.15),
                    child: Text(
                      post.authorDisplayName.isEmpty
                          ? '?'
                          : post.authorDisplayName.characters.first,
                      style: TextStyle(
                          color: StegColors.communityAccent,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: StegSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorDisplayName.isEmpty
                              ? '—'
                              : post.authorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          communityTimeLabel(
                              post.createdAt, l10n, locale),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (failed)
                    Semantics(
                      label: l10n.msgFailed,
                      child: Icon(Icons.error_outline,
                          color: scheme.onErrorContainer),
                    )
                  else if (post.pending)
                    Semantics(
                      label: l10n.pendingLabel,
                      child: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (menuItems.isNotEmpty)
                    Semantics(
                      button: true,
                      label: l10n.communityReport,
                      child: PopupMenuButton<CommunityMenuAction>(
                        tooltip: l10n.communityReport,
                        icon: const Icon(Icons.more_vert_outlined),
                        onSelected: (a) => a.onSelected(),
                        itemBuilder: (_) => [
                          for (final a in menuItems)
                            PopupMenuItem<CommunityMenuAction>(
                              value: a,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(a.icon,
                                      size: 20,
                                      color: a.destructive
                                          ? scheme.error
                                          : null),
                                  const SizedBox(
                                      width: StegSpacing.xs),
                                  Flexible(
                                    child: Text(a.label,
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: a.destructive
                                            ? TextStyle(
                                                color: scheme.error)
                                            : null),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: StegSpacing.xs),
              Semantics(
                label: post.body,
                child: Text(post.body),
              ),
              if (post.attachment != null) ...[
                const SizedBox(height: StegSpacing.xs),
                _AttachmentRow(attachment: post.attachment!),
              ],
              const SizedBox(height: StegSpacing.xs),
              Row(
                children: [
                  if (failed) ...[
                    Icon(Icons.error_outline,
                        size: 16,
                        color: scheme.onErrorContainer),
                    const SizedBox(width: StegSpacing.xxs),
                    Expanded(
                      child: Text(l10n.msgFailed,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color:
                                      scheme.onErrorContainer)),
                    ),
                  ] else ...[
                    Icon(Icons.chat_bubble_outline,
                        size: 16,
                        color: scheme.onSurfaceVariant),
                    const SizedBox(width: StegSpacing.xxs),
                    Text('${post.commentCount}',
                        style:
                            Theme.of(context).textTheme.bodySmall),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(width: StegSpacing.sm),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon:
                          const Icon(Icons.refresh_outlined, size: 16),
                      label: Text(l10n.msgRetry),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overflow-menu entry (label + icon + destructive tone + callback).
/// The CALLER builds the list per role/content — this widget renders it.
class CommunityMenuAction {
  const CommunityMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment});

  final CommunityAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: StegSpacing.sm, vertical: StegSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
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
              size: 20),
          const SizedBox(width: StegSpacing.xs),
          Flexible(
            child: Text(attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// One comment row: display name, relative position in thread, body.
/// Pending comments render dimmed with a spinner (never as sent).
class CommunityCommentTile extends StatelessWidget {
  const CommunityCommentTile({
    super.key,
    required this.comment,
    this.menuItems = const [],
  });

  final CommunityComment comment;
  final List<CommunityMenuAction> menuItems;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: comment.pending ? 0.7 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: StegSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  StegColors.communityAccent.withValues(alpha: 0.15),
              child: Text(
                comment.authorDisplayName.isEmpty
                    ? '?'
                    : comment.authorDisplayName.characters.first,
                style: TextStyle(
                    color: StegColors.communityAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
            const SizedBox(width: StegSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.authorDisplayName.isEmpty
                              ? '—'
                              : comment.authorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        communityTimeLabel(
                            comment.createdAt, l10n, locale),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    label: comment.body,
                    child: Text(comment.body),
                  ),
                  if (comment.pending)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(l10n.pendingLabel,
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                ],
              ),
            ),
            if (comment.pending)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (menuItems.isNotEmpty)
              Semantics(
                button: true,
                label: l10n.communityReport,
                child: PopupMenuButton<CommunityMenuAction>(
                  tooltip: l10n.communityReport,
                  iconSize: 18,
                  icon: const Icon(Icons.more_vert_outlined),
                  onSelected: (a) => a.onSelected(),
                  itemBuilder: (_) => [
                    for (final a in menuItems)
                      PopupMenuItem<CommunityMenuAction>(
                        value: a,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(a.icon,
                                size: 20,
                                color: a.destructive
                                    ? scheme.error
                                    : null),
                            const SizedBox(width: StegSpacing.xs),
                            Flexible(
                              child: Text(a.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: a.destructive
                                      ? TextStyle(
                                          color: scheme.error)
                                      : null),
                            ),
                          ],
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
