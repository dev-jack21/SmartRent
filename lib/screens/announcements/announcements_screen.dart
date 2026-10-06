import 'package:flutter/material.dart';
import '../../services/announcement_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  final String userRole; // 'owner' or 'tenant'

  const AnnouncementsScreen({
    super.key,
    required this.property,
    required this.userRole,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final AnnouncementService _service = AnnouncementService.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _category = 'General';
  bool _isLoading = true;
  bool _isSaving = false;
  List<PropertyAnnouncement> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    final list = await _service.loadAnnouncements(widget.property['id'].toString());
    if (mounted) {
      setState(() {
        _announcements = list;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _postAnnouncement() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and content.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final item = PropertyAnnouncement(
      id: '',
      propertyId: widget.property['id'].toString(),
      title: title,
      content: content,
      category: _category,
      createdAt: DateTime.now(),
    );

    final success = await _service.createAnnouncement(item);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      _titleController.clear();
      _contentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement posted successfully!')),
      );
      _loadAnnouncements();
    } else {
      setState(() {
        _announcements.insert(0, item);
      });
      _titleController.clear();
      _contentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted locally!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isOwner = widget.userRole == 'owner';
    final propName = widget.property['name']?.toString() ?? 'Building';

    return Scaffold(
      appBar: AppBar(
        title: Text('$propName Notice Board'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isOwner) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post Building Announcement',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Scheduled Water Maintenance',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _contentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notice Details *',
                          hintText: 'e.g. Water will be turned off tomorrow from 9am to 12pm for pipe repairs.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: ['General', 'Maintenance', 'Billing', 'Emergency']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _postAnnouncement,
                          icon: const Icon(Icons.campaign_outlined),
                          label: Text(_isSaving ? 'Posting...' : 'Post Announcement'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'Active Notices & Announcements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _announcements.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.campaign_outlined,
                                  size: 56, color: colors.primary.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text('No building notices posted yet.'),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _announcements.length,
                        itemBuilder: (context, index) {
                          final item = _announcements[index];
                          final dateStr =
                              '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _categoryColor(item.category, colors),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Posted: $dateStr',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const Divider(height: 16),
                                  Text(
                                    item.content,
                                    style: const TextStyle(fontSize: 14, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category, ColorScheme colors) {
    switch (category) {
      case 'Emergency':
        return colors.errorContainer;
      case 'Maintenance':
        return colors.tertiaryContainer;
      case 'Billing':
        return colors.secondaryContainer;
      default:
        return colors.primaryContainer;
    }
  }
}
