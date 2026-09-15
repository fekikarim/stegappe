import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/evaluation.dart';
import '../widgets/status_labels.dart';
import '../screens/intern_detail_screen.dart';

/// Shared supervised-intern row: identity, reference, department,
/// attention badge vs status chip. Tapping opens the intern file.
class InternCard extends StatelessWidget {
  const InternCard({super.key, required this.intern});

  final SupervisedIntern intern;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(intern.internName.isEmpty
              ? '?'
              : intern.internName[0].toUpperCase()),
        ),
        title: Text(intern.internName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${intern.reference} • ${intern.departmentName} • '
          '${formatDay(intern.endDate, locale)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: intern.needsAttention
            ? StegStatusChip(
                label:
                    '${intern.pendingJournal + intern.pendingDeliverables}',
                kind: StegStatusKind.warning,
              )
            : StegStatusChip(
                label: internshipStatusLabel(
                    intern.status, l10n),
                kind: internshipStatusKind(intern.status),
              ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InternDetailScreen(
                internshipId: intern.internshipId),
          ),
        ),
      ),
    );
  }
}
