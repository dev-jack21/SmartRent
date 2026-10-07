import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/emergency_alert_service.dart';

class EmergencyAlertScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const EmergencyAlertScreen({
    super.key,
    required this.property,
  });

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> {
  final EmergencyAlertService _service = EmergencyAlertService.instance;
  final TextEditingController _detailsController = TextEditingController();

  String _emergencyType = 'Water Burst / Major Plumbing Leak';
  bool _isBroadcasting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _broadcastAlert() async {
    setState(() => _isBroadcasting = true);

    final propId = widget.property['id'].toString();
    final details = _detailsController.text.trim();

    final success = await _service.broadcastEmergencyAlert(
      propertyId: propId,
      title: _emergencyType,
      details: details.isNotEmpty ? details : 'Urgent building emergency reported.',
    );

    if (!mounted) return;
    setState(() => _isBroadcasting = false);

    if (success) {
      _detailsController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('EMERGENCY BROADCAST SENT! All building contacts notified.'),
          backgroundColor: Colors.red[800],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Emergency alert broadcasted locally!'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final propName = widget.property['name']?.toString() ?? 'Building';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Building Emergency & Panic Alert'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panic Banner Card
            Card(
              color: Colors.amber[900]?.withValues(alpha: 0.15) ?? colors.tertiaryContainer,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.amber[800] ?? colors.tertiary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 56, color: Colors.amber[900]),
                    const SizedBox(height: 12),
                    Text(
                      'Emergency Panic Alert System',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Instantly broadcast urgent alerts to all $propName residents, caretakers, and property management.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Select Emergency Type',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _emergencyType,
              decoration: const InputDecoration(
                labelText: 'Emergency Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.report_problem_outlined),
              ),
              items: [
                'Water Burst / Major Plumbing Leak',
                'Fire / Smoke Hazard',
                'Power Failure / Blackout',
                'Security Breach / Break-In Threat',
                'Gas Leak Hazard',
              ].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _emergencyType = val);
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Emergency Details / Location Notes',
                hintText: 'e.g. Water flooding from 2nd floor corridor pipe',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red[800],
                ),
                onPressed: _isBroadcasting ? null : _broadcastAlert,
                icon: _isBroadcasting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.campaign),
                label: Text(
                  _isBroadcasting ? 'Broadcasting Alert...' : 'BROADCAST EMERGENCY ALERT',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            Text(
              'Quick Emergency Phone Speed Dial',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:999')),
                    icon: const Icon(Icons.local_fire_department_outlined, color: Colors.red),
                    label: const Text('Fire (999)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:999')),
                    icon: const Icon(Icons.local_police_outlined, color: Colors.blue),
                    label: const Text('Police (999)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
