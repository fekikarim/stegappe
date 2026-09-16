import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
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

/// Release-mode crash fallback: branded, localized-agnostic (l10n may
/// itself be broken), with a restart affordance via re-run.
class _CrashFallback extends StatelessWidget {
  const _CrashFallback();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'STEG',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Une erreur inattendue est survenue.\n'
                    'An unexpected error occurred.\n'
                    'حدث خطأ غير متوقع.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
