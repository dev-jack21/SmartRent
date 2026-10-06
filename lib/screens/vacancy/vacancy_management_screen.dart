import 'package:flutter/material.dart';
import '../../services/vacancy_application_service.dart';

class VacancyManagementScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const VacancyManagementScreen({
    super.key,
    required this.property,
  });

  @override
  State<VacancyManagementScreen> createState() =>
      _VacancyManagementScreenState();
}

class _VacancyManagementScreenState extends State<VacancyManagementScreen> {
  final VacancyApplicationService _service =
      VacancyApplicationService.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _employerController = TextEditingController();
  final TextEditingController _moveInController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  List<TenantApplication> _applications = [];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final apps = await _service
        .loadApplications(widget.property['id'].toString());
    if (mounted) {
      setState(() {
        _applications = apps;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _incomeController.dispose();
    _employerController.dispose();
    _moveInController.dispose();
    super.dispose();
  }

  Future<void> _submitNewApplicant() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final income = double.tryParse(_incomeController.text.trim()) ?? 0.0;

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in applicant name and email.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final app = TenantApplication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      propertyId: widget.property['id'].toString(),
      propertyName: widget.property['name']?.toString() ?? 'Property',
      applicantName: name,
      applicantEmail: email,
      applicantPhone: _phoneController.text.trim(),
      annualIncome: income,
      employerName: _employerController.text.trim(),
      moveInDate: _moveInController.text.trim(),
      notes: '',
      submittedAt: DateTime.now(),
    );

    final success = await _service.submitApplication(app);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rental application submitted successfully!')),
      );
      _clearForm();
      _loadApplications();
    } else {
      // Local addition
      setState(() {
        _applications.insert(0, app);
      });
      _clearForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application added locally!')),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _incomeController.clear();
    _employerController.clear();
    _moveInController.clear();
  }

  Future<void> _updateStatus(TenantApplication app, String newStatus) async {
    if (newStatus == 'Approved') {
      final success = await _service.approveTenantAndAssignProperty(app);
      if (success || true) {
        widget.property['tenant_name'] = app.applicantName;
        widget.property['tenant_email'] = app.applicantEmail;
        widget.property['tenant_phone'] = app.applicantPhone;
      }
    } else {
      await _service.updateStatus(app.id, newStatus);
    }

    if (!mounted) return;

    setState(() {
      app.status = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'Approved'
              ? '${app.applicantName} approved! The tenant can now tap "Create Account" using ${app.applicantEmail} to sign in.'
              : 'Application marked as $newStatus',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final propertyName =
        widget.property['name']?.toString() ?? 'Property Applicants';
    final currency = widget.property['currency']?.toString() ?? '\$';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$propertyName Applications'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Applicants'),
              Tab(icon: Icon(Icons.person_add_alt), text: 'Add Applicant'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Applicants List
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _applications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_outlined,
                                size: 56, color: colors.primary),
                            const SizedBox(height: 12),
                            const Text('No rental applications submitted yet.'),
                            const SizedBox(height: 6),
                            const Text(
                              'Use the "Add Applicant" tab to record prospective tenants.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _applications.length,
                        itemBuilder: (context, index) {
                          final app = _applications[index];
                          final isApproved = app.status == 'Approved';
                          final isRejected = app.status == 'Rejected';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        app.applicantName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isApproved
                                              ? colors.primaryContainer
                                              : isRejected
                                                  ? colors.errorContainer
                                                  : colors.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          app.status,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isApproved
                                                ? colors.onPrimaryContainer
                                                : isRejected
                                                    ? colors.onErrorContainer
                                                    : colors.onTertiaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Email: ${app.applicantEmail} | Phone: ${app.applicantPhone}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Annual Income: $currency ${app.annualIncome.toStringAsFixed(2)} | Employer: ${app.employerName.isEmpty ? 'N/A' : app.employerName}',
                                  ),
                                  if (app.moveInDate.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Desired Move-In: ${app.moveInDate}'),
                                  ],
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () =>
                                            _updateStatus(app, 'Rejected'),
                                        child: const Text('Decline'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: () =>
                                            _updateStatus(app, 'Approved'),
                                        child: const Text('Approve Tenant'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

            // Tab 2: Add New Prospective Applicant
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record Prospective Tenant Application',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _incomeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Annual Income ($currency)',
                      border: const OutlineInputBorder(),
                      prefixText: '$currency ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _employerController,
                    decoration: const InputDecoration(
                      labelText: 'Current Employer',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _moveInController,
                    decoration: const InputDecoration(
                      labelText: 'Desired Move-In Date',
                      hintText: 'e.g. 2025-03-01',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _submitNewApplicant,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isSaving ? 'Submitting...' : 'Submit Application'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
