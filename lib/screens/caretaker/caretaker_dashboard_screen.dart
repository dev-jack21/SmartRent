import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ai/ai_assistant_screen.dart';
import '../analytics/financial_analytics_screen.dart';
import '../announcements/announcements_screen.dart';
import '../emergency/emergency_alert_screen.dart';
import '../expenses/expense_tracker_screen.dart';
import '../inspection/property_inspection_screen.dart';
import '../maintenance/maintenance_requests_screen.dart';
import '../profile/user_profile_screen.dart';
import '../tenant/tenant_directory_screen.dart';
import 'key_management_screen.dart';
import 'parcel_logger_screen.dart';
import 'sanitation_schedule_screen.dart';
import 'vendor_directory_screen.dart';

class CaretakerDashboardScreen extends StatefulWidget {
  const CaretakerDashboardScreen({super.key});

  @override
  State<CaretakerDashboardScreen> createState() =>
      _CaretakerDashboardScreenState();
}

class _CaretakerDashboardScreenState extends State<CaretakerDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _maintenanceRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCaretakerData();
  }

  Future<void> _loadCaretakerData() async {
    setState(() => _isLoading = true);

    try {
      final propertiesResponse = await _supabase
          .from('properties')
          .select('id, name, address, unit_number, tenant_name, tenant_email, tenant_phone, monthly_rent, currency')
          .order('name');

      final requestsResponse = await _supabase
          .from('maintenance_requests')
          .select('id, property_id, title, description, priority, status, created_at')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _properties = List<Map<String, dynamic>>.from(propertiesResponse);
          _maintenanceRequests = List<Map<String, dynamic>>.from(requestsResponse);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _openMaintenanceCount =>
      _maintenanceRequests.where((r) => r['status'] != 'Completed').length;

  Future<void> _updateTicketStatus(Map<String, dynamic> ticket, String newStatus) async {
    try {
      await _supabase
          .from('maintenance_requests')
          .update({'status': newStatus})
          .eq('id', ticket['id']);
      await _loadCaretakerData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket status updated to $newStatus!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    }
  }

  void _openPropertyFeature(void Function(Map<String, dynamic> property) onSelect) {
    if (_properties.isEmpty) {
      final defaultBuilding = {
        'id': 'main_building',
        'name': 'Main Apartment Building',
        'unit_number': 'All Units',
        'tenant_name': 'Building Residents',
      };
      onSelect(defaultBuilding);
      return;
    }

    if (_properties.length == 1) {
      onSelect(_properties.first);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Property / Unit'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _properties.length,
              itemBuilder: (context, index) {
                final prop = _properties[index];
                return ListTile(
                  title: Text(prop['name']?.toString() ?? 'Property'),
                  subtitle: Text('Unit: ${prop['unit_number'] ?? 'N/A'}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect(prop);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caretaker Portal'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadCaretakerData,
          ),
          IconButton(
            tooltip: 'My Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCaretakerData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Caretaker Welcome Card
                  Card(
                    color: colors.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: colors.onTertiaryContainer,
                                child: Icon(Icons.engineering_outlined,
                                    color: colors.tertiaryContainer),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'On-Site Caretaker Hub',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: colors.onTertiaryContainer,
                                      ),
                                    ),
                                    Text(
                                      'Managing ${_properties.length} Properties & Units',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.onTertiaryContainer.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricBox(
                                  label: 'Open Maintenance',
                                  value: '$_openMaintenanceCount',
                                  color: colors.error,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricBox(
                                  label: 'Managed Properties',
                                  value: '${_properties.length}',
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Caretaker Work Modules',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  // Module Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _CaretakerTile(
                        icon: Icons.build_outlined,
                        title: 'Maintenance Requests',
                        badge: '$_openMaintenanceCount Open',
                        color: colors.error,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MaintenanceRequestsScreen(),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.report_problem_outlined,
                        title: 'Building Emergency Alert',
                        badge: 'Panic System',
                        color: Colors.red[800]!,
                        onTap: () {
                          _openPropertyFeature((p) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EmergencyAlertScreen(property: p),
                              ),
                            );
                          });
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.smart_toy_outlined,
                        title: 'AI Assistant',
                        badge: 'Smart Manager',
                        color: Colors.deepPurple[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiAssistantScreen(properties: _properties),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Property Expenses',
                        badge: 'Log Repair Expenses',
                        color: Colors.brown[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ExpenseTrackerScreen(),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.analytics_outlined,
                        title: 'Cashflow & P&L',
                        badge: 'Financial Analytics',
                        color: Colors.green[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FinancialAnalyticsScreen(),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.checklist_outlined,
                        title: 'Move Inspections',
                        badge: 'Checklists',
                        color: Colors.blue[800]!,
                        onTap: () {
                          _openPropertyFeature((p) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PropertyInspectionScreen(property: p),
                              ),
                            );
                          });
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.people_outline,
                        title: 'Tenant Directory',
                        badge: '${_properties.length} Tenants',
                        color: Colors.purple[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TenantDirectoryScreen(properties: _properties),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.key_outlined,
                        title: 'Key Inventory',
                        badge: 'Keys & Badges',
                        color: Colors.amber[900]!,
                        onTap: () {
                          _openPropertyFeature((p) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KeyManagementScreen(property: p),
                              ),
                            );
                          });
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.connect_without_contact_outlined,
                        title: 'Vendor Directory',
                        badge: 'On-Call Pros',
                        color: Colors.teal[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VendorDirectoryScreen(),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.local_post_office_outlined,
                        title: 'Gate Parcel Log',
                        badge: 'Deliveries',
                        color: Colors.deepOrange[800]!,
                        onTap: () {
                          _openPropertyFeature((p) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParcelLoggerScreen(property: p),
                              ),
                            );
                          });
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.cleaning_services_outlined,
                        title: 'Sanitation Routine',
                        badge: 'Cleaning Log',
                        color: Colors.lightGreen[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SanitationScheduleScreen(),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.campaign_outlined,
                        title: 'Notice Board',
                        badge: 'Announcements',
                        color: Colors.indigo[800]!,
                        onTap: () {
                          _openPropertyFeature((p) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnnouncementsScreen(
                                  property: p,
                                  userRole: 'caretaker',
                                ),
                              ),
                            );
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Maintenance Tickets',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MaintenanceRequestsScreen(),
                            ),
                          );
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_maintenanceRequests.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No maintenance tickets reported yet.'),
                        ),
                      ),
                    )
                  else
                    ..._maintenanceRequests.map((req) {
                      final status = req['status']?.toString() ?? 'Open';
                      final priority = req['priority']?.toString() ?? 'Medium';
                      final title = req['title']?.toString() ?? 'Maintenance Issue';
                      final desc = req['description']?.toString() ?? '';

                      Color pColor = Colors.orange;
                      if (priority == 'High') pColor = Colors.red;
                      if (priority == 'Low') pColor = Colors.blue;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: pColor.withValues(alpha: 0.2),
                            child: Icon(Icons.build_outlined, color: pColor, size: 20),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(desc.isNotEmpty ? desc : 'Priority: $priority'),
                          trailing: DropdownButton<String>(
                            value: ['Open', 'In Progress', 'Completed'].contains(status) ? status : 'Open',
                            underline: const SizedBox(),
                            items: ['Open', 'In Progress', 'Completed'].map((s) {
                              return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                            }).toList(),
                            onChanged: (newVal) {
                              if (newVal != null) _updateTicketStatus(req, newVal);
                            },
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CaretakerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;
  final Color color;
  final VoidCallback onTap;

  const _CaretakerTile({
    required this.icon,
    required this.title,
    required this.badge,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                badge,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
