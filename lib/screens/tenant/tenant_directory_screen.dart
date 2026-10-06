import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/tenant_communication_service.dart';
import '../chat/chat_screen.dart';
import '../lease/digital_lease_screen.dart';

class TenantDirectoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> properties;

  const TenantDirectoryScreen({
    super.key,
    required this.properties,
  });

  @override
  State<TenantDirectoryScreen> createState() => _TenantDirectoryScreenState();
}

class _TenantDirectoryScreenState extends State<TenantDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _tenants {
    final list = <Map<String, dynamic>>[];
    for (final p in widget.properties) {
      final name = p['tenant_name']?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        list.add({
          'tenant_name': name,
          'tenant_email': p['tenant_email']?.toString().trim() ?? '',
          'tenant_phone': p['tenant_phone']?.toString().trim() ?? '',
          'property': p,
        });
      }
    }
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((t) {
      final name = t['tenant_name'].toString().toLowerCase();
      final email = t['tenant_email'].toString().toLowerCase();
      final phone = t['tenant_phone'].toString().toLowerCase();
      final propName = (t['property']['name'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q) || propName.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tenants = _tenants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Directory'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tenants by name, property, or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),

          // List
          Expanded(
            child: tenants.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: colors.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No tenants matching "$_searchQuery"'
                                : 'No tenants linked to properties yet',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Edit your properties to assign tenant names, emails, and phone numbers.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tenants.length,
                    itemBuilder: (context, index) {
                      final item = tenants[index];
                      final name = item['tenant_name'] as String;
                      final email = item['tenant_email'] as String;
                      final phone = item['tenant_phone'] as String;
                      final property = item['property'] as Map<String, dynamic>;
                      final propName = property['name']?.toString() ?? 'Property';
                      final unit = property['unit_number']?.toString().trim() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colors.primaryContainer,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                      style: TextStyle(
                                        color: colors.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '$propName${unit.isNotEmpty ? ' (Unit $unit)' : ''}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colors.onSurface.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              if (email.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, size: 16),
                                    const SizedBox(width: 8),
                                    Text(email, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (phone.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 16),
                                    const SizedBox(width: 8),
                                    Text(phone, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                              // Actions
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                                    label: const Text('Chat'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            propertyId: property['id'].toString(),
                                            propertyName: propName,
                                            counterpartyName: name,
                                            currentUserRole: 'owner',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (phone.isNotEmpty) ...[
                                    ActionChip(
                                      avatar: const Icon(Icons.call_outlined, size: 16),
                                      label: const Text('Call'),
                                      onPressed: () {
                                        launchUrl(Uri.parse('tel:$phone'));
                                      },
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.chat, size: 16, color: Colors.green),
                                      label: const Text('WhatsApp'),
                                      onPressed: () {
                                        TenantCommunicationService.instance.sendWhatsApp(
                                          phone: phone,
                                          message: 'Hello $name, regarding $propName...',
                                        );
                                      },
                                    ),
                                  ],
                                  ActionChip(
                                    avatar: const Icon(Icons.draw_outlined, size: 16),
                                    label: const Text('Digital Lease'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DigitalLeaseScreen(
                                            property: property,
                                            userRole: 'owner',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
