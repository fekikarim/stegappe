import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_button.dart';
import '../../../../core/widgets/steg_dialog.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/community.dart';
import '../providers/community_providers.dart';
import 'community_moderation_sheets.dart';
import 'community_post_detail_screen.dart';

/// Staff moderation queue (T08 / D7): open/all reports, resolve with an
/// optional conclusion, mute/unmute from the report row.
///
/// Staff-only by server rule; the entry points (feed AppBar action, More
/// card) are hidden for students, and a direct open degrades to the
/// server's 403 sentence instead of a fake list.
class CommunityReportsScreen extends ConsumerWidget {
  const CommunityReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(communityReportsProvider);
    final controller = ref.read(communityReportsProvider.notifier);
    final auth = ref.watch(authControllerProvider);
    final role = auth is AuthAuthenticated
        ? auth.user.mobileRole
        : UserRole.unsupported;

    ref.listen<CommunityReportsState>(communityReportsProvider,
        (previous, next) {
      if (next.actionError != null &&
          next.actionError != previous?.actionError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(context.userError(next.actionError!).message)));
        controller.clearActionError();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityReports)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(StegSpacing.md,
                StegSpacing.sm, StegSpacing.md, 0),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.communityOpenReports),
                  selected: state.openOnly,
                  onSelected: (_) => controller.setOpenOnly(true),
                ),
                const SizedBox(width: StegSpacing.xs),
                FilterChip(
                  label: Text(l10n.communityAllReports),
                  selected: !state.openOnly,
                  onSelected: (_) => controller.setOpenOnly(false),
                ),
              ],
            ),
          ),
          Expanded(
            child: !state.initialized
                ? const Center(child: StegLoading())
                : state.error != null && state.reports.isEmpty
                    ? Center(
                        child: Padding(
                          padding: StegSpacing.screenPadding,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  context
                                      .userError(state.error!)
                                      .message,
                                  textAlign: TextAlign.center),
                              const SizedBox(
                                  height: StegSpacing.sm),
                              StegButton(
                                  label: l10n.retry,
                                  onPressed: controller.refresh),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: controller.refresh,
                        child: state.reports.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding:
                                    StegSpacing.screenPadding,
                                children: [
                                  const SizedBox(height: 80),
                                  StegEmptyView(
                                    title:
                                        l10n.communityNoReports,
                                    icon: Icons.flag_outlined,
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(
                                        StegSpacing.sm,
                                        StegSpacing.sm,
                                        StegSpacing.sm,
                                        StegSpacing.lg),
                                itemCount: state.reports.length,
                                itemBuilder: (ctx, i) =>
                                    Padding(
                                  padding:
                                      const EdgeInsets.only(
                                          bottom:
                                              StegSpacing.xs),
                                  child: _ReportCard(
                                    report: state.reports[i],
                                    role: role,
                                  ),
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report, required this.role});

  final CommunityReport report;
  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(communityReportsProvider.notifier);
    final isPost = report.targetType == 'POST';
    final targetId =
        isPost ? report.targetPostId : report.targetCommentId;

    return Card(
      child: Padding(
        padding: StegSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                    report.status == CommunityReportStatus.open
                        ? Icons.flag_outlined
                        : Icons.flag,
                    size: 18),
                const SizedBox(width: StegSpacing.xs),
                Expanded(
                  child: Text(
                    isPost
                        ? l10n.communityPublish
                        : l10n.communityComments,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  report.status == CommunityReportStatus.open
                      ? l10n.communityOpenReports
                      : l10n.communityResolve,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (targetId != null && isPost)
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => CommunityPostDetailScreen(
                          postId: targetId)),
                ),
                icon: const Icon(Icons.open_in_new_outlined,
                    size: 16),
                label: Text(l10n.notifOpen),
              ),
            const SizedBox(height: StegSpacing.xs),
            Semantics(
              label: report.reason,
              child: Text(report.reason,
                  maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: StegSpacing.xs),
            Wrap(
              spacing: StegSpacing.xs,
              runSpacing: StegSpacing.xs,
              children: [
                if (report.status ==
                    CommunityReportStatus.open)
                  StegButton(
                    label: l10n.communityResolve,
                    variant: StegButtonVariant.secondary,
                    onPressed: () => showCommunityResolveSheet(
                        context,
                        onSubmit: (resolution) => controller
                            .resolve(report.id,
                                resolution: resolution)),
                  ),
                if (isPost && targetId != null)
                  StegButton(
                    label: l10n.communityRemove,
                    variant: StegButtonVariant.destructive,
                    onPressed: () =>
                        showCommunityRemoveSheet(context,
                            onSubmit: (reason) =>
                                controller.removePostFromQueue(
                                    targetId,
                                    reason: reason)),
                  )
                else if (!isPost && targetId != null)
                  StegButton(
                    label: l10n.communityRemove,
                    variant: StegButtonVariant.destructive,
                    onPressed: () =>
                        showCommunityRemoveSheet(context,
                            onSubmit: (reason) =>
                                controller.removeCommentFromQueue(
                                    targetId,
                                    reason: reason)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCommunityResolveSheet(
  BuildContext context, {
  required Future<void> Function(String? resolution) onSubmit,
}) {
  final l10n = AppLocalizations.of(context);
  return showStegSheet<void>(
    context,
    title: l10n.communityResolve,
    builder: (_) => _ResolveSheet(onSubmit: onSubmit),
  );
}

class _ResolveSheet extends ConsumerStatefulWidget {
  const _ResolveSheet({required this.onSubmit});

  final Future<void> Function(String? resolution) onSubmit;

  @override
  ConsumerState<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends ConsumerState<_ResolveSheet> {
  final _resolution = TextEditingController();
  String? _serverError;
  bool _sending = false;

  @override
  void dispose() {
    _resolution.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (_sending) return;
    setState(() {
      _sending = true;
      _serverError = null;
    });
    try {
      await widget.onSubmit(_resolution.text.trim().isEmpty
          ? null
          : _resolution.text.trim());
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StegTextField(
          controller: _resolution,
          label: l10n.communityResolution,
        ),
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
          label: l10n.communityResolve,
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
