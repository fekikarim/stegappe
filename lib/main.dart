import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/l10n/settings_providers.dart';
import 'core/storage/prefs_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await PrefsStore.load();
  runApp(
    ProviderScope(
      overrides: [prefsStoreProvider.overrideWithValue(prefs)],
      child: const StegApp(),
    ),
  );
}
