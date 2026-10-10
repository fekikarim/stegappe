import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/steg_spacing.dart';

/// Online/offline banner shown at the top of every authenticated shell.
/// Offline data must be labeled stale — never silently fresh.
///
/// Modern finish: gradient pill strip with icon medallion.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final banner = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? const [Color(0xFF1B7A3D), Color(0xFF2FA35C)]
              : const [Color(0xFF9A6200), Color(0xFFD99A2B)],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: StegSpacing.md, vertical: StegSpacing.xs + 2),
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          excludeSemantics: true,
          label: isOnline ? l10n.online : l10n.offline,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: StegSpacing.xs),
              Expanded(
                child: Text(
                  isOnline ? l10n.online : l10n.offline,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2),
                ),
              ),
              if (!isOnline)
                const Icon(Icons.cloud_off_outlined,
                    size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
    if (!isOnline || reducedMotion) return banner;
    return banner;
  }
}

/// Compact offline dot used inside modern headers.
class StegOfflineDot extends StatelessWidget {
  const StegOfflineDot({super.key, required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isOnline
            ? const Color(0xFF23A55A)
            : const Color(0xFF80848E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
      ),
    );
  }
}
