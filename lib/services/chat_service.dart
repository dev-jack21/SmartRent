import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String id;
  final String propertyId;
  final String senderId;
  final String senderEmail;
  final String senderRole; // 'owner' or 'tenant'
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.propertyId,
    required this.senderId,
    required this.senderEmail,
    required this.senderRole,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      propertyId: map['property_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      senderEmail: map['sender_email']?.toString() ?? '',
      senderRole: map['sender_role']?.toString() ?? 'unknown',
      message: map['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      isRead: map['is_read'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'property_id': propertyId,
      'sender_id': senderId,
      'sender_email': senderEmail,
      'sender_role': senderRole,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }
}

class ChatService {
  final SupabaseClient _supabase;

  ChatService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final ChatService instance = ChatService();

  final Map<String, List<ChatMessage>> _localStore = {};
  final StreamController<Map<String, List<ChatMessage>>> _localStreamController =
      StreamController<Map<String, List<ChatMessage>>>.broadcast();

  /// Stream real-time messages for a given property ID
  Stream<List<ChatMessage>> getMessagesStream(String propertyId) {
    try {
      return _supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('property_id', propertyId)
          .order('created_at', ascending: true)
          .map((data) {
            final remote = data.map((map) => ChatMessage.fromMap(map)).toList();
            if (remote.isNotEmpty) {
              _localStore[propertyId]?.clear();
              return remote;
            }
            return _localStore[propertyId] ?? [];
          })
          .handleError((error) {
            return _localStore[propertyId] ?? [];
          });
    } catch (_) {
      return Stream.value(_localStore[propertyId] ?? []);
    }
  }

  /// Send a chat message
  Future<ChatMessage> sendMessage({
    required String propertyId,
    required String message,
    required String senderRole,
  }) async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id ?? 'local_user';
    final userEmail = user?.email ?? 'user@rentreminder.com';

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final newMsg = ChatMessage(
      id: messageId,
      propertyId: propertyId,
      senderId: userId,
      senderEmail: userEmail,
      senderRole: senderRole,
      message: message.trim(),
      createdAt: DateTime.now(),
      isRead: false,
    );

    final payload = {
      'property_id': propertyId,
      'sender_id': userId,
      'sender_email': userEmail,
      'sender_role': senderRole,
      'message': message.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_read': false,
    };

    try {
      final response = await _supabase
          .from('chat_messages')
          .insert(payload)
          .select()
          .single();

      return ChatMessage.fromMap(response);
    } catch (e) {
      _localStore.putIfAbsent(propertyId, () => []).add(newMsg);
      _localStreamController.add(_localStore);
      return newMsg;
    }
  }

  /// Edit a message
  Future<bool> editMessage({
    required String messageId,
    required String propertyId,
    required String newText,
  }) async {
    try {
      await _supabase
          .from('chat_messages')
          .update({'message': newText.trim()})
          .eq('id', messageId);
      return true;
    } catch (_) {
      final list = _localStore[propertyId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final old = list[idx];
          list[idx] = ChatMessage(
            id: old.id,
            propertyId: old.propertyId,
            senderId: old.senderId,
            senderEmail: old.senderEmail,
            senderRole: old.senderRole,
            message: newText.trim(),
            createdAt: old.createdAt,
            isRead: old.isRead,
          );
        }
      }
      return true;
    }
  }

  /// Delete a message
  Future<bool> deleteMessage({
    required String messageId,
    required String propertyId,
  }) async {
    try {
      await _supabase
          .from('chat_messages')
          .delete()
          .eq('id', messageId);
      return true;
    } catch (_) {
      _localStore[propertyId]?.removeWhere((m) => m.id == messageId);
      return true;
    }
  }

  /// Mark messages as read for a property
  Future<void> markAsRead({
    required String propertyId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('property_id', propertyId)
          .neq('sender_id', user.id);
    } catch (_) {}
  }
}
