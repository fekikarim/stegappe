import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/steg_colors.dart';
import '../../../../core/theme/steg_spacing.dart';
import '../../../../core/widgets/steg_fields.dart';
import '../../../../core/widgets/steg_status_chip.dart';
import '../../domain/entities/evaluation.dart';
import '../widgets/status_labels.dart';
import '../screens/intern_detail_screen.dart';

/// Shared supervised-intern row: identity, reference, department,
/// attention badge vs status chip. Tapping opens the intern file.
/// With [onSelectionChanged], the row becomes selectable instead (T14
/// multi-select): a checkbox leads and tapping toggles.
///
/// Modern finish: 16 px radius, hairline border, soft shadow.
class InternCard extends StatelessWidget {
  const InternCard({
    super.key,
    required this.intern,
    this.selected = false,
    this.onSelectionChanged,
  });

  final SupervisedIntern intern;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final selectable = onSelectionChanged != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    // A real Material Card keeps the ListTile ink + the widget contract
    // (callers and tests rely on the Card ancestor).
    return Card(
      elevation: dark ? 0 : 2,
      shadowColor: dark
          ? Colors.black54
          : StegColors.brandPrimary.withValues(alpha: 0.14),
      color: selected
          ? scheme.primary.withValues(alpha: dark ? 0.18 : 0.08)
          : (dark ? StegColors.darkSurface : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StegSpacing.radiusMd),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.5)
              : (dark ? StegColors.darkBorder : StegColors.lightBorder),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: selectable
            ? Semantics(
                button: true,
                label: intern.internName,
                child: Checkbox(
                  value: selected,
                  onChanged: (v) =>
                      onSelectionChanged?.call(v ?? false),
                ),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: StegColors.brandGradient,
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  intern.internName.isEmpty
                      ? '?'
                      : intern.internName[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17),
                ),
              ),
        title: Text(intern.internName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          // T15/RTL: the reference is an LTR run inside a localized sentence.
          '${BidiText.isolate(intern.reference)} • ${intern.departmentName} • '
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
        onTap: selectable
            ? () => onSelectionChanged?.call(!selected)
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InternDetailScreen(
                        internshipId: intern.internshipId),
                  ),
                ),
      ),
    );
  }
}
