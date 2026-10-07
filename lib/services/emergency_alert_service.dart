import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyAlertItem {
  final String id;
  final String propertyId;
  final String title; // e.g. 'Fire Alarm', 'Water Pipe Burst', 'Security Alert'
  final String details;
  final String triggeredBy;
  final DateTime triggeredAt;

  const EmergencyAlertItem({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.details,
    required this.triggeredBy,
    required this.triggeredAt,
  });

  factory EmergencyAlertItem.fromMap(Map<String, dynamic> map) {
    return EmergencyAlertItem(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Emergency Alert',
      details: map['details']?.toString() ?? '',
      triggeredBy: map['triggered_by']?.toString() ?? 'Resident',
      triggeredAt: DateTime.tryParse(map['triggered_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'title': title,
      'details': details,
      'triggered_by': triggeredBy,
      'triggered_at': triggeredAt.toIso8601String(),
    };
  }
}

class EmergencyAlertService {
  final SupabaseClient _supabase;

  EmergencyAlertService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final EmergencyAlertService instance = EmergencyAlertService();

  Future<bool> broadcastEmergencyAlert({
    required String propertyId,
    required String title,
    required String details,
  }) async {
    final user = _supabase.auth.currentUser;
    final userName = user?.userMetadata?['full_name']?.toString() ?? user?.email ?? 'Resident';

    final alert = EmergencyAlertItem(
      id: '',
      propertyId: propertyId,
      title: title,
      details: details,
      triggeredBy: userName,
      triggeredAt: DateTime.now(),
    );

    try {
      final payload = alert.toMap();
      if (user != null) payload['user_id'] = user.id;

      await _supabase.from('emergency_alerts').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
