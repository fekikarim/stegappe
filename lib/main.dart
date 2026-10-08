import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/l10n/settings_providers.dart';
import 'core/storage/prefs_store.dart';

/// Crash-free boundaries (D7 gate):
/// - framework errors show a branded fallback instead of a red/blank
///   screen in release builds (debug keeps the red screen);
/// - async zone errors are logged, never silently swallowed.
/// No crash reporting SDK is wired (no provider credentials) — errors go
/// to the platform log via debugPrint in debug and are dropped in
/// release except for the fallback UI.
Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Production-critical: refuse to run an unconfigured release bundle.
      // In debug mode, permit startup with local dev defaults so developers
      // and simulators can launch the app smoothly without crashing.
      if (kReleaseMode) {
        AppConfig.ensureConfigured();
      } else if (!AppConfig.isBackendConfigured) {
        debugPrint(
          'Notice: API_BASE_URL is not set via --dart-define. '
          'Defaulting to local dev host in debug mode.',
        );
      }
      FlutterError.onError = (details) {
        if (kDebugMode) {
          FlutterError.presentError(details);
        } else {
          debugPrint('FlutterError: ${details.exception}');
        }
      };
      ErrorWidget.builder = (details) => kDebugMode
          ? ErrorWidget(details.exception)
          : const _CrashFallback();
      final prefs = await PrefsStore.load();
      runApp(
        ProviderScope(
          overrides: [
            prefsStoreProvider.overrideWithValue(prefs)
          ],
          child: const StegApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Zone error: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stack);
      }
    },
  );
}

/// Release-mode crash fallback: branded with STEG gradient, localized-agnostic
/// (l10n may itself be broken), trilingual message.
class _CrashFallback extends StatelessWidget {
  const _CrashFallback();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF042843),
                Color(0xFF073858),
                Color(0xFF0B61A0),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 64,
                      width: 260,
                      child: Image.asset(
                        'assets/logo-steg-1200x327.png',
                        fit: BoxFit.contain,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, _, _) => const Text(
                          'STEG',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white54,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Une erreur inattendue est survenue.\n'
                      'An unexpected error occurred.\n'
                      'حدث خطأ غير متوقع.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
