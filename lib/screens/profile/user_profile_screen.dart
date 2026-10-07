import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/theme_service.dart';
import '../security/security_settings_screen.dart';
import '../tenant/tenant_locker_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _userEmail = '';
  String _userRole = 'user';
  String _selectedCurrency = 'KES';
  String? _avatarUrl;
  Uint8List? _avatarBytes;

  final List<Map<String, String>> _avatarPresets = const [
    {'icon': '🏢', 'label': 'Manager'},
    {'icon': '🔑', 'label': 'Key Master'},
    {'icon': '👑', 'label': 'Owner'},
    {'icon': '🏠', 'label': 'Home'},
    {'icon': '🛡️', 'label': 'Verified'},
    {'icon': '⭐', 'label': 'Gold Star'},
    {'icon': '😊', 'label': 'Friendly'},
    {'icon': '🛠️', 'label': 'Caretaker Pro'},
    {'icon': '💼', 'label': 'Executive'},
    {'icon': '👤', 'label': 'Classic'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _userEmail = user.email ?? '';
    _userRole = user.userMetadata?['account_type']?.toString() ??
        user.userMetadata?['account_role']?.toString() ??
        'User';
    _selectedCurrency = user.userMetadata?['currency']?.toString() ?? 'KES';
    _avatarUrl = user.userMetadata?['avatar_url']?.toString();

    if (_avatarUrl != null && _avatarUrl!.contains('base64,')) {
      try {
        final base64Str = _avatarUrl!.split('base64,').last;
        _avatarBytes = base64Decode(base64Str);
      } catch (_) {}
    }

    _nameController.text =
        user.userMetadata?['full_name']?.toString() ?? 'User';
    _phoneController.text =
        user.userMetadata?['phone']?.toString() ?? '';

    setState(() => _isLoading = false);
  }

  void _showAvatarChooserSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Profile Icon / Avatar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Choose a preset avatar icon or upload a custom photo:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: _avatarPresets.length,
                    itemBuilder: (context, index) {
                      final preset = _avatarPresets[index];
                      final icon = preset['icon']!;
                      final isSelected = _avatarUrl == 'preset:$icon';

                      return InkWell(
                        onTap: () async {
                          Navigator.pop(ctx);
                          setState(() {
                            _avatarUrl = 'preset:$icon';
                            _avatarBytes = null;
                          });
                          await _supabase.auth.updateUser(
                            UserAttributes(data: {'avatar_url': 'preset:$icon'}),
                          );
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Profile icon set to ${preset['label']}!')),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(icon, style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickDevicePhoto();
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Upload Custom Photo'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDevicePhoto() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result.isNotEmpty) {
        final file = result.first;
        final path = file.path;

        if (path != null && path.isNotEmpty) {
          Uint8List? bytes;
          try {
            final fileObj = File(path);
            if (fileObj.existsSync()) {
              bytes = await fileObj.readAsBytes();
            }
          } catch (_) {}

          final photoUrl = bytes != null
              ? 'data:image/png;base64,${base64Encode(bytes)}'
              : path;

          setState(() {
            _avatarBytes = bytes;
            _avatarUrl = photoUrl;
          });

          await _supabase.auth.updateUser(
            UserAttributes(data: {'avatar_url': photoUrl}),
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile picture: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': name,
            'phone': _phoneController.text.trim(),
            'currency': _selectedCurrency,
          },
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_userEmail.isEmpty) return;

    try {
      await _supabase.auth.resetPasswordForEmail(_userEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $_userEmail')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending reset link: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _buildAvatarWidget(ColorScheme colors) {
    if (_avatarUrl != null && _avatarUrl!.startsWith('preset:')) {
      final emoji = _avatarUrl!.replaceFirst('preset:', '');
      return Text(emoji, style: const TextStyle(fontSize: 40));
    }

    if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
      return CircleAvatar(
        radius: 44,
        backgroundImage: MemoryImage(_avatarBytes!),
      );
    }

    return Text(
      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'U',
      style: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: colors.onPrimaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final roleTitle = _userRole == 'owner' || _userRole == 'landlord'
        ? 'Property Owner / Manager'
        : 'Tenant';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile & Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Profile Avatar Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: colors.primaryContainer,
                                child: _buildAvatarWidget(colors),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Material(
                                  elevation: 3,
                                  shape: const CircleBorder(),
                                  color: colors.primary,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _showAvatarChooserSheet,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _nameController.text,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userEmail,
                            style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 8),
                          Chip(
                            avatar: const Icon(Icons.badge_outlined, size: 16),
                            label: Text(roleTitle),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Edit Personal Info',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Global Preferred Currency',
                      prefixIcon: Icon(Icons.currency_exchange),
                      border: OutlineInputBorder(),
                    ),
                    items: ['KES', 'USD', 'EUR', 'GBP', 'ZAR', 'INR', 'UGX', 'TZS']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCurrency = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _updateProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSaving ? 'Saving...' : 'Update Info'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Security & Preferences',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeService.instance,
                    builder: (context, mode, _) {
                      final isDark = ThemeService.instance.isDarkMode;
                      return SwitchListTile(
                        secondary: Icon(
                          isDark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                        ),
                        title: const Text('Dark Mode Theme'),
                        subtitle: Text(
                          isDark ? 'Dark theme active' : 'Light theme active',
                        ),
                        value: isDark,
                        onChanged: (_) {
                          ThemeService.instance.toggleTheme();
                        },
                      );
                    },
                  ),
                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('Security & Offline Sync'),
                    subtitle: const Text('Set 4-digit PIN lock & Biometrics'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecuritySettingsScreen(),
                        ),
                      );
                    },
                  ),

                  if (_userRole == 'tenant') ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.lock_outlined),
                      title: const Text('Document Locker & Emergency Contacts'),
                      subtitle: const Text('ID proofs, insurance, and emergency info'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TenantLockerScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.lock_reset_outlined),
                    title: const Text('Change Password'),
                    subtitle: const Text('Send password reset email link'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _resetPassword,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                      ),
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Log Out'),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
