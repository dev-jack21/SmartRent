import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityMessage {
  final String id;
  final String propertyId;
  final String senderId;
  final String senderName;
  final String recipientId; // 'group' or target tenant email/id
  final String message;
  final DateTime createdAt;

  const CommunityMessage({
    required this.id,
    required this.propertyId,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.message,
    required this.createdAt,
  });

  factory CommunityMessage.fromMap(Map<String, dynamic> map) {
    return CommunityMessage(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      senderName: map['sender_name']?.toString() ?? 'Neighbor',
      recipientId: map['recipient_id']?.toString() ?? 'group',
      message: map['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'sender_id': senderId,
      'sender_name': senderName,
      'recipient_id': recipientId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class CommunityChatService {
  final SupabaseClient _supabase;

  CommunityChatService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final CommunityChatService instance = CommunityChatService();

  final Map<String, List<CommunityMessage>> _localStore = {};

  /// Stream group chat messages for a building property
  Stream<List<CommunityMessage>> getGroupMessagesStream(String propertyId) {
    try {
      return _supabase
          .from('community_messages')
          .stream(primaryKey: ['id'])
          .eq('property_id', propertyId)
          .eq('recipient_id', 'group')
          .order('created_at', ascending: true)
          .map((data) => data.map((map) => CommunityMessage.fromMap(map)).toList())
          .handleError((_) => _localStore[propertyId] ?? []);
    } catch (_) {
      return Stream.value(_localStore[propertyId] ?? []);
    }
  }

  /// Stream 1-on-1 messages between two tenants
  Stream<List<CommunityMessage>> getDirectMessagesStream({
    required String propertyId,
    required String myId,
    required String peerId,
  }) {
    try {
      return _supabase
          .from('community_messages')
          .stream(primaryKey: ['id'])
          .eq('property_id', propertyId)
          .order('created_at', ascending: true)
          .map((data) {
            final all = data.map((map) => CommunityMessage.fromMap(map)).toList();
            return all.where((m) {
              return (m.senderId == myId && m.recipientId == peerId) ||
                  (m.senderId == peerId && m.recipientId == myId);
            }).toList();
          })
          .handleError((_) => []);
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Send message (Group or 1-on-1)
  Future<CommunityMessage> sendMessage({
    required String propertyId,
    required String recipientId, // 'group' or peer email/id
    required String message,
  }) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'tenant_user';
    final userName = user?.userMetadata?['full_name']?.toString() ??
        user?.email ??
        'Tenant';

    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final newMsg = CommunityMessage(
      id: msgId,
      propertyId: propertyId,
      senderId: userId,
      senderName: userName,
      recipientId: recipientId,
      message: message.trim(),
      createdAt: DateTime.now(),
    );

    final payload = {
      'property_id': propertyId,
      'sender_id': userId,
      'sender_name': userName,
      'recipient_id': recipientId,
      'message': message.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final response = await _supabase
          .from('community_messages')
          .insert(payload)
          .select()
          .single();

      return CommunityMessage.fromMap(response);
    } catch (e) {
      // Local fallback
      _localStore.putIfAbsent(propertyId, () => []).add(newMsg);
      return newMsg;
    }
  }
}
