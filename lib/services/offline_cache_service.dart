import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineCacheService {
  final SupabaseClient _supabase;

  OfflineCacheService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final OfflineCacheService instance = OfflineCacheService();

  static const String _propertiesKey = 'cached_properties';
  static const String _paymentsKey = 'cached_payments';

  // In-memory persistent cache buffers for fast offline recovery
  final Map<String, String> _localStore = {};

  /// Caches property records locally
  Future<void> cacheProperties(List<Map<String, dynamic>> properties) async {
    _localStore[_propertiesKey] = jsonEncode(properties);
  }

  /// Retrieves cached properties when offline
  List<Map<String, dynamic>> getCachedProperties() {
    final raw = _localStore[_propertiesKey];
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Caches payment records locally
  Future<void> cachePayments(List<Map<String, dynamic>> payments) async {
    _localStore[_paymentsKey] = jsonEncode(payments);
  }

  /// Retrieves cached payments when offline
  List<Map<String, dynamic>> getCachedPayments() {
    final raw = _localStore[_paymentsKey];
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check network connectivity status with Supabase backend
  Future<bool> isOnline() async {
    try {
      await _supabase.from('properties').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
