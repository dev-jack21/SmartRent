import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddPropertyScreen extends StatefulWidget {
  final Map<String, dynamic>? property;

  const AddPropertyScreen({super.key, this.property});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _unitNumberController = TextEditingController();
  final _tenantNameController = TextEditingController();
  final _tenantEmailController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _rentController = TextEditingController();

  int _dueDay = 1;
  String _currency = 'KES';
  DateTime? _leaseStartDate;
  DateTime? _leaseEndDate;
  bool _isSaving = false;

  bool get _isEditing => widget.property != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final property = widget.property!;
      _nameController.text = property['name']?.toString() ?? '';
      _addressController.text = property['address']?.toString() ?? '';
      _unitNumberController.text = property['unit_number']?.toString() ?? '';
      _tenantNameController.text = property['tenant_name']?.toString() ?? '';
      _tenantEmailController.text = property['tenant_email']?.toString() ?? '';
      _tenantPhoneController.text = property['tenant_phone']?.toString() ?? '';
      _rentController.text = property['monthly_rent']?.toString() ?? '';
      _currency = property['currency']?.toString() ?? 'KES';
      _dueDay = int.tryParse(property['due_day']?.toString() ?? '') ?? 1;
      _leaseStartDate = DateTime.tryParse(
        property['lease_start_date']?.toString() ?? '',
      );
      _leaseEndDate = DateTime.tryParse(
        property['lease_end_date']?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _unitNumberController.dispose();
    _tenantNameController.dispose();
    _tenantEmailController.dispose();
    _tenantPhoneController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_leaseStartDate != null &&
        _leaseEndDate != null &&
        _leaseEndDate!.isBefore(_leaseStartDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lease end date must follow its start date.'),
        ),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not logged in. Please log in again.'),
        ),
      );
      return;
    }

    final rent = double.tryParse(_rentController.text.trim());

    if (rent == null || rent <= 0) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = {
        'user_id': user.id,
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'unit_number': _unitNumberController.text.trim(),
        'tenant_name': _tenantNameController.text.trim().isEmpty
            ? null
            : _tenantNameController.text.trim(),
        'tenant_email': _tenantEmailController.text.trim().isEmpty
            ? null
            : _tenantEmailController.text.trim().toLowerCase(),
        'tenant_phone': _tenantPhoneController.text.trim().isEmpty
            ? null
            : _tenantPhoneController.text.trim(),
        'monthly_rent': rent,
        'currency': _currency,
        'due_day': _dueDay,
        'lease_start_date': _leaseStartDate == null
            ? null
            : _dateOnly(_leaseStartDate!),
        'lease_end_date': _leaseEndDate == null
            ? null
            : _dateOnly(_leaseEndDate!),
      };

      if (_isEditing) {
        final propertyId = widget.property!['id'];

        await Supabase.instance.client
            .from('properties')
            .update(payload)
            .eq('id', propertyId)
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('properties').insert(payload);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Property updated successfully!'
                : 'Property saved successfully!',
          ),
        ),
      );

      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save property: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _pickLeaseDate({required bool isStartDate}) async {
    final currentDate = isStartDate ? _leaseStartDate : _leaseEndDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      if (isStartDate) {
        _leaseStartDate = pickedDate;
      } else {
        _leaseEndDate = pickedDate;
      }
    });
  }

  Widget _buildLeaseDateField({required bool isStartDate}) {
    final date = isStartDate ? _leaseStartDate : _leaseEndDate;
    final label = isStartDate ? 'Lease start date' : 'Lease end date';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pickLeaseDate(isStartDate: isStartDate),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '$label (optional)',
                prefixIcon: const Icon(Icons.event_outlined),
                border: const OutlineInputBorder(),
              ),
              child: Text(date == null ? 'Not set' : _formatDate(date)),
            ),
          ),
        ),
        if (date != null)
          IconButton(
            tooltip: 'Clear $label',
            onPressed: () {
              setState(() {
                if (isStartDate) {
                  _leaseStartDate = null;
                } else {
                  _leaseEndDate = null;
                }
              });
            },
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Property' : 'Add Property'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.home_work_outlined, size: 64),

                const SizedBox(height: 16),

                Text(
                  _isEditing
                      ? 'Update your rental property'
                      : 'Add a rental property',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  _isEditing
                      ? 'Adjust the property details below.'
                      : 'Enter the property details below.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Property name',
                    hintText: 'e.g. My Apartment',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a property name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressController,
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    hintText: 'e.g. Eldoret, Kenya',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _unitNumberController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Unit number',
                    hintText: 'e.g. A12',
                    prefixIcon: Icon(Icons.door_front_door_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the unit number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                Text(
                  'Tenant contact (optional)',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _tenantNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Tenant name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _tenantEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tenant email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isNotEmpty &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _tenantPhoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tenant phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 24),

                TextFormField(
                  controller: _rentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Monthly rent',
                    hintText: 'e.g. 15000',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the monthly rent';
                    }

                    final rent = double.tryParse(value.trim());

                    if (rent == null || rent <= 0) {
                      return 'Enter a valid rent amount';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    prefixIcon: Icon(Icons.currency_exchange),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'KES',
                      child: Text('KES - Kenyan Shilling'),
                    ),
                    DropdownMenuItem(
                      value: 'USD',
                      child: Text('USD - US Dollar'),
                    ),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                    DropdownMenuItem(
                      value: 'GBP',
                      child: Text('GBP - British Pound'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _currency = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'Rent due day',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<int>(
                  initialValue: _dueDay,
                  decoration: const InputDecoration(
                    labelText: 'Day of the month',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(31, (index) {
                    final day = index + 1;

                    return DropdownMenuItem<int>(
                      value: day,
                      child: Text('Day $day'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _dueDay = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 24),

                Text(
                  'Lease dates',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                _buildLeaseDateField(isStartDate: true),

                const SizedBox(height: 16),

                _buildLeaseDateField(isStartDate: false),

                const SizedBox(height: 32),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProperty,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving
                          ? (_isEditing ? 'Updating...' : 'Saving...')
                          : (_isEditing ? 'Update Property' : 'Save Property'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  _isEditing
                      ? 'Your changes will be saved to your account.'
                      : 'Your property will be saved securely to your account.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
