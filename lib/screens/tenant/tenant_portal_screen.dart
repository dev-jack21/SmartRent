import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/rent_credit_ledger.dart';
import '../../services/tenant_portal_repository.dart';
import '../../widgets/digital_payment_dialog.dart';
import '../../widgets/tenant_report_issue_dialog.dart';
import '../announcements/announcements_screen.dart';
import '../chat/chat_screen.dart';
import '../inspection/property_inspection_screen.dart';
import '../lease/digital_lease_screen.dart';
import '../notifications/notifications_center_screen.dart';
import '../profile/user_profile_screen.dart';
import 'tenant_locker_screen.dart';

class TenantPortalScreen extends StatefulWidget {
  final TenantPortalRepository? repository;
  final String? tenantEmail;

  const TenantPortalScreen({super.key, this.repository, this.tenantEmail});

  @override
  State<TenantPortalScreen> createState() => _TenantPortalScreenState();
}

class _TenantPortalScreenState extends State<TenantPortalScreen> {
  late final TenantPortalRepository _repository =
      widget.repository ?? SupabaseTenantPortalRepository();
  late Future<_TenantPortalData> _data;

  @override
  void initState() {
    super.initState();
    _data = _loadData();
  }

  Future<_TenantPortalData> _loadData() async {
    final email =
        widget.tenantEmail ?? Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw StateError('Your account does not have a verified email address.');
    }

