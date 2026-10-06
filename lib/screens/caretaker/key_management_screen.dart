import 'package:flutter/material.dart';
import '../../services/key_management_service.dart';

class KeyManagementScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const KeyManagementScreen({
    super.key,
    required this.property,
  });

  @override
  State<KeyManagementScreen> createState() => _KeyManagementScreenState();
}

class _KeyManagementScreenState extends State<KeyManagementScreen> {
  final KeyManagementService _service = KeyManagementService.instance;

  final TextEditingController _keyTagController = TextEditingController();
  final TextEditingController _checkoutController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<KeyRecord> _keys = [];

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() => _isLoading = true);
    final list = await _service.loadKeys(widget.property['id'].toString());
    if (mounted) {
      setState(() {
        _keys = list;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _keyTagController.dispose();
    _checkoutController.dispose();
    super.dispose();
  }

  Future<void> _addKey() async {
    final tag = _keyTagController.text.trim();
    if (tag.isEmpty) return;

    setState(() => _isSaving = true);

    final record = KeyRecord(
      id: '',
      propertyId: widget.property['id'].toString(),
      keyTag: tag,
      status: 'In Custody',
    );

    final success = await _service.saveKey(record);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      _keyTagController.clear();
      _loadKeys();
    } else {
      setState(() {
        _keys.add(record);
      });
      _keyTagController.clear();
    }
  }

  Future<void> _toggleKeyStatus(KeyRecord key) async {
    final isCheckedOut = key.status == 'Checked Out';
    final newStatus = isCheckedOut ? 'In Custody' : 'Checked Out';

    String recipient = key.checkedOutTo;

    if (!isCheckedOut) {
      // Checkout prompt
      recipient = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Key Checkout Details'),
              content: TextField(
                controller: _checkoutController,
                decoration: const InputDecoration(
                  labelText: 'Checked out to (Name / Contractor)',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, _checkoutController.text.trim()),
                  child: const Text('Confirm Checkout'),
                ),
              ],
            ),
          ) ??
          '';
      _checkoutController.clear();

      if (recipient.isEmpty) return;
    }

    final updated = KeyRecord(
      id: key.id,
      propertyId: key.propertyId,
      keyTag: key.keyTag,
      status: newStatus,
      checkedOutTo: newStatus == 'Checked Out' ? recipient : '',
      checkedOutAt: newStatus == 'Checked Out' ? DateTime.now() : null,
    );

    await _service.saveKey(updated);
    _loadKeys();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final propName = widget.property['name']?.toString() ?? 'Building';

    return Scaffold(
      appBar: AppBar(
        title: Text('$propName Keys'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add key card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Register Key Tag / Access Badge',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _keyTagController,
                            decoration: const InputDecoration(
                              labelText: 'Key Tag / Badge Name',
                              hintText: 'e.g. Unit 3B Spare Key #2',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _addKey,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Key'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Key Inventory & Checkout Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _keys.isEmpty
                    ? const Center(child: Text('No keys registered in inventory yet.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _keys.length,
                        itemBuilder: (context, index) {
                          final item = _keys[index];
                          final isOut = item.status == 'Checked Out';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isOut
                                    ? colors.errorContainer
                                    : colors.primaryContainer,
                                child: Icon(
                                  isOut ? Icons.key_off : Icons.key,
                                  color: isOut
                                      ? colors.onErrorContainer
                                      : colors.onPrimaryContainer,
                                ),
                              ),
                              title: Text(
                                item.keyTag,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                isOut
                                    ? 'Checked out to: ${item.checkedOutTo}'
                                    : 'In Custody (Safe at Desk)',
                              ),
                              trailing: OutlinedButton(
                                onPressed: () => _toggleKeyStatus(item),
                                child: Text(isOut ? 'Return Key' : 'Check Out'),
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
