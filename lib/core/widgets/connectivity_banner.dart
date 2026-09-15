import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/steg_colors.dart';
import '../theme/steg_spacing.dart';

/// Online/offline banner shown at the top of every authenticated shell.
/// Offline data must be labeled stale — never silently fresh.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reducedMotion =
        MediaQuery.of(context).disableAnimations;
    final banner = Container(
      width: double.infinity,
      color: isOnline ? StegColors.success : StegColors.warning,
      padding: const EdgeInsets.symmetric(
          horizontal: StegSpacing.md, vertical: StegSpacing.xs),
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          // Announced once: exclude duplicate child text semantics.
          excludeSemantics: true,
          label: isOnline ? l10n.online : l10n.offline,
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: StegSpacing.xs),
              Expanded(
                child: Text(
                  isOnline ? l10n.online : l10n.offline,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!isOnline || reducedMotion) return banner;
    // Online state is transient confirmation; offline persists.
    return banner;
  }
}
