import 'package:flutter/material.dart';
import '../../services/sanitation_schedule_service.dart';

class SanitationScheduleScreen extends StatefulWidget {
  const SanitationScheduleScreen({super.key});

  @override
  State<SanitationScheduleScreen> createState() =>
      _SanitationScheduleScreenState();
}

class _SanitationScheduleScreenState
    extends State<SanitationScheduleScreen> {
  final SanitationScheduleService _service = SanitationScheduleService.instance;

  final TextEditingController _taskController = TextEditingController();
  String _frequency = 'Weekly';
  bool _isLoading = true;
  List<SanitationTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final list = await _service.loadTasks();
    if (mounted) {
      setState(() {
        _tasks = list;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    final task = SanitationTask(
      id: '',
      title: title,
      frequency: _frequency,
    );

    await _service.saveTask(task);
    _taskController.clear();
    _loadTasks();
  }

  Future<void> _toggleTask(SanitationTask task) async {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });

    final updated = SanitationTask(
      id: task.id,
      title: task.title,
      frequency: task.frequency,
      assignedTo: task.assignedTo,
      isCompleted: task.isCompleted,
      lastCompletedAt: task.isCompleted ? DateTime.now() : task.lastCompletedAt,
    );

    await _service.saveTask(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sanitation & Cleaning Routine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add task card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Site Cleaning Task',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _taskController,
                            decoration: const InputDecoration(
                              labelText: 'Task Title',
                              hintText: 'e.g. Septic Tank Inspection',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _frequency,
                          items: ['Daily', 'Weekly', 'Bi-Weekly', 'Monthly']
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _frequency = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _addTask,
                        icon: const Icon(Icons.add_task),
                        label: const Text('Add Cleaning Routine'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Building Sanitation Checklist',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final item = _tasks[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: item.isCompleted,
                          title: Text(
                            item.title,
                            style: TextStyle(
                              decoration: item.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('Routine: ${item.frequency}'),
                          secondary: Icon(
                            item.isCompleted
                                ? Icons.check_circle
                                : Icons.cleaning_services_outlined,
                            color: item.isCompleted
                                ? colors.primary
                                : colors.outline,
                          ),
                          onChanged: (_) => _toggleTask(item),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
