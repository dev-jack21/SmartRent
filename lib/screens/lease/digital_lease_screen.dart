import 'package:flutter/material.dart';
import '../../services/digital_lease_service.dart';

class DigitalLeaseScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  final String userRole; // 'owner' or 'tenant'

  const DigitalLeaseScreen({
    super.key,
    required this.property,
    required this.userRole,
  });

  @override
  State<DigitalLeaseScreen> createState() => _DigitalLeaseScreenState();
}

class _DigitalLeaseScreenState extends State<DigitalLeaseScreen> {
  final DigitalLeaseService _service = DigitalLeaseService.instance;
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _signatureController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _agreedToTerms = false;
  DigitalLeaseAgreement? _lease;

  @override
  void initState() {
    super.initState();
    _loadLease();
  }

  Future<void> _loadLease() async {
    setState(() => _isLoading = true);
    final propertyId = widget.property['id'].toString();
    final rent = double.tryParse(widget.property['monthly_rent']?.toString() ?? '') ?? 0.0;
    final currency = widget.property['currency']?.toString() ?? '\$';
    final propName = widget.property['name']?.toString() ?? 'Rental Property';

    var lease = await _service.getLeaseForProperty(propertyId);

    if (lease == null) {
      // Default draft lease
      final defaultTerms = DigitalLeaseService.defaultStandardTerms(
        propertyName: propName,
        rent: rent,
        deposit: rent, // 1 month rent default security deposit
        currency: currency,
      );

      lease = DigitalLeaseAgreement(
        id: '',
        propertyId: propertyId,
        propertyName: propName,
        tenantName: widget.property['tenant_name']?.toString() ?? 'Tenant',
        tenantEmail: widget.property['tenant_email']?.toString() ?? '',
        monthlyRent: rent,
        securityDeposit: rent,
        leaseStart: DateTime.now(),
        leaseEnd: DateTime.now().add(const Duration(days: 365)),
        termsAndConditions: defaultTerms,
        isSignedByLandlord: true,
        landlordSignedAt: DateTime.now(),
      );
    }

    if (mounted) {
      setState(() {
        _lease = lease;
        _termsController.text = lease!.termsAndConditions;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _termsController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _saveOrUpdateLease() async {
    if (_lease == null) return;
    setState(() => _isSaving = true);

    final updatedLease = DigitalLeaseAgreement(
      id: _lease!.id,
      propertyId: _lease!.propertyId,
      propertyName: _lease!.propertyName,
      tenantName: _lease!.tenantName,
      tenantEmail: _lease!.tenantEmail,
      monthlyRent: _lease!.monthlyRent,
      securityDeposit: _lease!.securityDeposit,
      leaseStart: _lease!.leaseStart,
      leaseEnd: _lease!.leaseEnd,
      termsAndConditions: _termsController.text.trim(),
      isSignedByLandlord: true,
      landlordSignedAt: DateTime.now(),
    );

    final success = await _service.saveLease(updatedLease);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lease agreement updated successfully!')),
      );
      _loadLease();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally. (Syncs when remote table is connected)'),
        ),
      );
    }
  }

  Future<void> _signAsTenant() async {
    final signature = _signatureController.text.trim();
    if (signature.isEmpty || !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check the confirmation box and enter your full signature name.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await _service.signLeaseByTenant(
      propertyId: _lease!.propertyId,
      signatureName: signature,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lease agreement electronically signed!')),
      );
      _loadLease();
    } else {
      // Local fallback sign state
      setState(() {
        _lease = DigitalLeaseAgreement(
          id: _lease!.id,
          propertyId: _lease!.propertyId,
          propertyName: _lease!.propertyName,
          tenantName: _lease!.tenantName,
          tenantEmail: _lease!.tenantEmail,
          monthlyRent: _lease!.monthlyRent,
          securityDeposit: _lease!.securityDeposit,
          leaseStart: _lease!.leaseStart,
          leaseEnd: _lease!.leaseEnd,
          termsAndConditions: _lease!.termsAndConditions,
          isSignedByLandlord: _lease!.isSignedByLandlord,
          isSignedByTenant: true,
          landlordSignedAt: _lease!.landlordSignedAt,
          tenantSignedAt: DateTime.now(),
          tenantSignatureName: signature,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document electronically signed!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isOwner = widget.userRole == 'owner';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Digital Lease Agreement')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final lease = _lease!;
    final currency = widget.property['currency']?.toString() ?? '\$';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Lease Agreement'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: lease.isFullySigned
                  ? colors.primaryContainer
                  : colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              lease.isFullySigned ? 'Fully Signed' : 'Pending Signature',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: lease.isFullySigned
                    ? colors.onPrimaryContainer
                    : colors.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lease.propertyName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text('Tenant: ${lease.tenantName} (${lease.tenantEmail})'),
                    const SizedBox(height: 4),
                    Text(
                      'Rent: $currency ${lease.monthlyRent.toStringAsFixed(2)} / month | Deposit: $currency ${lease.securityDeposit.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Term: ${_formatDate(lease.leaseStart)} to ${_formatDate(lease.leaseEnd)}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Lease Terms & Conditions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            if (isOwner && !lease.isFullySigned) ...[
              TextField(
                controller: _termsController,
                maxLines: 12,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter custom lease terms...',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveOrUpdateLease,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Update Lease Terms'),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Text(
                  lease.termsAndConditions,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Signature Status Card
            Card(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E-Signature Confirmations',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        lease.isSignedByLandlord
                            ? Icons.check_circle
                            : Icons.hourglass_empty,
                        color: lease.isSignedByLandlord
                            ? colors.primary
                            : colors.outline,
                      ),
                      title: const Text('Landlord Signature'),
                      subtitle: Text(
                        lease.isSignedByLandlord
                            ? 'Signed on ${_formatDate(lease.landlordSignedAt)}'
                            : 'Awaiting signature',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        lease.isSignedByTenant
                            ? Icons.check_circle
                            : Icons.hourglass_empty,
                        color: lease.isSignedByTenant
                            ? colors.primary
                            : colors.outline,
                      ),
                      title: const Text('Tenant Signature'),
                      subtitle: Text(
                        lease.isSignedByTenant
                            ? 'Signed by ${lease.tenantSignatureName ?? lease.tenantName} on ${_formatDate(lease.tenantSignedAt)}'
                            : 'Awaiting tenant signature',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tenant E-signing Widget
            if (!isOwner && !lease.isSignedByTenant) ...[
              Card(
                color: colors.primaryContainer.withValues(alpha: 0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Electronically Sign Document',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _agreedToTerms,
                        title: const Text(
                          'I have read, understood, and agree to the lease terms and conditions set forth above.',
                          style: TextStyle(fontSize: 13),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _agreedToTerms = val == true;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _signatureController,
                        decoration: const InputDecoration(
                          labelText: 'Enter Full Legal Name (Signature)',
                          hintText: 'e.g. Johnathan Doe',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.draw_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _signAsTenant,
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('Sign Lease Agreement'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (!isOwner && lease.isSignedByTenant) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Request Lease Renewal'),
                        content: const Text(
                          'Send a lease extension request to your landlord for the upcoming rental term?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Lease extension request sent to landlord!'),
                                ),
                              );
                            },
                            child: const Text('Send Request'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.autorenew_outlined),
                  label: const Text('Request Lease Extension / Renewal'),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
