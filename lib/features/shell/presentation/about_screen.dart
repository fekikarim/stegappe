import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/steg_spacing.dart';
import '../../../core/widgets/steg_card.dart';

/// About screen (T14 SH-SET-04): brand, real app version/build, licences,
/// support pointer and privacy note. Only safe public information — no
/// secret, token, internal URL, credential or personal data leaves this
/// screen (BR-59).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: StegSpacing.screenPadding,
        children: [
          StegCard(
            title: l10n.aboutTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/logo-steg-1200x327.png',
                  height: 48,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
                const SizedBox(height: StegSpacing.sm),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (ctx, snap) => Text(
                    snap.hasData
                        ? l10n.aboutVersion(
                            '${snap.data!.version}+${snap.data!.buildNumber}')
                        : l10n.aboutVersion('…'),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: StegSpacing.md),
          StegCard(
            title: l10n.aboutLicenses,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.aboutLicenses),
              trailing: const Icon(Icons.arrow_forward_outlined),
              onTap: () => showLicensePage(context: context),
            ),
          ),
          const SizedBox(height: StegSpacing.md),
          StegCard(
            title: l10n.aboutSupport,
            child: Text(l10n.aboutSupportBody,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: StegSpacing.md),
          StegCard(
            title: l10n.aboutPrivacy,
            child: Text(l10n.aboutPrivacyBody,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
