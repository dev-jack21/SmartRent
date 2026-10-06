import 'package:flutter/material.dart';
import '../../services/app_notification_hub_service.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState
    extends State<NotificationsCenterScreen> {
  final AppNotificationHubService _service =
      AppNotificationHubService.instance;

  bool _isLoading = true;
  List<AppNotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final list = await _service.loadNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();
    if (mounted) {
      setState(() {
        for (var item in _notifications) {
          item.isRead = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications Center'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 64, color: colors.primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('No notifications yet',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        const Text(
                          'You will receive notifications here for rent due dates, payments, and messages.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final dateStr =
                        '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')}';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: item.isRead
                          ? colors.surface
                          : colors.primaryContainer.withValues(alpha: 0.3),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _typeColor(item.type, colors),
                          child: Icon(
                            _typeIcon(item.type),
                            color: colors.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.body),
                            const SizedBox(height: 6),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: !item.isRead
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            item.isRead = true;
                          });
                        },
                      ),
                    );
                  },
                ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'payment':
        return Icons.payments_outlined;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'maintenance':
        return Icons.handyman_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _typeColor(String type, ColorScheme colors) {
    switch (type) {
      case 'payment':
        return colors.primaryContainer;
      case 'maintenance':
        return colors.tertiaryContainer;
      case 'announcement':
        return colors.secondaryContainer;
      default:
        return colors.surfaceContainerHighest;
    }
  }
}
