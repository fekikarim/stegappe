import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/share_files.dart';
import '../providers/workspace_providers.dart';

/// Platform share entry point, injectable for tests (path_provider and
/// share_plus hang without a platform — widget tests override this).
typedef ShareFn = Future<void> Function(Uint8List bytes, String fileName);

final shareFnProvider = Provider<ShareFn>((ref) => shareBytes);

/// Secure download helper: bytes come ONLY from the authenticated backend
/// endpoint (Bearer enforced, no public URLs). The platform share step is
/// resolved through [shareFnProvider].
Future<void> downloadAndShare(
  WidgetRef ref, {
  required String deliverableId,
  int? version,
  required String fileName,
}) async {
  final repo = ref.read(internshipRepositoryProvider);
  final bytes = await repo.downloadDeliverable(deliverableId,
      version: version);
  await ref.read(shareFnProvider)(bytes, fileName);
}
