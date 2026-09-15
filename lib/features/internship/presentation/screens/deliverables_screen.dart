import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_states.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/work_items.dart';
import '../providers/workspace_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/status_labels.dart';
import 'deliverable_detail_screen.dart';
import 'deliverable_upload_sheet.dart';

/// Deliverable checklist. No backend "expected deliverables" template
/// exists, so the checklist groups ACTUAL deliverables by state instead
/// of inventing requirements: to-finalize / awaiting validation /
/// validated — with honest counts.
class DeliverablesScreen extends ConsumerWidget {
  const DeliverablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(deliverablesListProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final auth = ref.watch(authControllerProvider);
    final isIntern = auth is AuthAuthenticated &&
        auth.user.mobileRole == UserRole.intern;
    final internshipId =
        ref.watch(myInternshipIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliverablesTitle)),
      floatingActionButton: isIntern && internshipId != null
          ? FloatingActionButton(
              tooltip: l10n.deliverableNew,
              onPressed: () =>
                  DeliverableUploadSheet.showCreate(context,
                      internshipId: internshipId),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(deliverablesListProvider);
          try {
            await ref.read(deliverablesListProvider.future);
          } on Exception {
            // Error UI renders via the AsyncValue.
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: StegSpacing.screenPadding,
              sliver: async.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: StegLoading(),
                ),
                error: (e, _) {
                  if (e is StateError &&
                      e.message == 'no-internship') {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: StegEmptyView(
                        title: l10n.noInternshipTitle,
                        hint: l10n.noInternshipHint,
                        icon: Icons.school_outlined,
                      ),
                    );
                  }
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: StegErrorView(
                      message: e is ApiException
                          ? e.message
                          : e.toString(),
                      onRetry: () =>
                          ref.invalidate(deliverablesListProvider),
                    ),
                  );
                },
                data: (page) {
                  if (page.items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: StegEmptyView(
                        title: l10n.deliverableChecklistEmpty,
                        hint: l10n.deliverablesSubtitle,
                        icon: Icons.upload_file_outlined,
                      ),
                    );
                  }
                  final todo = page.items
                      .where((d) =>
                          d.status == DeliverableStatus.draft ||
                          d.status == DeliverableStatus.rejected)
                      .toList();
                  final pending = page.items
                      .where((d) => d.awaitsSupervisor)
                      .toList();
                  final done = page.items
                      .where((d) =>
                          d.status == DeliverableStatus.validated)
                      .toList();
                  return SliverMainAxisGroup(
                    slivers: [
                      if (!isOnline)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(
                                bottom: StegSpacing.sm),
                            child: StaleNotice(),
                          ),
                        ),
                      _Group(
                          title:
                              '${l10n.deliverableChecklistTodo} (${todo.length})',
                          items: todo),
                      _Group(
                          title:
                              '${l10n.deliverableChecklistPending} (${pending.length})',
                          items: pending),
                      _Group(
                          title:
                              '${l10n.deliverableChecklistDone} (${done.length})',
                          items: done),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items});

  final String title;
  final List<DeliverableSummary> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
                top: StegSpacing.sm, bottom: StegSpacing.xs),
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final d = items[i];
              return Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.upload_file_outlined),
                  title: Text(d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      AppLocalizations.of(ctx)
                          .versionLabel(d.currentVersion)),
                  trailing: StegStatusChip(
                    label: deliverableStatusLabel(
                        d.status,
                        AppLocalizations.of(ctx)),
                    kind: deliverableStatusKind(d.status),
                  ),
                  onTap: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DeliverableDetailScreen(
                              deliverableId: d.id),
                    ),
                  ),
                ),
              );
            },
            childCount: items.length,
          ),
        ),
      ],
    );
  }
}
