import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/steg_states.dart';

/// Generic placeholder tab for D0 shells. Real feature screens land in
/// D1+. Each tab demonstrates loading/error/empty reuse + semantics.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      label: title,
      child: StegEmptyView(
        title: title,
        hint: l10n.comingSoon,
        icon: icon,
      ),
    );
  }
}
