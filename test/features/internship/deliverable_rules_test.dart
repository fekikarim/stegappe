import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/features/internship/domain/deliverable_file_rules.dart';

void main() {
  group('DeliverableFileRules (mirrors backend STEG_INTERNSHIP_REPORT)', () {
    test('accepts PDF within 25 MB', () {
      expect(
          DeliverableFileRules.check('rapport.pdf', 1024), isNull);
      expect(
          DeliverableFileRules.check('RAPPORT.PDF', 25 * 1024 * 1024),
          isNull);
    });

    test('rejects non-PDF (backend Tika would refuse)', () {
      expect(DeliverableFileRules.check('demo.jpg', 1024),
          FileRejection.wrongType);
      expect(DeliverableFileRules.check('demo.png', 1024),
          FileRejection.wrongType);
      expect(DeliverableFileRules.check('notes.txt', 100),
          FileRejection.wrongType);
      expect(
          DeliverableFileRules.check('noextension', 100),
          FileRejection.wrongType);
    });

    test('rejects oversize and empty files', () {
      expect(
          DeliverableFileRules.check(
              'big.pdf', 25 * 1024 * 1024 + 1),
          FileRejection.tooLarge);
      expect(
          DeliverableFileRules.check('empty.pdf', 0),
          FileRejection.empty);
    });

    test('formatBytes is human-readable', () {
      expect(DeliverableFileRules.formatBytes(512), '512 B');
      expect(DeliverableFileRules.formatBytes(2048), '2.0 KB');
      expect(DeliverableFileRules.formatBytes(25 * 1024 * 1024),
          '25.0 MB');
    });
  });
}
