import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/owner_data_backup.dart';

void main() {
  group('OwnerDataBackup', () {
    test('serializes version, timestamp, owner, and every dataset', () {
      final backup = OwnerDataBackup(
        ownerId: 'owner-1',
        generatedAt: DateTime.utc(2026, 10, 3, 4, 5, 6),
        datasets: {
          'properties': [
            {
              'id': 'property-1',
              'tenant_name': 'Taylor Tenant',
              'monthly_rent': 1250,
            },
          ],
          'property_documents': [
            {
              'id': 'document-1',
              'property_id': 'property-1',
              'original_name': 'lease.pdf',
              'content_type': 'application/pdf',
              'file_size': 2048,
              'storage_path': 'property-1/document-1.pdf',
            },
          ],
          'payments': [
            {'property_id': 'property-1', 'amount': 1250},
          ],
          'profiles': [
            {'id': 'owner-1', 'full_name': 'Property Owner', 'phone': '12345'},
          ],
        },
      );

      final decoded = jsonDecode(backup.toJsonString()) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;

      expect(decoded['format'], OwnerDataBackup.formatName);
      expect(decoded['schemaVersion'], OwnerDataBackup.currentSchemaVersion);
      expect(decoded['generatedAt'], '2026-10-03T04:05:06.000Z');
      expect(decoded['ownerId'], 'owner-1');
      expect(data.keys, containsAll(OwnerDataBackup.datasetNames));
      expect(data['properties'], [
        {
          'id': 'property-1',
          'tenant_name': 'Taylor Tenant',
          'monthly_rent': 1250,
        },
      ]);
      expect(data['payments'], [
        {'property_id': 'property-1', 'amount': 1250},
      ]);
      expect(data['property_documents'], [
        {
          'id': 'document-1',
          'property_id': 'property-1',
          'original_name': 'lease.pdf',
          'content_type': 'application/pdf',
          'file_size': 2048,
          'storage_path': 'property-1/document-1.pdf',
        },
      ]);
      expect(data['profiles'], [
        {'id': 'owner-1', 'full_name': 'Property Owner', 'phone': '12345'},
      ]);
      for (final datasetName in OwnerDataBackup.datasetNames.where(
        (name) =>
            !{'properties', 'property_documents', 'payments', 'profiles'}
                .contains(name),
      )) {
        expect(data[datasetName], isEmpty);
      }
    });

    test('normalizes generated timestamp to UTC', () {
      final backup = OwnerDataBackup(
        ownerId: 'owner-1',
        generatedAt: DateTime.parse('2026-10-03T07:05:00+03:00'),
        datasets: const {},
      );

      final decoded = jsonDecode(backup.toJsonString()) as Map<String, dynamic>;
      expect(decoded['generatedAt'], '2026-10-03T04:05:00.000Z');
    });
  });
}
