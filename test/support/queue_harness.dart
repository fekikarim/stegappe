import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegappe/core/offline/pending_write_store.dart';
import 'package:stegappe/core/offline/pending_writes.dart';
import 'package:stegappe/core/realtime/realtime_sync.dart';
import 'package:stegappe/core/storage/prefs_store.dart';
import 'package:stegappe/features/internship/presentation/providers/workspace_providers.dart';
import 'package:stegappe/features/messaging/presentation/providers/messaging_providers.dart';

/// T06 test seam: a real [PendingWritesController] backed by isolated mock
/// preferences. The messaging repository falls back to the default graph
/// (safe: constructed but never called unless a test flushes messages).
Future<Override> queueOverride() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return pendingWritesProvider.overrideWith((ref) =>
      PendingWritesController(
        ref,
        PendingWriteStore(PrefsStore(prefs)),
        ref.watch(internshipRepositoryProvider),
        ref.watch(messagingRepositoryProvider),
        ref.watch(realtimeSyncProvider),
      ));
}
