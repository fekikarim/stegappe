import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/l10n/settings_providers.dart';
import 'core/theme/steg_theme.dart';
import 'features/shell/presentation/auth_gate.dart';

/// Root widget: theme mode, locale, RTL delegation, reduced-motion aware.
class StegApp extends ConsumerWidget {
  const StegApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider.notifier).materialMode;
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'STEG',
      debugShowCheckedModeBanner: false,
      theme: StegTheme.light(),
      darkTheme: StegTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: StegLocales.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (device, supported) {
        if (locale != null) return locale;
        if (device != null &&
            supported.any((s) => s.languageCode == device.languageCode)) {
          return Locale(device.languageCode);
        }
        return StegLocales.french;
      },
      // Text scaling is honored (no clamping); layouts avoid fixed heights.
      // Reduced motion: disableAnimations is read by animated widgets.
      home: const AuthGate(),
    );
  }
}
