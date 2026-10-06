import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceRequestsScreen extends StatefulWidget {
  const MaintenanceRequestsScreen({super.key});

  @override
  State<MaintenanceRequestsScreen> createState() =>
      _MaintenanceRequestsScreenState();
}

class _MaintenanceRequestsScreenState extends State<MaintenanceRequestsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const List<String> _priorities = ['Low', 'Medium', 'High'];
  static const List<String> _statuses = ['Open', 'In Progress', 'Completed'];

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _requests = [];
  String? _selectedPropertyId;
  String _priority = 'Medium';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You are not logged in.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final propertiesResponse = await _supabase
          .from('properties')
          .select('id, name')
          .eq('user_id', user.id)
          .order('name');
      final requestsResponse = await _supabase
          .from('maintenance_requests')
          .select(
            'id, property_id, title, description, priority, status, created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final properties = List<Map<String, dynamic>>.from(propertiesResponse);
      setState(() {
        _properties = properties;
        _requests = List<Map<String, dynamic>>.from(requestsResponse);
        if (_selectedPropertyId == null ||
            !properties.any(
              (property) => property['id'].toString() == _selectedPropertyId,
            )) {
          _selectedPropertyId = properties.isEmpty
              ? null
              : properties.first['id'].toString();
        }
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load maintenance requests: ${error.message}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong: $error';
      });
    }
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null || _selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a property before creating a request.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _supabase.from('maintenance_requests').insert({
        'user_id': user.id,
        'property_id': _selectedPropertyId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'priority': _priority,
      });

      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      setState(() => _priority = 'Medium');
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance request created.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create request: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create request: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateStatus(
    Map<String, dynamic> request,
    String status,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final requestId = request['id'].toString();
    try {
      await _supabase
          .from('maintenance_requests')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('user_id', user.id);

      if (!mounted) return;
      setState(() {
        final index = _requests.indexWhere(
          (item) => item['id'].toString() == requestId,
        );
        if (index != -1) _requests[index]['status'] = status;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $error')),
      );
    }
  }

  String _propertyName(String propertyId) {
    return _properties
            .firstWhere(
              (property) => property['id'].toString() == propertyId,
              orElse: () => {'name': 'Property'},
            )['name']
            ?.toString() ??
        'Property';
  }

  String _formatDate(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _priorityColor(String priority) {
    if (priority == 'High') return Theme.of(context).colorScheme.error;
    if (priority == 'Low') return Theme.of(context).colorScheme.tertiary;
    return Theme.of(context).colorScheme.primary;
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final priority = request['priority']?.toString() ?? 'Medium';
    final status = request['status']?.toString() ?? 'Open';
    final propertyId = request['property_id'].toString();
    final description = request['description']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _priorityColor(priority)
                      .withValues(alpha: 0.12),
                  child: Icon(
                    Icons.handyman_outlined,
                    color: _priorityColor(priority),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['title']?.toString() ?? 'Maintenance request',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_propertyName(propertyId)} · ${_formatDate(request['created_at']?.toString())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Update status',
                  initialValue: status,
                  onSelected: (value) => _updateStatus(request, value),
                  itemBuilder: (context) => _statuses
                      .map(
                        (value) => PopupMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  child: Chip(
                    label: Text(status),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.expand_more, size: 18),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description),
            ],
            const SizedBox(height: 10),
            Text(
              '$priority priority',
              style: TextStyle(
                color: _priorityColor(priority),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'New request',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              if (_properties.isEmpty)
                                const Text(
                                  'Add a property before creating a maintenance request.',
                                )
                              else
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedPropertyId,
                                  decoration: const InputDecoration(
                                    labelText: 'Property',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _properties
                                      .map(
                                        (property) => DropdownMenuItem<String>(
                                          value: property['id'].toString(),
                                          child: Text(
                                            property['name']?.toString() ??
                                                'Property',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(
                                        () => _selectedPropertyId = value,
                                      );
                                    }
                                  },
                                ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _titleController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Issue',
                                  hintText: 'e.g. Leaking kitchen tap',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter a short issue title'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Details (optional)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _priority,
                                decoration: const InputDecoration(
                                  labelText: 'Priority',
                                  border: OutlineInputBorder(),
                                ),
                                items: _priorities
                                    .map(
                                      (value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _priority = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _isSaving || _properties.isEmpty
                                    ? null
                                    : _saveRequest,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add_task_outlined),
                                label: Text(
                                  _isSaving ? 'Saving...' : 'Create Request',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Requests',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_requests.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No maintenance requests yet.'),
                        ),
                      )
                    else
                      ..._requests.map(_buildRequestCard),
                  ],
                ),
              ),
            ),
    );
  }
}
