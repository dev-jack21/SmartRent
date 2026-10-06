import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class TenantPortalRepository {
  Future<List<Map<String, dynamic>>> loadProperties({
    required String tenantEmail,
  });

  Future<List<Map<String, dynamic>>> loadPayments({
    required List<String> propertyIds,
  });

  Future<List<Map<String, dynamic>>> loadCreditAllocations({
    required List<String> propertyIds,
  });
}

class SupabaseTenantPortalRepository implements TenantPortalRepository {
  final SupabaseClient _client;

  SupabaseTenantPortalRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> loadProperties({
    required String tenantEmail,
  }) async {
    final response = await _client
        .from('properties')
        .select(
          'id, name, address, unit_number, monthly_rent, currency, due_day, lease_start_date, lease_end_date, created_at',
        )
        .ilike('tenant_email', tenantEmail.trim())
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> loadPayments({
    required List<String> propertyIds,
  }) async {
    if (propertyIds.isEmpty) return const [];

    final response = await _client
        .from('payments')
        .select('id, property_id, amount, status, payment_date, rent_month, notes')
        .inFilter('property_id', propertyIds)
        .order('payment_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> loadCreditAllocations({
    required List<String> propertyIds,
  }) async {
    if (propertyIds.isEmpty) return const [];

    final response = await _client
        .from('rent_credit_allocations')
        .select('property_id, source_month, target_month, amount')
        .inFilter('property_id', propertyIds)
        .order('target_month', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
