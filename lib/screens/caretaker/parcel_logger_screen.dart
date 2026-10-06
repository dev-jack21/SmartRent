import 'package:flutter/material.dart';
import '../../services/parcel_logger_service.dart';

class ParcelLoggerScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const ParcelLoggerScreen({
    super.key,
    required this.property,
  });

  @override
  State<ParcelLoggerScreen> createState() => _ParcelLoggerScreenState();
}

class _ParcelLoggerScreenState extends State<ParcelLoggerScreen> {
  final ParcelLoggerService _service = ParcelLoggerService.instance;

  final TextEditingController _tenantNameController = TextEditingController();
  final TextEditingController _courierController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<ParcelRecord> _parcels = [];

  @override
  void initState() {
    super.initState();
    _tenantNameController.text =
        widget.property['tenant_name']?.toString().trim() ?? '';
    _loadParcels();
  }

  Future<void> _loadParcels() async {
    setState(() => _isLoading = true);
    final list = await _service.loadParcels(widget.property['id'].toString());
    if (mounted) {
      setState(() {
        _parcels = list;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tenantNameController.dispose();
    _courierController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _logParcel() async {
    final name = _tenantNameController.text.trim();
    final courier = _courierController.text.trim();

    if (name.isEmpty || courier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant name and courier are required.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final record = ParcelRecord(
      id: '',
      propertyId: widget.property['id'].toString(),
      tenantName: name,
      courierName: courier,
      trackingOrCode: _codeController.text.trim(),
      receivedAt: DateTime.now(),
    );

    final success = await _service.saveParcel(record);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      _courierController.clear();
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parcel logged at gate/desk!')),
      );
      _loadParcels();
    } else {
      setState(() {
        _parcels.insert(0, record);
      });
      _courierController.clear();
      _codeController.clear();
    }
  }

  Future<void> _markCollected(ParcelRecord item) async {
    final updated = ParcelRecord(
      id: item.id,
      propertyId: item.propertyId,
      tenantName: item.tenantName,
      courierName: item.courierName,
      trackingOrCode: item.trackingOrCode,
      status: 'Collected',
      receivedAt: item.receivedAt,
      collectedAt: DateTime.now(),
    );

    await _service.saveParcel(updated);
    _loadParcels();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final propName = widget.property['name']?.toString() ?? 'Building';

    return Scaffold(
      appBar: AppBar(
        title: Text('$propName Parcels'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Log parcel card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Incoming Delivery at Gate / Desk',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tenantNameController,
                      decoration: const InputDecoration(
                        labelText: 'Recipient Tenant Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _courierController,
                            decoration: const InputDecoration(
                              labelText: 'Courier / Rider Name *',
                              hintText: 'e.g. DHL, Jumia, Rider',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.local_shipping),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            decoration: const InputDecoration(
                              labelText: 'Tracking / Code',
                              hintText: 'e.g. #9081',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _logParcel,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(_isSaving ? 'Logging...' : 'Log Parcel Arrival'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Parcels & Deliveries Log',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _parcels.isEmpty
                    ? const Center(child: Text('No deliveries logged yet.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _parcels.length,
                        itemBuilder: (context, index) {
                          final item = _parcels[index];
                          final isCollected = item.status == 'Collected';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isCollected
                                    ? colors.secondaryContainer
                                    : colors.primaryContainer,
                                child: Icon(
                                  isCollected
                                      ? Icons.mark_email_read
                                      : Icons.unarchive,
                                  color: isCollected
                                      ? colors.onSecondaryContainer
                                      : colors.onPrimaryContainer,
                                ),
                              ),
                              title: Text(
                                '${item.tenantName} (${item.courierName})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                isCollected
                                    ? 'Status: Collected by tenant'
                                    : 'Status: Waiting at caretaker desk',
                              ),
                              trailing: !isCollected
                                  ? OutlinedButton(
                                      onPressed: () => _markCollected(item),
                                      child: const Text('Mark Collected'),
                                    )
                                  : Chip(
                                      label: const Text('Collected'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