    final properties = await _repository.loadProperties(tenantEmail: email);
    final ids = properties
        .map((property) => property['id'].toString())
        .toList(growable: false);
    if (ids.isEmpty) {
      return const _TenantPortalData(
        properties: [],
        payments: [],
        allocations: [],
      );
    }
    final results = await Future.wait([
      _repository.loadPayments(propertyIds: ids),
      _repository.loadCreditAllocations(propertyIds: ids),
    ]);
    return _TenantPortalData(
      properties: properties,
      payments: results[0],
      allocations: results[1],
    );
  }

  Future<void> _refresh() async {
    setState(() => _data = _loadData());
    try {
      await _data;
    } catch (_) {
      // FutureBuilder displays the load error.
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not log out: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        widget.tenantEmail ?? Supabase.instance.client.auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant portal'),
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
            tooltip: 'Refresh Portal',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
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
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_TenantPortalData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load your rental information.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(
                      onPressed: () => setState(() => _data = _loadData()),
                      child: const Text('Try again'),
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            if (data.properties.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Icon(Icons.home_work_outlined, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'No rental properties are linked to ${email ?? 'your email'} yet.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask your property owner or manager to add this exact email address to your rental.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final paymentsByProperty = <String, List<Map<String, dynamic>>>{};
            for (final payment in data.payments) {
              final propertyId = payment['property_id']?.toString();
              if (propertyId != null) {
                paymentsByProperty
                    .putIfAbsent(propertyId, () => [])
                    .add(payment);
              }
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Your rentals and rent payment history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final property in data.properties)
                  _PropertyCard(
                    property: property,
                    payments:
                        paymentsByProperty[property['id']?.toString()] ??
                        const [],
                    allocations: data.allocations
                        .where(
                          (allocation) =>
                              allocation['property_id']?.toString() ==
                              property['id']?.toString(),
                        )
                        .toList(growable: false),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TenantPortalData {
  final List<Map<String, dynamic>> properties;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> allocations;

  const _TenantPortalData({
    required this.properties,
    required this.payments,
    required this.allocations,
  });
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> allocations;

  const _PropertyCard({
    required this.property,
    required this.payments,
    required this.allocations,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rent = _number(property['monthly_rent']);
    final addressParts = [
      property['address']?.toString().trim(),
      property['unit_number']?.toString().trim(),
    ].where((value) => value != null && value.isNotEmpty).toList();
    final currency = property['currency']?.toString().trim() ?? '';
    final leaseStart = DateTime.tryParse(
      property['lease_start_date']?.toString() ??
          property['created_at']?.toString() ??
          '',
    );
    final now = DateTime.now();
    final ledger = RentCreditLedger.build(
      property: property,
      payments: payments,
      allocations: allocations,
      now: now,
      startMonth: leaseStart,
    );
    final currentBalance = ledger.firstWhere(
      (entry) => entry.month.year == now.year && entry.month.month == now.month,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              property['name']?.toString() ?? 'Rental property',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (addressParts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(addressParts.join(' • ')),
            ],
            const SizedBox(height: 8),
            Text(
              'Monthly rent: ${currency.isEmpty ? '' : '$currency '}${rent.toStringAsFixed(2)}'
              '${property['due_day'] == null ? '' : ' • Due day ${property['due_day']}'}',
            ),
            const SizedBox(height: 8),
            Text(
              'Current rent balance: ${currency.isEmpty ? '' : '$currency '}${currentBalance.amountOwing.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (currentBalance.availableCredit > 0)
              Text(
                'Available rent credit: ${currency.isEmpty ? '' : '$currency '}${currentBalance.availableCredit.toStringAsFixed(2)}',
              ),
            Text(
              currentBalance.status == 'Paid' ||
                      currentBalance.status == 'Credit'
                  ? 'Current month: ${currentBalance.status}'
                  : 'Current month: ${currentBalance.status} • due ${_date(currentBalance.dueDate)}',
            ),
            if (rent > 0) ...[
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rent Payment Progress',
                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.7)),
                      ),
                      Text(
                        '${((1 - (currentBalance.amountOwing / rent)) * 100).clamp(0, 100).toStringAsFixed(0)}% Paid',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: ((rent - currentBalance.amountOwing) / rent).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: colors.surfaceContainerHighest,
                      color: currentBalance.amountOwing <= 0 ? Colors.green : colors.primary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[800],
                ),
                onPressed: () async {
                  final paid = await showDialog<bool>(
                    context: context,
                    builder: (_) => DigitalPaymentDialog(
                      property: property,
                      defaultAmount: currentBalance.amountOwing > 0
                          ? currentBalance.amountOwing
                          : rent,
                    ),
                  );
                  if (paid == true) {
                    // Trigger state refresh
                  }
                },
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Pay Rent (M-Pesa / PayPal)'),
              ),
            ),
            if (property['lease_start_date'] != null ||
                property['lease_end_date'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Lease: ${_date(property['lease_start_date'])} – ${_date(property['lease_end_date'])}',
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            propertyId: property['id'].toString(),
                            propertyName: property['name']?.toString() ?? 'Rental Property',
                            counterpartyName: 'Landlord',
                            currentUserRole: 'tenant',
                            property: property,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => TenantReportIssueDialog(property: property),
                      );
                    },
                    icon: const Icon(Icons.build_outlined),
                    label: const Text('Report Issue'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DigitalLeaseScreen(
                            property: property,
                            userRole: 'tenant',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.draw_outlined),
                    label: const Text('Lease'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.campaign_outlined, size: 16),
                  label: const Text('Notice Board'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnnouncementsScreen(
                          property: property,
                          userRole: 'tenant',
                        ),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.checklist_outlined, size: 16),
                  label: const Text('Move Inspection'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PropertyInspectionScreen(property: property),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.lock_outlined, size: 16),
                  label: const Text('Locker & Contacts'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TenantLockerScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 28),
            Text(
              'Payment history',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No rent payment records yet.'),
              )
            else
              ...payments.map((payment) {
                final status =
                    payment['status']?.toString().toLowerCase() ?? 'unknown';
                final month = _date(payment['rent_month']);
                final paymentDate = _date(payment['payment_date']);
                final amount = _number(payment['amount']);
                final notes = payment['notes']?.toString().trim() ?? '';
                final details = [
                  if (paymentDate != '—') 'Recorded $paymentDate',
                  if (notes.isNotEmpty) notes,
                ].join(' • ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    month == '—' ? 'Rent payment' : 'Rent for $month',
                  ),
                  subtitle: Text(details.isEmpty ? 'Payment record' : details),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${currency.isEmpty ? '' : '$currency '}${amount.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(status, colors),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status[0].toUpperCase() + status.substring(1),
                              style: TextStyle(
                                color: colors.onSecondaryContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'View Receipt',
                        icon: const Icon(Icons.receipt_outlined),
                        onPressed: () {
                          _showReceiptDialog(context, property, payment);
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  static void _showReceiptDialog(
    BuildContext context,
    Map<String, dynamic> property,
    Map<String, dynamic> payment,
  ) {
    final currency = property['currency']?.toString() ?? 'KES';
    final amount = double.tryParse(payment['amount']?.toString() ?? '') ?? 0.0;
    final paymentDate = DateTime.tryParse(payment['payment_date']?.toString() ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Official Rent Payment Receipt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Property: ${property['name'] ?? 'Rental Property'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (property['unit_number'] != null)
                  Text('Unit Number: ${property['unit_number']}'),
                Text('Tenant Name: ${property['tenant_name'] ?? 'Tenant'}'),
                Text('Amount Paid: $currency ${amount.toStringAsFixed(2)}'),
                Text('Payment Status: ${payment['status']}'),
                Text('Date Recorded: ${_date(paymentDate)}'),
                if (payment['notes'] != null && payment['notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Notes: ${payment['notes']}'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static double _number(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Color _statusColor(String status, ColorScheme colors) {
    return switch (status) {
      'paid' => colors.primaryContainer,
      'pending' => colors.tertiaryContainer,
      'overdue' => colors.errorContainer,
      _ => colors.secondaryContainer,
    };
  }
}
