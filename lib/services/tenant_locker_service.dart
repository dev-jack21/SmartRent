import 'package:supabase_flutter/supabase_flutter.dart';

class TenantLockerData {
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String idTypeAndNumber;
  final String insuranceDetails;
  final String parkingSpot;
  final String vehiclePlate;
  final String notes;

  const TenantLockerData({
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.idTypeAndNumber = '',
    this.insuranceDetails = '',
    this.parkingSpot = '',
    this.vehiclePlate = '',
    this.notes = '',
  });

  factory TenantLockerData.fromMap(Map<String, dynamic> map) {
    return TenantLockerData(
      emergencyContactName: map['emergency_name']?.toString() ?? '',
      emergencyContactPhone: map['emergency_phone']?.toString() ?? '',
      idTypeAndNumber: map['id_details']?.toString() ?? '',
      insuranceDetails: map['insurance_details']?.toString() ?? '',
      parkingSpot: map['parking_spot']?.toString() ?? '',
      vehiclePlate: map['vehicle_plate']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emergency_name': emergencyContactName,
      'emergency_phone': emergencyContactPhone,
      'id_details': idTypeAndNumber,
      'insurance_details': insuranceDetails,
      'parking_spot': parkingSpot,
      'vehicle_plate': vehiclePlate,
      'notes': notes,
    };
  }
}

class TenantLockerService {
  final SupabaseClient _supabase;

  TenantLockerService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final TenantLockerService instance = TenantLockerService();

  Future<TenantLockerData> loadLockerData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return const TenantLockerData();

      final response = await _supabase
          .from('tenant_lockers')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return const TenantLockerData();
      return TenantLockerData.fromMap(response);
    } catch (_) {
      return const TenantLockerData();
    }
  }

  Future<bool> saveLockerData(TenantLockerData data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final payload = data.toMap();
      payload['user_id'] = user.id;

      await _supabase.from('tenant_lockers').upsert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
