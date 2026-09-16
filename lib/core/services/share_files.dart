import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes bytes to the app temp dir under [fileName] and opens the
/// platform share sheet (the user decides where the file goes).
Future<void> shareBytes(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final safe = fileName.isEmpty ? 'file.bin' : fileName;
  final file = File('${dir.path}/$safe');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      fileNameOverrides: [safe],
    ),
  );
}
