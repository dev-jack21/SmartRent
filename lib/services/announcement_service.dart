import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyAnnouncement {
  final String id;
  final String propertyId;
  final String title;
  final String content;
  final String category; // 'General', 'Maintenance', 'Billing', 'Emergency'
  final DateTime createdAt;

  const PropertyAnnouncement({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
  });

  factory PropertyAnnouncement.fromMap(Map<String, dynamic> map) {
    return PropertyAnnouncement(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Notice',
      content: map['content']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'title': title,
      'content': content,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AnnouncementService {
  final SupabaseClient _supabase;

  AnnouncementService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final AnnouncementService instance = AnnouncementService();

  Future<List<PropertyAnnouncement>> loadAnnouncements(String propertyId) async {
    try {
      final response = await _supabase
          .from('property_announcements')
          .select()
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((row) => PropertyAnnouncement.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createAnnouncement(PropertyAnnouncement announcement) async {
    try {
      final user = _supabase.auth.currentUser;
      final payload = announcement.toMap();
      if (user != null) payload['user_id'] = user.id;

      await _supabase.from('property_announcements').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
