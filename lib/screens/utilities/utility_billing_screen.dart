import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/tenant_communication_service.dart';
import '../../services/utility_billing_service.dart';

class UtilityBillingScreen extends StatefulWidget {
  const UtilityBillingScreen({super.key});

  @override
  State<UtilityBillingScreen> createState() => _UtilityBillingScreenState();
}

class _UtilityBillingScreenState extends State<UtilityBillingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _utilityBills = [];
  String? _selectedPropertyFilter;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You are not logged in.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Map<String, dynamic>> loadedProperties = [];
      List<Map<String, dynamic>> loadedBills = [];

      try {
        final propResponse = await _supabase
            .from('properties')
            .select('id, name, unit_number, currency, tenant_name, tenant_phone')
            .order('name');
        loadedProperties = List<Map<String, dynamic>>.from(propResponse);
      } catch (_) {}

      try {
        final billResponse = await _supabase
            .from('utility_bills')
            .select(
              'id, property_id, utility_type, previous_reading, current_reading, rate_per_unit, total_amount, bill_month, status, notes, created_at',
            )
            .order('bill_month', ascending: false);
        loadedBills = List<Map<String, dynamic>>.from(billResponse);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _properties = loadedProperties;
        _utilityBills = loadedBills;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _toggleBillStatus(Map<String, dynamic> bill) async {
    final newStatus = bill['status'] == 'paid' ? 'unpaid' : 'paid';
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('utility_bills')
          .update({'status': newStatus})
          .eq('id', bill['id'])
          .eq('user_id', user.id);

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update bill status: $e')),
      );
    }
  }

  Future<void> _deleteBill(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('utility_bills')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utility bill deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete bill: $e')),
      );
    }
  }

  void _showAddBillDialog() {
    if (_properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a property before creating utility bills.')),
      );
      return;
    }

    String selectedPropId = _properties.first['id'].toString();
    String selectedType = UtilityBillingService.utilityTypes.first;
    final prevReadingCtrl = TextEditingController();
    final currReadingCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    final totalAmountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime billMonth = DateTime(DateTime.now().year, DateTime.now().month);

    void recalculateTotal() {
      final prev = double.tryParse(prevReadingCtrl.text.trim());
      final curr = double.tryParse(currReadingCtrl.text.trim());
      final rate = double.tryParse(rateCtrl.text.trim());
      final units = UtilityBillingService.instance.calculateUnitsConsumed(prev, curr);
      if (units > 0 && rate != null && rate > 0) {
        final total = UtilityBillingService.instance.calculateTotalCharge(
          unitsConsumed: units,
          ratePerUnit: rate,
        );
        totalAmountCtrl.text = total.toStringAsFixed(2);
      }
    }

    prevReadingCtrl.addListener(recalculateTotal);
    currReadingCtrl.addListener(recalculateTotal);
    rateCtrl.addListener(recalculateTotal);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Utility Bill'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedPropId,
                      decoration: const InputDecoration(
                        labelText: 'Property',
                        border: OutlineInputBorder(),
                      ),
                      items: _properties.map((p) {
                        final unit = p['unit_number']?.toString();
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text('${p['name']} ${unit != null && unit.isNotEmpty ? "($unit)" : ""}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedPropId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Utility Type',
                        border: OutlineInputBorder(),
                      ),
                      items: UtilityBillingService.utilityTypes.map((t) {
                        return DropdownMenuItem<String>(value: t, child: Text(t));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: prevReadingCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Prev Reading',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: currReadingCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Curr Reading',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Rate per Unit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: totalAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Total Bill Amount *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final total = double.tryParse(totalAmountCtrl.text.trim());
                    if (total == null || total <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid total amount.')),
                      );
                      return;
                    }

                    final user = _supabase.auth.currentUser;
                    if (user == null) return;

                    final prev = double.tryParse(prevReadingCtrl.text.trim());
                    final curr = double.tryParse(currReadingCtrl.text.trim());
                    final rate = double.tryParse(rateCtrl.text.trim());

                    final monthStr = '${billMonth.year}-${billMonth.month.toString().padLeft(2, '0')}-01';

                    try {
                      await _supabase.from('utility_bills').insert({
                        'user_id': user.id,
                        'property_id': selectedPropId,
                        'utility_type': selectedType,
                        'previous_reading': prev,
                        'current_reading': curr,
                        'rate_per_unit': rate,
                        'total_amount': total,
                        'bill_month': monthStr,
                        'status': 'unpaid',
                        'notes': notesCtrl.text.trim(),
                      });

                      if (!dialogCtx.mounted) return;
                      Navigator.pop(dialogCtx);
                      await _loadData();
                    } catch (e) {
                      if (!dialogCtx.mounted) return;
                      ScaffoldMessenger.of(dialogCtx).showSnackBar(
                        SnackBar(content: Text('Could not save bill: $e')),
                      );
                    }
                  },
                  child: const Text('Save Bill'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBills = _selectedPropertyFilter == null
        ? _utilityBills
        : _utilityBills
            .where((b) => b['property_id']?.toString() == _selectedPropertyFilter)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utility Bills & Meters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Property Filter
                    if (_properties.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedPropertyFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Property',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Properties'),
                            ),
                            ..._properties.map((p) {
                              final unit = p['unit_number']?.toString();
                              return DropdownMenuItem<String?>(
                                value: p['id'].toString(),
                                child: Text('${p['name']} ${unit != null && unit.isNotEmpty ? "($unit)" : ""}'),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedPropertyFilter = val),
                        ),
                      ),

                    Expanded(
                      child: filteredBills.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.speed_outlined, size: 56, color: Colors.grey),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No utility bills recorded',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Record meter readings and monthly bills for water, electricity, or trash.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredBills.length,
                              itemBuilder: (context, index) {
                                final bill = filteredBills[index];
                                final prop = _properties.firstWhere(
                                  (p) => p['id']?.toString() == bill['property_id']?.toString(),
                                  orElse: () => {'name': 'Property', 'currency': 'KES'},
                                );
                                final propName = prop['name']?.toString() ?? 'Property';
                                final unitNumber = prop['unit_number']?.toString();
                                final currency = prop['currency']?.toString() ?? 'KES';
                                final amount = double.tryParse(bill['total_amount']?.toString() ?? '0') ?? 0;
                                final isPaid = bill['status'] == 'paid';
                                final utilityType = bill['utility_type']?.toString() ?? 'Utility';
                                final billMonth = bill['bill_month']?.toString() ?? '';
                                final prevReading = double.tryParse(bill['previous_reading']?.toString() ?? '');
                                final currReading = double.tryParse(bill['current_reading']?.toString() ?? '');
                                final ratePerUnit = double.tryParse(bill['rate_per_unit']?.toString() ?? '');
                                final units = UtilityBillingService.instance.calculateUnitsConsumed(prevReading, currReading);
                                final tenantPhone = prop['tenant_phone']?.toString();
                                final tenantName = prop['tenant_name']?.toString();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '$propName ${unitNumber != null && unitNumber.isNotEmpty ? "($unitNumber)" : ""}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '$utilityType • Period: $billMonth',
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '$currency ${amount.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                            ),
                                          ],
                                        ),
                                        if (units > 0 && ratePerUnit != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Consumed: ${units.toStringAsFixed(1)} units (Prev: $prevReading, Curr: $currReading) @ $currency ${ratePerUnit.toStringAsFixed(2)}/unit',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          ),
                                        ],
                                        const Divider(height: 16),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () => _toggleBillStatus(bill),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isPaid ? Colors.green.shade300 : Colors.orange.shade300,
                                                  ),
                                                ),
                                                child: Text(
                                                  isPaid ? 'PAID' : 'UNPAID',
                                                  style: TextStyle(
                                                    color: isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (tenantPhone != null && tenantPhone.isNotEmpty)
                                              IconButton(
                                                tooltip: 'Send via WhatsApp',
                                                icon: const Icon(Icons.chat_outlined, color: Colors.green),
                                                onPressed: () {
                                                  final msg = UtilityBillingService.instance.buildUtilityBillNotificationMessage(
                                                    propertyName: propName,
                                                    unitNumber: unitNumber,
                                                    tenantName: tenantName,
                                                    utilityType: utilityType,
                                                    totalAmount: amount,
                                                    currency: currency,
                                                    billMonth: billMonth,
                                                    unitsConsumed: units > 0 ? units : null,
                                                    ratePerUnit: ratePerUnit,
                                                  );
                                                  TenantCommunicationService.instance.sendWhatsApp(phone: tenantPhone, message: msg);
                                                },
                                              ),
                                            IconButton(
                                              tooltip: 'Delete Bill',
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              onPressed: () => _deleteBill(bill['id'].toString()),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBillDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
    );
  }
}
