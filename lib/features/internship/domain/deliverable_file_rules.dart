/// Backend-confirmed deliverable file rules (display + pre-check ONLY).
/// Source: `DocumentValidationService` validates deliverable bytes as
/// `STEG_INTERNSHIP_REPORT` (Tika-verified server-side). The backend is
/// authoritative; these constants only let the UI show exact limits and
/// fail fast before upload.
abstract final class DeliverableFileRules {
  static const int maxBytes = 25 * 1024 * 1024;
  static const String maxLabel = '25 MB';
  static const Set<String> allowedExtensions = {'pdf'};
  static const Set<String> allowedMimeTypes = {'application/pdf'};

  /// Client-side pre-check (UX hint). Returns null when acceptable.
  static FileRejection? check(String fileName, int sizeBytes) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    if (!allowedExtensions.contains(ext)) {
      return FileRejection.wrongType;
    }
    if (sizeBytes > maxBytes) {
      return FileRejection.tooLarge;
    }
    if (sizeBytes <= 0) {
      return FileRejection.empty;
    }
    return null;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum FileRejection { wrongType, tooLarge, empty }
