import 'package:flutter/material.dart';
import '../../services/tenant_locker_service.dart';

class TenantLockerScreen extends StatefulWidget {
  const TenantLockerScreen({super.key});

  @override
  State<TenantLockerScreen> createState() => _TenantLockerScreenState();
}

class _TenantLockerScreenState extends State<TenantLockerScreen> {
  final TenantLockerService _service = TenantLockerService.instance;

  final TextEditingController _emergencyNameController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _idDetailsController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();
  final TextEditingController _parkingController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _service.loadLockerData();
    if (mounted) {
      setState(() {
        _emergencyNameController.text = data.emergencyContactName;
        _emergencyPhoneController.text = data.emergencyContactPhone;
        _idDetailsController.text = data.idTypeAndNumber;
        _insuranceController.text = data.insuranceDetails;
        _parkingController.text = data.parkingSpot;
        _vehicleController.text = data.vehiclePlate;
        _notesController.text = data.notes;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _idDetailsController.dispose();
    _insuranceController.dispose();
    _parkingController.dispose();
    _vehicleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    setState(() => _isSaving = true);

    final data = TenantLockerData(
      emergencyContactName: _emergencyNameController.text.trim(),
      emergencyContactPhone: _emergencyPhoneController.text.trim(),
      idTypeAndNumber: _idDetailsController.text.trim(),
      insuranceDetails: _insuranceController.text.trim(),
      parkingSpot: _parkingController.text.trim(),
      vehiclePlate: _vehicleController.text.trim(),
      notes: _notesController.text.trim(),
    );

    final success = await _service.saveLockerData(data);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document locker & vehicle registration saved!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved locally to your device!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Locker & Parking Info'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contact Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emergencyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Contact Name',
                      hintText: 'e.g. Jane Doe (Sister)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emergencyPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Phone Number',
                      hintText: 'e.g. +254 700 000 000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Parking & Vehicle Registration',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _parkingController,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Parking Bay',
                            hintText: 'e.g. Bay #12B',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.directions_car_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _vehicleController,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle License Plate',
                            hintText: 'e.g. KCD 123A',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Identity & Insurance Records',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _idDetailsController,
                    decoration: const InputDecoration(
                      labelText: 'Government ID / Passport Details',
                      hintText: 'e.g. National ID #12345678',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _insuranceController,
                    decoration: const InputDecoration(
                      labelText: 'Renter Insurance Policy Details',
                      hintText: 'e.g. Policy #POL-9901 (Allianz)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes / Rules Copy',
                      hintText: 'e.g. Meter reading location: Ground floor box #4',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveData,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_outline),
                      label: Text(_isSaving ? 'Saving...' : 'Save Locker Details'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
