import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/notification_service.dart';

class ReminderSettingsScreen extends StatefulWidget {
  final String propertyId;
  final String propertyName;

  const ReminderSettingsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final Map<int, bool> _reminders = {7: true, 3: true, 1: true, 0: true};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _supabase
          .from('reminders')
          .select('days_before, enabled')
          .eq('property_id', widget.propertyId)
          .eq('user_id', user.id);

      for (final row in response) {
        final days = int.tryParse(row['days_before'].toString());

        if (days != null && _reminders.containsKey(days)) {
          _reminders[days] = row['enabled'] == true;
        }
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load reminders: $error')),
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveReminders() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final hasEnabledReminders = _reminders.values.any((enabled) => enabled);
    if (kIsWeb &&
        hasEnabledReminders &&
        !await NotificationService.instance.requestBrowserPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow browser notifications to schedule reminders.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final property = await _supabase
          .from('properties')
          .select('name, monthly_rent, currency, due_day')
          .eq('id', widget.propertyId)
          .eq('user_id', user.id)
          .single();

      final propertyName = property['name']?.toString() ?? widget.propertyName;

      final currency = property['currency']?.toString() ?? 'KES';

      final rent = property['monthly_rent']?.toString() ?? '0';

      final dueDay = int.tryParse(property['due_day'].toString()) ?? 1;

      /*
       * Save reminder preferences in Supabase.
       */

      await _supabase
          .from('reminders')
          .delete()
          .eq('property_id', widget.propertyId)
          .eq('user_id', user.id);

      final rows = _reminders.entries.map((entry) {
        return {
          'user_id': user.id,
          'property_id': widget.propertyId,
          'days_before': entry.key,
          'enabled': entry.value,
        };
      }).toList();

      await _supabase.from('reminders').insert(rows);

      /*
       * Schedule notifications.
       */

      final baseNotificationId = widget.propertyId.hashCode.abs() % 100000;

      await NotificationService.instance.cancelPropertyReminders(
        baseNotificationId,
      );

      final enabledReminderDays = _reminders.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (enabledReminderDays.isNotEmpty) {
        await NotificationService.instance.scheduleMonthlyReminders(
          baseNotificationId: baseNotificationId,
          propertyName: propertyName,
          currency: currency,
          rent: rent,
          dueDay: dueDay,
          reminderDays: enabledReminderDays,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder settings saved successfully!')),
      );

      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reminders: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _enableBrowserNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final granted = await NotificationService.instance
          .requestBrowserPermission();
      if (!granted) {
        throw Exception(
          'Allow notifications for this site in Chrome settings.',
        );
      }

      final subscription = await NotificationService.instance
          .subscribeToBrowserPush();
      final keys = subscription['keys'] as Map<String, dynamic>;
      await _supabase.from('push_subscriptions').upsert({
        'user_id': user.id,
        'endpoint': subscription['endpoint'],
        'p256dh': keys['p256dh'],
        'auth': keys['auth'],
      }, onConflict: 'endpoint');
      NotificationService.instance.markBrowserPushSubscriptionSaved();

      await NotificationService.instance.showTestNotification();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background browser reminders enabled.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save browser subscription: ${error.message}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not enable browser reminders: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _labelForDays(int days) {
    if (days == 0) {
      return 'On the due date';
    }

    if (days == 1) {
      return '1 day before';
    }

    return '$days days before';
  }

  String _descriptionForDays(int days) {
    if (days == 0) {
      return 'Remind me on the day rent is due.';
    }

    if (days == 1) {
      return 'Remind me one day before rent is due.';
    }

    return 'Remind me $days days before rent is due.';
  }

  IconData _iconForDays(int days) {
    if (days == 0) {
      return Icons.event_available;
    }

    if (days == 1) {
      return Icons.warning_amber_rounded;
    }

    return Icons.notifications_active_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rent Reminders')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.propertyName,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text('Choose when you want to receive rent reminders.'),

                  const SizedBox(height: 24),

                  if (kIsWeb) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : _enableBrowserNotifications,
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Enable browser notifications'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep this app open in Chrome for scheduled reminders.',
                    ),
                    const SizedBox(height: 20),
                  ],

                  ..._reminders.keys.map((days) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: SwitchListTile(
                        value: _reminders[days]!,
                        onChanged: (value) {
                          setState(() {
                            _reminders[days] = value;
                          });
                        },
                        secondary: Icon(_iconForDays(days)),
                        title: Text(
                          _labelForDays(days),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(_descriptionForDays(days)),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveReminders,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Reminder Settings',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              kIsWeb
                                  ? 'Browser reminders are scheduled for 9:00 AM Kenya time while this app is open.'
                                  : 'Reminders are scheduled for 9:00 AM Kenya time for the next 12 months.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
