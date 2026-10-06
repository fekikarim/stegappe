import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../domain/schedule.dart';
import 'status_labels.dart';

/// T04/D8 shared schedule field (SU-TASK-04): Tunis date + time pickers
/// producing an absolute UTC instant, plus clear-to-immediate.
///
/// Used by the manual bulk sheet (T04) and the AI drafts screen (T05) so
/// both flows share one Tunis conversion and one wording. Null = immediate
/// (create/bulk-add) — the edit sheet keeps its own stamp-now semantics.
class ScheduleField extends StatelessWidget {
  const ScheduleField({
    super.key,
    required this.scheduled,
    required this.onPick,
    required this.onClear,
  });

  /// Absolute UTC instant, or null for immediate.
  final DateTime? scheduled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(scheduled == null
                  ? '${l10n.supScheduleLabel} : ${l10n.supScheduleNone}'
                  : '${l10n.supScheduleLabel} : ${formatDay(tunisWallFromInstant(scheduled!), locale)}'),
            ),
            TextButton(
              onPressed: onPick,
              child: Text(scheduled == null
                  ? l10n.supSchedulePickDate
                  : l10n.supSchedulePickTime),
            ),
            if (scheduled != null)
              TextButton(
                onPressed: onClear,
                child: Text(l10n.supScheduleClear),
              ),
          ],
        ),
        Text(
          l10n.supScheduleOutsideNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Picks a Tunis date + time and returns the absolute UTC instant.
/// Returns null when the user cancels either dialog.
Future<DateTime?> pickTunisMoment(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  final seed = initial ?? now.add(const Duration(days: 1));
  final picked = await showDatePicker(
    context: context,
    initialDate: seed,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 2),
  );
  if (picked == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(seed),
  );
  if (time == null) return null;
  return tunisWallToInstant(picked, time.hour, time.minute);
}
