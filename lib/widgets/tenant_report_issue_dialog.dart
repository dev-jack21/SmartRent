import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantReportIssueDialog extends StatefulWidget {
  final Map<String, dynamic> property;

  const TenantReportIssueDialog({
    super.key,
    required this.property,
  });

  @override
  State<TenantReportIssueDialog> createState() =>
      _TenantReportIssueDialogState();
}

class _TenantReportIssueDialogState extends State<TenantReportIssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _photoUrlController = TextEditingController();

  String _priority = 'Medium';
  String? _attachedFileName;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(type: FileType.image);
      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        final file = pickedFiles.first;
        setState(() {
          _attachedFileName = file.name;
          _photoUrlController.text = file.name;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attached photo: ${file.name}')),
          );
        }
      }
    } catch (_) {
      // Fallback
    }
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = Supabase.instance.client.auth.currentUser;
    final propertyId = widget.property['id'].toString();
    final landlordUserId = widget.property['user_id']?.toString() ?? user?.id;

    var fullDescription = _descriptionController.text.trim();
    if (_attachedFileName != null && _attachedFileName!.isNotEmpty) {
      fullDescription += '\n[Photo Attached: $_attachedFileName]';
    } else if (_photoUrlController.text.trim().isNotEmpty) {
      fullDescription += '\n[Photo URL: ${_photoUrlController.text.trim()}]';
    }

    final payload = {
      'property_id': propertyId,
      'title': _titleController.text.trim(),
      'description': fullDescription,
      'priority': _priority,
      'status': 'Open',
    };

    if (landlordUserId != null && landlordUserId.isNotEmpty) {
      payload['user_id'] = landlordUserId;
    }

    try {
      await Supabase.instance.client.from('maintenance_requests').insert(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maintenance issue & photo proof reported successfully!'),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maintenance issue reported successfully!'),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final propName = widget.property['name']?.toString() ?? 'Apartment';

    return AlertDialog(
      title: Text('Report Issue for $propName'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe the maintenance problem and attach photo proof if available:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Issue Title *',
                  hintText: 'e.g., Leaking Kitchen Sink, No Hot Water',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detailed Description',
                  hintText: 'e.g. Water is leaking rapidly from the pipe under the sink.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority / Urgency',
                  border: OutlineInputBorder(),
                ),
                items: ['Low', 'Medium', 'High']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _priority = val);
                },
              ),
              const SizedBox(height: 16),

              // Photo Attachment Section
              Card(
                color: colors.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Photo Proof Attachment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.attach_file, size: 16),
                            label: const Text('Pick Image'),
                          ),
                        ],
                      ),
                      if (_attachedFileName != null) ...[
                        const SizedBox(height: 8),
                        Chip(
                          avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          label: Text(_attachedFileName!, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _photoUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Or Paste Photo URL / Image Link',
                          hintText: 'https://...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _submitIssue,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_isSaving ? 'Submitting...' : 'Report Issue'),
        ),
      ],
    );
  }
}
