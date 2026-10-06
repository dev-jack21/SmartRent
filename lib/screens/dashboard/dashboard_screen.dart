import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_navigation.dart';
import '../../services/notification_service.dart';
import '../../services/overdue_rent_follow_up.dart';
import '../../services/rent_credit_ledger.dart';
import '../../services/tenant_communication_service.dart';
import '../../widgets/digital_payment_dialog.dart';
import '../announcements/announcements_screen.dart';
import '../auth/login_screen.dart';
import '../caretaker/caretaker_dashboard_screen.dart';
import '../chat/chat_screen.dart';
import '../documents/manage_property_documents_screen.dart';
import '../inspection/property_inspection_screen.dart';
import '../lease/digital_lease_screen.dart';
import '../vacancy/vacancy_management_screen.dart';
import '../expenses/expense_tracker_screen.dart';
import '../export/data_export_screen.dart';
import '../maintenance/maintenance_requests_screen.dart';
import '../notifications/notifications_center_screen.dart';
import '../profile/user_profile_screen.dart';
import '../property/add_property_screen.dart';
import '../payments/payment_tracker_screen.dart';
import '../reminders/reminder_settings_screen.dart';
import '../security/security_settings_screen.dart';
import '../tenant/tenant_directory_screen.dart';
import '../tenant/tenant_portal_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _RentCycleStatus {
  final String label;
  final double amountReceived;
  final double creditApplied;
  final double balance;
  final DateTime dueDate;
  final int daysUntilDue;
  final bool isPaid;

  const _RentCycleStatus({
    required this.label,
    required this.amountReceived,
    required this.creditApplied,
    required this.balance,
    required this.dueDate,
    required this.daysUntilDue,
    required this.isPaid,
  });
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _creditAllocations = [];

  bool _isLoading = true;
  String? _errorMessage;
  String? _paymentLoadError;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

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
      final response = await _supabase
          .from('properties')
          .select(
            'id, name, address, unit_number, tenant_name, tenant_email, tenant_phone, monthly_rent, currency, due_day, lease_start_date, lease_end_date, created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final properties = List<Map<String, dynamic>>.from(response);
      List<Map<String, dynamic>> payments = [];
      List<Map<String, dynamic>> creditAllocations = [];
      String? paymentLoadError;

      try {
        final paymentResponse = await _supabase
            .from('payments')
            .select('property_id, amount, status, rent_month')
            .eq('user_id', user.id);
        payments = List<Map<String, dynamic>>.from(paymentResponse);
        final allocationResponse = await _supabase
            .from('rent_credit_allocations')
            .select('property_id, source_month, target_month, amount')
            .eq('user_id', user.id);
        creditAllocations = List<Map<String, dynamic>>.from(allocationResponse);
      } catch (error) {
        paymentLoadError = error.toString();
      }

      if (!mounted) return;

      setState(() {
        _properties = properties;
        _payments = payments;
        _creditAllocations = creditAllocations;
        _paymentLoadError = paymentLoadError;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load properties: ${error.message}';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong: $error';
      });
    }
  }

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();

      if (_supabase.auth.currentSession != null) {
        throw StateError('Supabase still has an active session after sign-out.');
      }

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        throw StateError('The app navigator is not available.');
      }

      navigator.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not log out: $error')));
    }
  }

  Future<void> _scheduleTestReminder() async {
    try {
      await NotificationService.instance.scheduleTestReminder();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test reminder scheduled for 1 minute from now.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule test reminder: $error')),
      );
    }
  }

  Future<void> _editProperty(Map<String, dynamic> property) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddPropertyScreen(property: property)),
    );

    if (result == true) {
      await _loadProperties();
    }
  }

  Future<void> _deleteProperty(Map<String, dynamic> property) async {
    final propertyId = property['id']?.toString();

    if (propertyId == null || propertyId.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete property?'),
          content: Text(
            'This will remove "${property['name'] ?? 'this property'}" and its reminder settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      final baseNotificationId = propertyId.hashCode.abs() % 100000;
      await NotificationService.instance.cancelPropertyReminders(
        baseNotificationId,
      );

      await _supabase
          .from('reminders')
          .delete()
          .eq('property_id', propertyId)
          .eq('user_id', user.id);
      await _supabase
          .from('properties')
          .delete()
          .eq('id', propertyId)
          .eq('user_id', user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property deleted successfully.')),
      );

      await _loadProperties();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete property: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete property: $error')),
      );
    }
  }

  Map<String, dynamic> _getMonthlyOverview() {
    double totalRent = 0;
    int nextDueDay = 31;
    int dueThisMonth = 0;

    final today = DateTime.now();

    for (final property in _properties) {
      final rent =
          double.tryParse(property['monthly_rent']?.toString() ?? '0') ?? 0;
      totalRent += rent;

      final dueDay = int.tryParse(property['due_day']?.toString() ?? '') ?? 1;
      if (dueDay >= today.day) {
        dueThisMonth++;
      }

      if (dueDay < nextDueDay) {
        nextDueDay = dueDay;
      }
    }

    return {
      'totalRent': totalRent,
      'propertyCount': _properties.length,
      'dueThisMonth': dueThisMonth,
      'nextDueDay': _properties.isEmpty ? 1 : nextDueDay,
    };
  }

  _RentCycleStatus _getRentCycleStatus(Map<String, dynamic> property) {
    final now = DateTime.now();
    final ledger = RentCreditLedger.build(
      property: property,
      payments: _payments,
      allocations: _creditAllocations,
      now: now,
    );
    final currentMonth = DateTime(now.year, now.month);
    final entry = ledger.firstWhere(
      (item) =>
          item.month.year == currentMonth.year &&
          item.month.month == currentMonth.month,
    );
    final balance = entry.amountOwing - entry.availableCredit;
    final isPaid = balance <= 0;

    return _RentCycleStatus(
      label: entry.status,
      amountReceived: entry.cashReceived,
      creditApplied: entry.creditApplied,
      balance: balance,
      dueDate: entry.dueDate,
      daysUntilDue: entry.daysUntilDue,
      isPaid: isPaid,
    );
  }

  String _formatRentMonth(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _recordPayment(Map<String, dynamic> property) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentTrackerScreen(
          propertyId: property['id'].toString(),
          rentMonth: DateTime.now(),
          closeAfterSave: true,
        ),
      ),
    );

    if (result == true) {
      await _loadProperties();
    }
  }

  Future<void> _emailRentReminder(Map<String, dynamic> property) async {
    final tenantEmail = property['tenant_email']?.toString().trim() ?? '';

    if (tenantEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the tenant email to this property first.'),
        ),
      );
      return;
    }

    final propertyName = property['name']?.toString() ?? 'your rental property';
    final tenantName = property['tenant_name']?.toString().trim() ?? '';
    final unitNumber = property['unit_number']?.toString().trim() ?? '';
    final address = property['address']?.toString().trim() ?? '';
    final currency = property['currency']?.toString() ?? 'KES';
    final rent = double.tryParse(
      property['monthly_rent']?.toString() ?? '',
    );
    final dueDay = property['due_day']?.toString() ?? '';
    final rentStatus = _getRentCycleStatus(property);
    final subject = 'Rent reminder - $propertyName';
    final greeting = tenantName.isEmpty ? 'Hello,' : 'Hello $tenantName,';
    final propertyDetails = [
      if (unitNumber.isNotEmpty) 'Unit: $unitNumber',
      if (address.isNotEmpty) 'Address: $address',
    ];
    final body = [
      greeting,
      '',
      'This is a friendly reminder about the rent for $propertyName.',
      if (propertyDetails.isNotEmpty) ...propertyDetails,
      if (rent != null)
        'Monthly rent: ${_formatCurrency(rent, currency: currency)}',
      if (dueDay.isNotEmpty) 'Rent due day: $dueDay of each month',
      'Upcoming due date: ${_formatDate(rentStatus.dueDate)}',
      '',
      'Please let me know once payment has been sent. Thank you.',
    ].join('\n');

    final tenantPhone = property['tenant_phone']?.toString().trim() ?? '';

    await _sendReminderDialog(
      tenantEmail: tenantEmail,
      tenantPhone: tenantPhone,
      subject: subject,
      body: body,
    );
  }

  Future<void> _sendReminderDialog({
    required String tenantEmail,
    required String tenantPhone,
    required String subject,
    required String body,
  }) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: tenantEmail,
      queryParameters: {'subject': subject, 'body': body},
    );

    bool opened = false;
    try {
      opened = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!opened && mounted) {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Send Rent Reminder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipient: $tenantEmail',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      body,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '$subject\n\n$body'));
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminder text copied to clipboard!')),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy Text'),
              ),
              if (tenantPhone.isNotEmpty)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green[700]),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    TenantCommunicationService.instance.sendWhatsApp(
                      phone: tenantPhone,
                      message: '$subject\n\n$body',
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
            ],
          );
        },
      );
    }
  }

  List<OverdueRentFollowUp> _getOverdueFollowUps() {
    return OverdueRentFollowUp.build(
      properties: _properties,
      payments: _payments,
      allocations: _creditAllocations,
      now: DateTime.now(),
    );
  }

  Future<void> _emailOverdueFollowUp(OverdueRentFollowUp followUp) async {
    final property = followUp.property;
    final tenantEmail = property['tenant_email']?.toString().trim() ?? '';

    if (tenantEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the tenant email to this property first.'),
        ),
      );
      return;
    }

    final propertyName = property['name']?.toString() ?? 'your rental property';
    final tenantName = property['tenant_name']?.toString().trim() ?? '';
    final unitNumber = property['unit_number']?.toString().trim() ?? '';
    final address = property['address']?.toString().trim() ?? '';
    final currency = property['currency']?.toString() ?? 'KES';
    final greeting = tenantName.isEmpty ? 'Hello,' : 'Hello $tenantName,';
    final overdueLines = followUp.overdueEntries.map((entry) {
      return '- ${_formatRentMonth(entry.month)} (due ${_formatDate(entry.dueDate)}): '
          '${_formatCurrency(entry.amountOwing, currency: currency)} outstanding';
    });
    final body = [
      greeting,
      '',
      'This is a friendly follow-up about overdue rent for $propertyName.',
      if (unitNumber.isNotEmpty) 'Unit: $unitNumber',
      if (address.isNotEmpty) 'Address: $address',
      '',
      'Outstanding rent:',
      ...overdueLines,
      'Total overdue: ${_formatCurrency(followUp.totalOwing, currency: currency)}',
      '',
      'Please let me know when payment has been sent, or contact me if you have any questions. Thank you.',
    ].join('\n');
    final tenantPhone = property['tenant_phone']?.toString().trim() ?? '';

    await _sendReminderDialog(
      tenantEmail: tenantEmail,
      tenantPhone: tenantPhone,
      subject: 'Overdue rent follow-up - $propertyName',
      body: body,
    );
  }

  Widget _buildOverdueFollowUpCard() {
    final followUps = _getOverdueFollowUps();

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Overdue rent follow-up',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_paymentLoadError != null)
              Text(
                'Overdue balances are unavailable until payment and credit data load.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              )
            else if (followUps.isEmpty)
              Text(
                'No overdue rent. Outstanding rent past its due date will appear here.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              )
            else
              ...followUps.map((followUp) {
                final property = followUp.property;
                final name = property['name']?.toString() ?? 'Property';
                final currency = property['currency']?.toString() ?? 'KES';
                final monthLabels = followUp.overdueEntries
                    .map((entry) => _formatRentMonth(entry.month))
                    .join(', ');
                final tenantEmail =
                    property['tenant_email']?.toString().trim() ?? '';

                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatCurrency(
                                followUp.totalOwing,
                                currency: currency,
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Overdue months: $monthLabels'),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: tenantEmail.isEmpty
                                ? null
                                : () => _emailOverdueFollowUp(followUp),
                            icon: const Icon(Icons.email_outlined),
                            label: Text(
                              tenantEmail.isEmpty
                                  ? 'Add tenant email'
                                  : 'Email follow-up',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getLeaseRenewals() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.add(const Duration(days: 90));
    final leases = _properties.where((property) {
      final endDate = DateTime.tryParse(
        property['lease_end_date']?.toString() ?? '',
      );
      return endDate != null && !endDate.isAfter(cutoff);
    }).toList();

    leases.sort((first, second) {
      final firstDate = DateTime.parse(first['lease_end_date'].toString());
      final secondDate = DateTime.parse(second['lease_end_date'].toString());
      return firstDate.compareTo(secondDate);
    });

    return leases;
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _leaseExpiryLabel(DateTime endDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(endDate.year, endDate.month, endDate.day);
    final daysRemaining = date.difference(today).inDays;

    if (daysRemaining < 0) {
      return 'Expired ${daysRemaining.abs()} ${daysRemaining.abs() == 1 ? 'day' : 'days'} ago';
    }
    if (daysRemaining == 0) return 'Ends today';
    if (daysRemaining == 1) return 'Ends tomorrow';
    return 'Ends in $daysRemaining days';
  }

  Future<void> _showPropertyDetails(Map<String, dynamic> property) async {
    final propertyName = property['name']?.toString() ?? 'Property';

    final address = property['address']?.toString() ?? 'No address';

    final unitNumber = property['unit_number']?.toString() ?? 'Not specified';

    final currency = property['currency']?.toString() ?? 'KES';

    final monthlyRent = property['monthly_rent']?.toString() ?? '0';

    final dueDay = property['due_day']?.toString() ?? 'Not specified';
    final tenantName = property['tenant_name']?.toString() ?? '';
    final tenantEmail = property['tenant_email']?.toString() ?? '';
    final tenantPhone = property['tenant_phone']?.toString() ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  propertyName,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: address,
                ),

                _DetailRow(
                  icon: Icons.home_outlined,
                  label: 'Unit',
                  value: unitNumber,
                ),

                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Monthly rent',
                  value: '$currency $monthlyRent',
                ),

                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Due day',
                  value: 'Day $dueDay',
                ),

                if (tenantName.isNotEmpty)
                  _DetailRow(
                    icon: Icons.person_outline,
                    label: 'Tenant',
                    value: tenantName,
                  ),

                if (tenantEmail.isNotEmpty)
                  _DetailRow(
                    icon: Icons.email_outlined,
                    label: 'Tenant email',
                    value: tenantEmail,
                  ),

                if (tenantPhone.isNotEmpty)
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Tenant phone',
                    value: tenantPhone,
                  ),

                if (property['lease_start_date'] != null)
                  _DetailRow(
                    icon: Icons.event_outlined,
                    label: 'Lease start',
                    value: _formatDate(
                      DateTime.parse(property['lease_start_date'].toString()),
                    ),
                  ),

                if (property['lease_end_date'] != null)
                  _DetailRow(
                    icon: Icons.event_busy_outlined,
                    label: 'Lease end',
                    value: _formatDate(
                      DateTime.parse(property['lease_end_date'].toString()),
                    ),
                  ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReminderSettingsScreen(
                            propertyId: property['id'].toString(),
                            propertyName: propertyName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Reminder Settings'),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: tenantEmail.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            _emailRentReminder(property);
                          },
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email rent reminder'),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _editProperty(property);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteProperty(property);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    final name = property['name']?.toString() ?? 'Unnamed Property';

    final address = property['address']?.toString() ?? 'No address';

    final unitNumber = property['unit_number']?.toString() ?? 'N/A';

    final currency = property['currency']?.toString() ?? 'KES';

    final rent = property['monthly_rent']?.toString() ?? '0';

    final dueDay = property['due_day']?.toString() ?? 'N/A';
    final rentStatus = _getRentCycleStatus(property);
    final statusColor = rentStatus.isPaid
        ? Theme.of(context).colorScheme.primary
        : rentStatus.daysUntilDue < 0
        ? Theme.of(context).colorScheme.error
        : rentStatus.daysUntilDue <= 7
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.secondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.home_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'details') {
                      await _showPropertyDetails(property);
                    } else if (value == 'inspection') {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PropertyInspectionScreen(property: property),
                        ),
                      );
                    } else if (value == 'lease') {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DigitalLeaseScreen(
                            property: property,
                            userRole: 'owner',
                          ),
                        ),
                      );
                    } else if (value == 'applications') {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VacancyManagementScreen(property: property),
                        ),
                      );
                    } else if (value == 'tenant_portal') {
                      if (!mounted) return;
                      final tenantEmail = property['tenant_email']?.toString().trim() ?? '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TenantPortalScreen(
                            tenantEmail: tenantEmail.isNotEmpty ? tenantEmail : null,
                          ),
                        ),
                      );
                    } else if (value == 'notices') {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnnouncementsScreen(
                            property: property,
                            userRole: 'owner',
                          ),
                        ),
                      );
                    } else if (value == 'edit') {
                      await _editProperty(property);
                    } else if (value == 'delete') {
                      await _deleteProperty(property);
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline),
                            SizedBox(width: 8),
                            Text('View details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'inspection',
                        child: Row(
                          children: [
                            Icon(Icons.checklist_outlined),
                            SizedBox(width: 8),
                            Text('Move-In/Out Checklist'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'lease',
                        child: Row(
                          children: [
                            Icon(Icons.draw_outlined),
                            SizedBox(width: 8),
                            Text('Digital Lease Contract'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'applications',
                        child: Row(
                          children: [
                            Icon(Icons.person_search_outlined),
                            SizedBox(width: 8),
                            Text('Tenant Applications'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'tenant_portal',
                        child: Row(
                          children: [
                            Icon(Icons.sensor_door_outlined),
                            SizedBox(width: 8),
                            Text('Preview Tenant Portal'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'notices',
                        child: Row(
                          children: [
                            Icon(Icons.campaign_outlined),
                            SizedBox(width: 8),
                            Text('Notice Board'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('Edit property'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline),
                            SizedBox(width: 8),
                            Text('Delete property'),
                          ],
                        ),
                      ),
                    ];
                  },
                  child: const Icon(Icons.more_vert),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Divider(),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    icon: Icons.payments_outlined,
                    label: 'Monthly rent',
                    value: '$currency $rent',
                  ),
                ),

                Expanded(
                  child: _SummaryItem(
                    icon: Icons.home_outlined,
                    label: 'Unit',
                    value: unitNumber,
                  ),
                ),

                Expanded(
                  child: _SummaryItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Due day',
                    value: 'Day $dueDay',
                  ),
                ),
              ],
            ),

            if (_paymentLoadError == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      rentStatus.isPaid
                          ? Icons.check_circle_outline
                          : rentStatus.daysUntilDue < 0
                          ? Icons.warning_amber_outlined
                          : Icons.schedule_outlined,
                      color: statusColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rentStatus.label,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            rentStatus.balance < 0
                                ? '${_formatCurrency(-rentStatus.balance, currency: currency)} available credit'
                                : rentStatus.creditApplied > 0
                                ? '${_formatCurrency(rentStatus.creditApplied, currency: currency)} credit applied this month'
                                : rentStatus.isPaid
                                ? 'Paid for ${_formatRentMonth(DateTime.now())}'
                                : rentStatus.amountReceived > 0
                                ? '${_formatCurrency(rentStatus.amountReceived, currency: currency)} received this month'
                                : rentStatus.daysUntilDue < 0
                                ? 'Due ${_formatDate(rentStatus.dueDate)}'
                                : rentStatus.daysUntilDue == 0
                                ? 'Due today'
                                : 'Due in ${rentStatus.daysUntilDue} ${rentStatus.daysUntilDue == 1 ? 'day' : 'days'}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(
                            rentStatus.balance.abs(),
                            currency: currency,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          rentStatus.balance < 0
                              ? 'credit'
                              : rentStatus.balance == 0
                              ? 'settled'
                              : 'remaining',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[800],
                ),
                onPressed: () async {
                  final parsedRent = double.tryParse(rent) ?? 0.0;
                  final paid = await showDialog<bool>(
                    context: context,
                    builder: (_) => DigitalPaymentDialog(
                      property: property,
                      defaultAmount: rentStatus.balance > 0 ? rentStatus.balance : parsedRent,
                    ),
                  );
                  if (paid == true) {
                    _loadProperties();
                  }
                },
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Collect Rent (M-Pesa / PayPal)'),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReminderSettingsScreen(
                            propertyId: property['id'].toString(),
                            propertyName: name,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Reminders'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _paymentLoadError == null
                        ? () => _recordPayment(property)
                        : null,
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('Add payment'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            propertyId: property['id'].toString(),
                            propertyName: property['name']?.toString() ?? 'Property',
                            counterpartyName: property['tenant_name']?.toString(),
                            currentUserRole: 'owner',
                            property: property,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: property['tenant_email']?.toString().trim().isEmpty ??
                            true
                        ? null
                        : () => _emailRentReminder(property),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email reminder'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56),

              const SizedBox(height: 16),

              Text(_errorMessage!, textAlign: TextAlign.center),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: _loadProperties,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProperties,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your Properties',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            _properties.isEmpty
                ? 'Add your first property to get started.'
                : '${_properties.length} ${_properties.length == 1 ? 'property' : 'properties'}',
            style: TextStyle(color: Colors.grey[600]),
          ),

          if (_paymentLoadError != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly rent status is unavailable.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(_paymentLoadError!),
                    const SizedBox(height: 4),
                    const Text(
                      'Confirm rent_month and rent_credit_allocations exist in Supabase, then refresh.',
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          if (_properties.isNotEmpty) ...[
            _buildOverdueFollowUpCard(),
            const SizedBox(height: 16),
          ],

          if (_properties.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Icon(Icons.home_work_outlined, size: 64),

                    const SizedBox(height: 16),

                    const Text(
                      'No properties yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Add a property to start receiving rent reminders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._properties.map(_buildPropertyCard),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long_outlined),
                      SizedBox(width: 10),
                      Text(
                        'Cash flow',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Track rent payments, verify status, and capture recent payment history.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentTrackerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('Open Payment Tracker'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long_outlined),
                      SizedBox(width: 10),
                      Text(
                        'Property expenses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Record repairs, insurance, taxes, and other property costs.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ExpenseTrackerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_card_outlined),
                      label: const Text('Open Expense Tracker'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.handyman_outlined),
                      SizedBox(width: 10),
                      Text(
                        'Property care',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Log repairs and follow maintenance progress by property.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MaintenanceRequestsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.build_outlined),
                      label: const Text('Open Maintenance Requests'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (_properties.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bar_chart_rounded),
                        SizedBox(width: 10),
                        Text(
                          'Monthly Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _OverviewMetric(
                            label: 'Total rent',
                            value: _formatCurrency(
                              _getMonthlyOverview()['totalRent'] as double,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _OverviewMetric(
                            label: 'Due this month',
                            value: '${_getMonthlyOverview()['dueThisMonth']}',
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 12),
                    _OverviewMetric(
                      label: 'Next due day',
                      value: 'Day ${_getMonthlyOverview()['nextDueDay']}',
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox.shrink(),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.event_available_outlined),
                      SizedBox(width: 10),
                      Text(
                        'Lease renewals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Expired leases and leases ending in the next 90 days.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  if (_getLeaseRenewals().isEmpty)
                    Text(
                      'No lease expirations to review.',
                      style: TextStyle(color: Colors.grey[700]),
                    )
                  else
                    ..._getLeaseRenewals().map((property) {
                      final endDate = DateTime.parse(
                        property['lease_end_date'].toString(),
                      );
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final normalizedEnd = DateTime(
                        endDate.year,
                        endDate.month,
                        endDate.day,
                      );
                      final daysRemaining = normalizedEnd
                          .difference(today)
                          .inDays;
                      final statusColor = daysRemaining < 0
                          ? Theme.of(context).colorScheme.error
                          : daysRemaining <= 30
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.primary;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          daysRemaining < 0
                              ? Icons.warning_amber_outlined
                              : Icons.event_outlined,
                          color: statusColor,
                        ),
                        title: Text(
                          property['name']?.toString() ?? 'Property',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_formatDate(endDate)} · ${_leaseExpiryLabel(endDate)}',
                          style: TextStyle(color: statusColor),
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editProperty(property),
                      );
                    }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined),
                      SizedBox(width: 10),
                      Text(
                        'Notification Testing',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Use this to verify that scheduled Android notifications are working.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _scheduleTestReminder,
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('Test Reminder in 1 Minute'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        try {
                          await NotificationService.instance
                              .showTestNotification();

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Test notification sent.'),
                            ),
                          );
                        } catch (error) {
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Notification error: $error'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.notifications),
                      label: const Text('Send Notification Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String _formatCurrency(double value, {String currency = 'KES'}) {
    final roundedValue = value.toStringAsFixed(0);
    final formattedValue = roundedValue.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
    return '$currency $formattedValue';
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    final email = user?.email ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent Reminder'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsCenterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserProfileScreen(),
                ),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Tenants Directory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TenantDirectoryScreen(properties: _properties),
                ),
              );
            },
            icon: const Icon(Icons.people_outline),
          ),
          IconButton(
            tooltip: 'Payment tracker',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentTrackerScreen()),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadProperties,
            icon: const Icon(Icons.refresh),
          ),

          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'tenants') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TenantDirectoryScreen(properties: _properties),
                  ),
                );
              } else if (value == 'payment_tracker') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentTrackerScreen(),
                  ),
                );
              } else if (value == 'documents') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManagePropertyDocumentsScreen(),
                  ),
                );
              } else if (value == 'data_export') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DataExportScreen()),
                );
              } else if (value == 'security') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
                );
              } else if (value == 'caretaker') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CaretakerDashboardScreen()),
                );
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: 'account',
                  enabled: false,
                  child: Text(email, overflow: TextOverflow.ellipsis),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'tenants',
                  child: Row(
                    children: [
                      Icon(Icons.people_outline),
                      SizedBox(width: 10),
                      Text('Tenants directory'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'caretaker',
                  child: Row(
                    children: [
                      Icon(Icons.engineering_outlined),
                      SizedBox(width: 10),
                      Text('Caretaker portal'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'payment_tracker',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined),
                      SizedBox(width: 10),
                      Text('Payment tracker'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'documents',
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined),
                      SizedBox(width: 10),
                      Text('Property documents'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'data_export',
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined),
                      SizedBox(width: 10),
                      Text('Backup & export'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'security',
                  child: Row(
                    children: [
                      Icon(Icons.security_outlined),
                      SizedBox(width: 10),
                      Text('Security & sync'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 10),
                      Text('Log out'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),

      body: _buildBody(),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
          );

          if (result == true) {
            await _loadProperties();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Property'),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  final String label;
  final String value;

  const _OverviewMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),

        const SizedBox(height: 5),

        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),

        const SizedBox(height: 2),

        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
