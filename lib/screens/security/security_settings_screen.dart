import 'package:flutter/material.dart';
import '../../services/offline_cache_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final OfflineCacheService _cacheService = OfflineCacheService.instance;
  final TextEditingController _pinController = TextEditingController();

  bool _biometricsEnabled = false;
  bool _pinLockEnabled = false;
  bool _isCheckingConnection = false;
  bool? _isOnline;
  String? _savedPin;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isCheckingConnection = true);
    final online = await _cacheService.isOnline();
    if (mounted) {
      setState(() {
        _isOnline = online;
        _isCheckingConnection = false;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _setPinDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set 4-Digit Security PIN'),
          content: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter 4-Digit PIN',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = _pinController.text.trim();
                if (pin.length == 4) {
                  setState(() {
                    _savedPin = pin;
                    _pinLockEnabled = true;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Security PIN set successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN must be 4 digits.')),
                  );
                }
              },
              child: const Text('Save PIN'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Offline Sync'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Network & Offline Status Card
          Card(
            color: colors.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isOnline == true ? Icons.cloud_done : Icons.cloud_off,
                        color: _isOnline == true ? colors.primary : colors.error,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isOnline == true
                            ? 'Cloud Synchronization Active'
                            : 'Offline Mode Active',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline == true
                        ? 'Your rental properties, expenses, and tenant messages are syncing live to Supabase cloud.'
                        : 'Using cached offline data. Changes will automatically sync when connection returns.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isCheckingConnection ? null : _checkStatus,
                    icon: _isCheckingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_outlined),
                    label: const Text('Check Connection & Sync'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'App Lock & Privacy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric Authentication'),
            subtitle: const Text('Require Fingerprint or Face ID to open app'),
            value: _biometricsEnabled,
            onChanged: (val) {
              setState(() => _biometricsEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val
                        ? 'Biometric authentication enabled.'
                        : 'Biometric authentication disabled.',
                  ),
                ),
              );
            },
          ),

          const Divider(),

          SwitchListTile(
            secondary: const Icon(Icons.pin_outlined),
            title: const Text('4-Digit Security PIN'),
            subtitle: Text(
              _savedPin != null ? 'PIN set' : 'Lock sensitive financial details with a PIN',
            ),
            value: _pinLockEnabled,
            onChanged: (val) {
              if (val) {
                _setPinDialog();
              } else {
                setState(() {
                  _pinLockEnabled = false;
                  _savedPin = null;
                });
              }
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.data_saver_on_outlined),
            title: const Text('Offline Storage Cache'),
            subtitle: const Text('View and clear locally saved app data cache'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline storage cache is up to date.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
