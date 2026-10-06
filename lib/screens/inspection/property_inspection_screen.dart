import 'package:flutter/material.dart';
import '../../services/inspection_service.dart';

class PropertyInspectionScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const PropertyInspectionScreen({
    super.key,
    required this.property,
  });

  @override
  State<PropertyInspectionScreen> createState() =>
      _PropertyInspectionScreenState();
}

class _PropertyInspectionScreenState extends State<PropertyInspectionScreen> {
  final InspectionService _service = InspectionService.instance;
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _inspectionType = 'Move-In';
  late List<InspectionItem> _checklist;
  bool _isLoading = true;
  bool _isSaving = false;
  List<PropertyInspection> _history = [];

  @override
  void initState() {
    super.initState();
    _checklist = InspectionService.defaultChecklist();
    _depositController.text =
        (widget.property['monthly_rent']?.toString() ?? '0');
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history =
        await _service.loadInspections(widget.property['id'].toString());
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _depositController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _initialDeposit =>
      double.tryParse(_depositController.text.trim()) ?? 0.0;

  double get _totalDeductions =>
      _checklist.fold(0.0, (sum, item) => sum + item.repairCost);

  double get _netRefund {
    final net = _initialDeposit - _totalDeductions;
    return net < 0 ? 0.0 : net;
  }

  Future<void> _saveReport() async {
    setState(() => _isSaving = true);

    final inspection = PropertyInspection(
      id: '',
      propertyId: widget.property['id'].toString(),
      inspectionType: _inspectionType,
      inspectionDate: DateTime.now(),
      initialSecurityDeposit: _initialDeposit,
      items: _checklist,
      inspectorNotes: _notesController.text.trim(),
    );

    final success = await _service.saveInspection(inspection);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection report saved successfully!')),
      );
      _loadHistory();
    } else {
      // Local preview saved notification
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report recorded locally. (Will sync when online database table is created)',
          ),
        ),
      );
      setState(() {
        _history.insert(0, inspection);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currency = widget.property['currency']?.toString() ?? '\$';
    final propertyName =
        widget.property['name']?.toString() ?? 'Property Inspection';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$propertyName Checklist'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.assignment_outlined), text: 'New Inspection'),
              Tab(icon: Icon(Icons.history), text: 'Inspection History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: New Inspection
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inspection Configuration',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Move-In',
                                label: Text('Move-In Inspection'),
                                icon: Icon(Icons.login),
                              ),
                              ButtonSegment(
                                value: 'Move-Out',
                                label: Text('Move-Out Inspection'),
                                icon: Icon(Icons.logout),
                              ),
                            ],
                            selected: {_inspectionType},
                            onSelectionChanged: (set) {
                              setState(() {
                                _inspectionType = set.first;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _depositController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Initial Security Deposit ($currency)',
                              border: const OutlineInputBorder(),
                              prefixText: '$currency ',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Checklist Section
                  Text(
                    'Condition Checklist Items',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),

                  ..._checklist.map((item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.itemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _conditionColor(item.condition, colors),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item.condition,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: ['Good', 'Fair', 'Needs Repair', 'Damaged']
                                  .map((status) {
                                final isSelected = item.condition == status;
                                return ChoiceChip(
                                  label: Text(status),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        item.condition = status;
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            if (item.condition == 'Needs Repair' ||
                                item.condition == 'Damaged') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: item.repairCost > 0
                                          ? item.repairCost.toStringAsFixed(2)
                                          : '',
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Estimated Repair Deduction ($currency)',
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          item.repairCost =
                                              double.tryParse(val) ?? 0.0;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Security Deposit Calculation Summary
                  Card(
                    color: colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deposit Deduction Summary',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colors.onPrimaryContainer,
                                ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Initial Security Deposit:'),
                              Text('$currency ${_initialDeposit.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Repair Deductions:'),
                              Text(
                                '- $currency ${_totalDeductions.toStringAsFixed(2)}',
                                style: TextStyle(color: colors.error),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Net Refundable Deposit:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$currency ${_netRefund.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Inspector Notes / Comments',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveReport,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isSaving ? 'Saving...' : 'Save Inspection Report'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Tab 2: History
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? const Center(
                        child: Text('No previous inspection records found.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final report = _history[index];
                          final dateStr =
                              '${report.inspectionDate.year}-${report.inspectionDate.month.toString().padLeft(2, '0')}-${report.inspectionDate.day.toString().padLeft(2, '0')}';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                '${report.inspectionType} Inspection',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Date: $dateStr\n'
                                'Initial Deposit: $currency ${report.initialSecurityDeposit.toStringAsFixed(2)} | Deductions: $currency ${report.totalDeductions.toStringAsFixed(2)}\n'
                                'Net Refund: $currency ${report.netRefundAmount.toStringAsFixed(2)}',
                              ),
                              isThreeLine: true,
                              trailing: Icon(
                                report.inspectionType == 'Move-In'
                                    ? Icons.login
                                    : Icons.logout,
                                color: colors.primary,
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

  Color _conditionColor(String condition, ColorScheme colors) {
    switch (condition) {
      case 'Good':
        return colors.primaryContainer;
      case 'Fair':
        return colors.secondaryContainer;
      case 'Needs Repair':
        return colors.tertiaryContainer;
      case 'Damaged':
        return colors.errorContainer;
      default:
        return colors.surfaceContainerHighest;
    }
  }
}
