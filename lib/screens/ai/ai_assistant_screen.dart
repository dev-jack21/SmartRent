import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ai_property_assistant_service.dart';

class AiAssistantScreen extends StatefulWidget {
  final List<Map<String, dynamic>> properties;

  const AiAssistantScreen({
    super.key,
    required this.properties,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final AiPropertyAssistantService _ai = AiPropertyAssistantService.instance;
  final TextEditingController _queryController = TextEditingController();

  String? _selectedPropertyId;
  String _aiOutput = '';

  @override
  void initState() {
    super.initState();
    if (widget.properties.isNotEmpty) {
      _selectedPropertyId = widget.properties.first['id'].toString();
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _selectedProperty {
    if (_selectedPropertyId == null || widget.properties.isEmpty) return {};
    return widget.properties.firstWhere(
      (p) => p['id'].toString() == _selectedPropertyId,
      orElse: () => widget.properties.first,
    );
  }

  void _draftReminder() {
    final p = _selectedProperty;
    final rent = double.tryParse(p['monthly_rent']?.toString() ?? '') ?? 0.0;
    final text = _ai.generatePoliteRentReminder(
      tenantName: p['tenant_name']?.toString() ?? '',
      propertyName: p['name']?.toString() ?? 'Property',
      amount: rent,
      currency: p['currency']?.toString() ?? 'KES',
      dueDate: DateTime.now(),
    );
    setState(() => _aiOutput = text);
  }

  void _draftRenewal() {
    final p = _selectedProperty;
    final rent = double.tryParse(p['monthly_rent']?.toString() ?? '') ?? 0.0;
    final text = _ai.generateLeaseRenewalProposal(
      tenantName: p['tenant_name']?.toString() ?? '',
      propertyName: p['name']?.toString() ?? 'Property',
      currentRent: rent,
      proposedRent: rent * 1.05, // 5% rent adjustment
      currency: p['currency']?.toString() ?? 'KES',
      newLeaseEnd: DateTime.now().add(const Duration(days: 365)),
    );
    setState(() => _aiOutput = text);
  }

  void _askAi() {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;
    final ans = _ai.answerPropertyQuery(q);
    setState(() => _aiOutput = ans);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Property Manager Assistant'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Selection Dropdown
            if (widget.properties.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedPropertyId,
                decoration: const InputDecoration(
                  labelText: 'Select Target Property / Unit',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home),
                ),
                items: widget.properties
                    .map((p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text(p['name']?.toString() ?? 'Property'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPropertyId = val);
                },
              ),
              const SizedBox(height: 16),
            ],

            // Quick AI Action Prompts
            Text(
              'Quick AI Generator Templates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Draft Polite Rent Reminder'),
                  onPressed: _draftReminder,
                ),
                ActionChip(
                  avatar: const Icon(Icons.autorenew_outlined, size: 16),
                  label: const Text('Draft Lease Renewal Proposal'),
                  onPressed: _draftRenewal,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Ask AI Assistant Query Field
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'Ask AI Property Manager Question',
                hintText: 'e.g. How to handle security deposit deductions?',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _askAi,
                ),
              ),
              onSubmitted: (_) => _askAi(),
            ),

            const SizedBox(height: 20),

            // Output Display Card
            if (_aiOutput.isNotEmpty) ...[
              Card(
                color: colors.primaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.smart_toy_outlined),
                              SizedBox(width: 8),
                              Text('AI Generated Output', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Copy Output',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _aiOutput));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('AI response copied to clipboard!')),
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        _aiOutput,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
