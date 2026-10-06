import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // 'payment', 'chat', 'maintenance', 'announcement', 'reminder'
  final DateTime createdAt;
  bool isRead;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotificationItem.fromMap(Map<String, dynamic> map) {
    return AppNotificationItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Notification',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'general',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      isRead: map['is_read'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }
}

class AppNotificationHubService {
  final SupabaseClient _supabase;

  AppNotificationHubService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final AppNotificationHubService instance = AppNotificationHubService();

  Future<List<AppNotificationItem>> loadNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return _defaultNotifications();

      final response = await _supabase
          .from('app_notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((row) => AppNotificationItem.fromMap(Map<String, dynamic>.from(row)))
          .toList();

      if (list.isEmpty) return _defaultNotifications();
      return list;
    } catch (_) {
      return _defaultNotifications();
    }
  }

  List<AppNotificationItem> _defaultNotifications() {
    return [
      AppNotificationItem(
        id: '1',
        title: 'Rent Reminder Active',
        body: 'Welcome to Rent Reminder! Automated rent notifications & portal tracking are active.',
        type: 'reminder',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      AppNotificationItem(
        id: '2',
        title: 'Digital Payments Enabled',
        body: 'M-Pesa STK Push and PayPal checkout are ready for rent collection.',
        type: 'payment',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }

  Future<bool> markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return true;

      await _supabase
          .from('app_notifications')
          .update({'is_read': true})
          .eq('user_id', user.id);
      return true;
    } catch (_) {
      return false;
    }
  }
}
