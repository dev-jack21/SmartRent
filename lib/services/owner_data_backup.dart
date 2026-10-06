import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerDataBackup {
  static const int currentSchemaVersion = 3;
  static const String formatName = 'rent_reminder_owner_backup';
  static const List<String> datasetNames = [
    'properties',
    'property_documents',
    'payments',
    'reminders',
    'rent_credit_allocations',
    'maintenance_requests',
    'property_expenses',
    'recurring_expense_rules',
    'profiles',
  ];

  const OwnerDataBackup({
    required this.ownerId,
    required this.generatedAt,
    required this.datasets,
  });

  final String ownerId;
  final DateTime generatedAt;
  final Map<String, List<Map<String, dynamic>>> datasets;

  String toJsonString() {
    final backup = <String, dynamic>{
      'format': formatName,
      'schemaVersion': currentSchemaVersion,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'ownerId': ownerId,
      'data': {
        for (final datasetName in datasetNames)
          datasetName: datasets[datasetName] ?? const [],
      },
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }
}

class OwnerDataBackupException implements Exception {
  const OwnerDataBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OwnerDataBackupService {
  OwnerDataBackupService(this._supabase);

  static const int _pageSize = 500;

  final SupabaseClient _supabase;

  Future<OwnerDataBackup> createBackup({DateTime? generatedAt}) async {
    final owner = _supabase.auth.currentUser;
    if (owner == null) {
      throw const OwnerDataBackupException(
        'You must be signed in to export your owner data.',
      );
    }

    final datasets = <String, List<Map<String, dynamic>>>{};
    for (final datasetName in OwnerDataBackup.datasetNames) {
      datasets[datasetName] = await _loadOwnerRows(datasetName, owner.id);
    }

    final properties = datasets['properties']!;
    if (properties.isNotEmpty &&
        properties.any(
          (property) =>
              !property.containsKey('tenant_name') ||
              !property.containsKey('tenant_email') ||
              !property.containsKey('tenant_phone'),
        )) {
      throw const OwnerDataBackupException(
        'The properties table is missing tenant contact columns. Apply '
        'supabase/migrations/20261003000000_add_tenant_contacts_to_properties.sql '
        'and try again.',
      );
    }

    return OwnerDataBackup(
      ownerId: owner.id,
      generatedAt: generatedAt ?? DateTime.now().toUtc(),
      datasets: datasets,
    );
  }

  Future<List<Map<String, dynamic>>> _loadOwnerRows(
    String table,
    String ownerId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      try {
        final selectedRows = _supabase.from(table).select('*');
        final ownerRows = table == 'profiles'
            ? selectedRows.eq('id', ownerId)
            : selectedRows.eq('user_id', ownerId);
        final orderedRows = table == 'reminders'
            ? ownerRows.order('property_id').order('days_before')
            : ownerRows.order('id');
        final response = await orderedRows.range(
          offset,
          offset + _pageSize - 1,
        );
        final page = List<Map<String, dynamic>>.from(response);
        rows.addAll(page);
        if (page.length < _pageSize) return rows;
        offset += _pageSize;
      } on PostgrestException catch (error) {
        throw OwnerDataBackupException(
          'Could not export "$table" (database code ${error.code ?? 'unknown'}). '
          '${_migrationGuidance(table)} Details: ${error.message}',
        );
      }
    }
  }

  String _migrationGuidance(String table) {
    final migration = switch (table) {
      'rent_credit_allocations' => 'Apply supabase/migrations/20261002001000_create_rent_credit_allocations.sql.',
      'maintenance_requests' => 'Apply supabase/migrations/20261001001000_create_maintenance_requests.sql.',
      'property_expenses' => 'Apply supabase/migrations/20261003001000_create_property_expenses.sql.',
      'recurring_expense_rules' =>
        'Apply both property expense migrations, including '
            'supabase/migrations/20261003002000_add_recurring_property_expenses.sql.',
      'property_documents' =>
        'Apply supabase/migrations/20261003004000_property_document_storage.sql '
            'to create the property document metadata table and private storage bucket.',
      'profiles' =>
        'Confirm the profiles table exists and grants the signed-in owner read access. '
            'Apply supabase/migrations/20261003003000_tenant_portal_read_access.sql '
            'if the current policies do not permit reading your own profile.',
      'reminders' => 'Confirm the existing reminders table is present and grants the signed-in owner read access.',
      'properties' => 'Confirm the properties table is present and grants the signed-in owner read access.',
      'payments' => 'Confirm the payments table is present and grants the signed-in owner read access.',
      _ =>
        'Confirm the table exists and grants the signed-in owner read access.',
    };
    return migration;
  }
}
