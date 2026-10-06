import 'package:supabase_flutter/supabase_flutter.dart';

class KeyRecord {
  final String id;
  final String propertyId;
  final String keyTag; // e.g. 'Unit 3B Main Key'
  final String status; // 'In Custody', 'Checked Out'
  final String checkedOutTo; // e.g. 'Plumber John'
  final DateTime? checkedOutAt;
  final String notes;

  const KeyRecord({
    required this.id,
    required this.propertyId,
    required this.keyTag,
    required this.status,
    this.checkedOutTo = '',
    this.checkedOutAt,
    this.notes = '',
  });

  factory KeyRecord.fromMap(Map<String, dynamic> map) {
    return KeyRecord(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      keyTag: map['key_tag']?.toString() ?? 'Key Tag',
      status: map['status']?.toString() ?? 'In Custody',
      checkedOutTo: map['checked_out_to']?.toString() ?? '',
      checkedOutAt: DateTime.tryParse(map['checked_out_at']?.toString() ?? ''),
      notes: map['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'key_tag': keyTag,
      'status': status,
      'checked_out_to': checkedOutTo,
      'checked_out_at': checkedOutAt?.toIso8601String(),
      'notes': notes,
    };
  }
}

class KeyManagementService {
  final SupabaseClient _supabase;

  KeyManagementService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final KeyManagementService instance = KeyManagementService();

  Future<List<KeyRecord>> loadKeys(String propertyId) async {
    try {
      final response = await _supabase
          .from('key_inventory')
          .select()
          .eq('property_id', propertyId)
          .order('key_tag');

      return (response as List<dynamic>)
          .map((row) => KeyRecord.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveKey(KeyRecord key) async {
    try {
      final user = _supabase.auth.currentUser;
      final payload = key.toMap();
      if (user != null) payload['user_id'] = user.id;

      await _supabase.from('key_inventory').upsert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
