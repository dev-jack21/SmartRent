import 'package:supabase_flutter/supabase_flutter.dart';

class VendorRecord {
  final String id;
  final String name;
  final String category; // 'Plumber', 'Electrician', 'Locksmith', 'Painter', 'HVAC'
  final String phone;
  final String email;
  final String notes;

  const VendorRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.phone,
    this.email = '',
    this.notes = '',
  });

  factory VendorRecord.fromMap(Map<String, dynamic> map) {
    return VendorRecord(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Contractor',
      category: map['category']?.toString() ?? 'General Maintenance',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'phone': phone,
      'email': email,
      'notes': notes,
    };
  }
}

class VendorDirectoryService {
  final SupabaseClient _supabase;

  VendorDirectoryService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final VendorDirectoryService instance = VendorDirectoryService();

  Future<List<VendorRecord>> loadVendors() async {
    try {
      final response = await _supabase
          .from('vendor_directory')
          .select()
          .order('name');

      return (response as List<dynamic>)
          .map((row) => VendorRecord.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return _defaultVendors();
    }
  }

  List<VendorRecord> _defaultVendors() {
    return [
      const VendorRecord(
        id: '1',
        name: 'John Plumbers & Drainage',
        category: 'Plumber',
        phone: '0712345678',
        notes: '24/7 Emergency Pipe & Leak Repairs',
      ),
      const VendorRecord(
        id: '2',
        name: 'Apex Electrical Solutions',
        category: 'Electrician',
        phone: '0722334455',
        notes: 'Wiring, Circuit Breakers & Generator Fixes',
      ),
      const VendorRecord(
        id: '3',
        name: 'Express Locksmiths',
        category: 'Locksmith',
        phone: '0733445566',
        notes: 'Door Locks & Key Replacements',
      ),
    ];
  }

  Future<bool> saveVendor(VendorRecord vendor) async {
    try {
      final user = _supabase.auth.currentUser;
      final payload = vendor.toMap();
      if (user != null) payload['user_id'] = user.id;

      await _supabase.from('vendor_directory').upsert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
