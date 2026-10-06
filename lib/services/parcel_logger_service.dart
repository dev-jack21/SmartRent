import 'package:supabase_flutter/supabase_flutter.dart';

class ParcelRecord {
  final String id;
  final String propertyId;
  final String tenantName;
  final String courierName; // e.g. 'DHL', 'FedEx', 'Jumia', 'Rider'
  final String trackingOrCode;
  String status; // 'Received at Gate', 'Collected'
  final DateTime receivedAt;
  final DateTime? collectedAt;

  ParcelRecord({
    required this.id,
    required this.propertyId,
    required this.tenantName,
    required this.courierName,
    this.trackingOrCode = '',
    this.status = 'Received at Gate',
    required this.receivedAt,
    this.collectedAt,
  });

  factory ParcelRecord.fromMap(Map<String, dynamic> map) {
    return ParcelRecord(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      tenantName: map['tenant_name']?.toString() ?? 'Tenant',
      courierName: map['courier_name']?.toString() ?? 'Courier',
      trackingOrCode: map['tracking_code']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Received at Gate',
      receivedAt: DateTime.tryParse(map['received_at']?.toString() ?? '') ?? DateTime.now(),
      collectedAt: DateTime.tryParse(map['collected_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'tenant_name': tenantName,
      'courier_name': courierName,
      'tracking_code': trackingOrCode,
      'status': status,
      'received_at': receivedAt.toIso8601String(),
      'collected_at': collectedAt?.toIso8601String(),
    };
  }
}

class ParcelLoggerService {
  final SupabaseClient _supabase;

  ParcelLoggerService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final ParcelLoggerService instance = ParcelLoggerService();

  Future<List<ParcelRecord>> loadParcels(String propertyId) async {
    try {
      final response = await _supabase
          .from('parcel_inventory')
          .select()
          .eq('property_id', propertyId)
          .order('received_at', ascending: false);

      return (response as List<dynamic>)
          .map((row) => ParcelRecord.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveParcel(ParcelRecord parcel) async {
    try {
      final user = _supabase.auth.currentUser;
      final payload = parcel.toMap();
      if (user != null) payload['user_id'] = user.id;

      await _supabase.from('parcel_inventory').upsert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
