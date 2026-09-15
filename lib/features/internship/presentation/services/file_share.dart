import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

/// Shares in-memory bytes under [fileName] via a temp file.
Future<void> shareBytes(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final safe = fileName.isEmpty ? 'deliverable.pdf' : fileName;
  final file = File('${dir.path}/$safe');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      fileNameOverrides: [safe],
    ),
  );
}
