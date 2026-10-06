import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/property_document_rules.dart';

void main() {
  test('allows supported document and image file types', () {
    for (final name in [
      'lease.pdf',
      'signed-lease.DOC',
      'inspection.docx',
      'front.jpg',
      'front.jpeg',
      'condition.png',
    ]) {
      expect(
        PropertyDocumentRules.validationError(
          fileName: name,
          fileSizeBytes: 1024,
        ),
        isNull,
        reason: name,
      );
    }
  });

  test('rejects unsupported types, empty files, and files over the limit', () {
    expect(
      PropertyDocumentRules.validationError(
        fileName: 'script.exe',
        fileSizeBytes: 1024,
      ),
      contains('PDF, Word'),
    );
    expect(
      PropertyDocumentRules.validationError(
        fileName: 'lease.pdf',
        fileSizeBytes: 0,
      ),
      contains('empty'),
    );
    expect(
      PropertyDocumentRules.validationError(
        fileName: 'lease.pdf',
        fileSizeBytes: PropertyDocumentRules.maxFileSizeBytes + 1,
      ),
      contains('20 MB'),
    );
  });

  test('formats sizes and extracts extensions without case sensitivity', () {
    expect(PropertyDocumentRules.extensionOf('Lease.PDF'), 'pdf');
    expect(PropertyDocumentRules.extensionOf('no-extension'), '');
    expect(PropertyDocumentRules.displaySize(1024), '1 KB');
    expect(PropertyDocumentRules.displaySize(2 * 1024 * 1024), '2.0 MB');
  });
}
