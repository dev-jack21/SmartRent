import 'package:supabase_flutter/supabase_flutter.dart';

class SanitationTask {
  final String id;
  final String title; // e.g. 'Stairwell Cleaning', 'Trash Collection'
  final String frequency; // 'Daily', 'Weekly', 'Bi-Weekly', 'Monthly'
  final String assignedTo;
  bool isCompleted;
  final DateTime? lastCompletedAt;

  SanitationTask({
    required this.id,
    required this.title,
    required this.frequency,
    this.assignedTo = 'Caretaker',
    this.isCompleted = false,
    this.lastCompletedAt,
  });

  factory SanitationTask.fromMap(Map<String, dynamic> map) {
    return SanitationTask(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Sanitation Task',
      frequency: map['frequency']?.toString() ?? 'Weekly',
      assignedTo: map['assigned_to']?.toString() ?? 'Caretaker',
      isCompleted: map['is_completed'] == true,
      lastCompletedAt: DateTime.tryParse(map['last_completed_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'frequency': frequency,
      'assigned_to': assignedTo,
      'is_completed': isCompleted,
      'last_completed_at': lastCompletedAt?.toIso8601String(),
    };
  }
}

class SanitationScheduleService {
  final SupabaseClient _supabase;

  SanitationScheduleService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final SanitationScheduleService instance = SanitationScheduleService();

  Future<List<SanitationTask>> loadTasks() async {
    try {
      final response = await _supabase
          .from('sanitation_tasks')
          .select()
          .order('title');

      return (response as List<dynamic>)
          .map((row) => SanitationTask.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return _defaultTasks();
    }
  }

  List<SanitationTask> _defaultTasks() {
    return [
      SanitationTask(id: '1', title: 'Main Stairwell & Hallways Sweeping', frequency: 'Daily'),
      SanitationTask(id: '2', title: 'Garbage Chute & Trash Bin Emptying', frequency: 'Bi-Weekly'),
      SanitationTask(id: '3', title: 'Water Tank Flushing & Chemical Dosing', frequency: 'Monthly'),
      SanitationTask(id: '4', title: 'Pest Control & Fumigation Routine', frequency: 'Monthly'),
    ];
  }

  Future<bool> saveTask(SanitationTask task) async {
    try {
      final user = _supabase.auth.currentUser;
      final payload = task.toMap();
      if (user != null) payload['user_id'] = user.id;

      await _supabase.from('sanitation_tasks').upsert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
