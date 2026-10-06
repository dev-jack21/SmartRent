import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../announcements/announcements_screen.dart';
import '../inspection/property_inspection_screen.dart';
import '../maintenance/maintenance_requests_screen.dart';
import '../profile/user_profile_screen.dart';
import '../tenant/tenant_directory_screen.dart';
import '../utilities/utility_billing_screen.dart';
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

  bool _isLoading = true;
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _maintenanceRequests = [];

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
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select Building / Unit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _properties.map((p) {
                return ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: Text(p['name']?.toString() ?? 'Building'),
                  subtitle: Text('Unit: ${p['unit_number'] ?? 'All'} | Tenant: ${p['tenant_name'] ?? 'Vacant'}'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    onSelect(p);
                  },
                );
              }).toList(),
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
                        icon: Icons.handyman_outlined,
                        title: 'Maintenance Tickets',
                        badge: '$_openMaintenanceCount Pending',
                        color: Colors.orange[800]!,
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
                              builder: (_) => TenantDirectoryScreen(
                                properties: _properties,
                              ),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.campaign_outlined,
                        title: 'Notice Board',
                        badge: 'Announcements',
                        color: Colors.teal[800]!,
                        onTap: () {
                          _openPropertyFeature((p) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnnouncementsScreen(
                                  property: p,
                                  userRole: 'owner',
                                ),
                              ),
                            );
                          });
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.bolt_outlined,
                        title: 'Meter Readings',
                        badge: 'Utility Bills',
                        color: Colors.green[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UtilityBillingScreen(),
                            ),
                          );
                        },
                      ),
                      _CaretakerTile(
                        icon: Icons.key_outlined,
                        title: 'Key Inventory',
                        badge: 'Checkout Log',
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
                        icon: Icons.inventory_2_outlined,
                        title: 'Parcel Deliveries',
                        badge: 'Gate Log',
                        color: Colors.brown[700]!,
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
                        title: 'Sanitation & Cleaning',
                        badge: 'Routine',
                        color: Colors.cyan[800]!,
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
                        icon: Icons.handyman_outlined,
                        title: 'On-Call Vendors',
                        badge: 'Contractors',
                        color: Colors.deepOrange[800]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VendorDirectoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Recent Properties Quick Action List
                  Text(
                    'Building Units List',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  ..._properties.map((property) {
                    final name = property['name']?.toString() ?? 'Building Unit';
                    final tenant = property['tenant_name']?.toString().trim() ?? 'Vacant';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.home_outlined)),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Tenant: $tenant'),
                        trailing: OutlinedButton(
                          child: const Text('Inspect'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PropertyInspectionScreen(property: property),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
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
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                badge,
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
