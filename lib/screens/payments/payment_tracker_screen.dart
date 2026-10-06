import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/monthly_rent_report.dart';
import '../../services/rent_credit_ledger.dart';

class PaymentTrackerScreen extends StatefulWidget {
  final String? propertyId;
  final DateTime? rentMonth;
  final bool closeAfterSave;

  const PaymentTrackerScreen({
    super.key,
    this.propertyId,
    this.rentMonth,
    this.closeAfterSave = false,
  });

  @override
  State<PaymentTrackerScreen> createState() => _PaymentTrackerScreenState();
}

class _PaymentTrackerScreenState extends State<PaymentTrackerScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _creditAllocations = [];
  List<Map<String, dynamic>> _expenses = [];

  String? _selectedPropertyId;
  String? _creditAllocationLoadError;
  String? _expenseLoadError;
  DateTime _paidDate = DateTime.now();
  DateTime _rentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _reportMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _status = 'paid';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExportingReport = false;

  static const Map<String, String> _statuses = {
    'pending': 'Pending',
    'paid': 'Paid',
    'overdue': 'Overdue',
  };

  @override
  void initState() {
    super.initState();
    _selectedPropertyId = widget.propertyId;
    if (widget.rentMonth != null) {
      _rentMonth = DateTime(widget.rentMonth!.year, widget.rentMonth!.month);
    }
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final propertiesResponse = await _supabase
          .from('properties')
          .select(
            'id, name, address, unit_number, tenant_name, tenant_email, monthly_rent, currency, due_day',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final paymentsResponse = await _supabase
          .from('payments')
          .select(
            'id, property_id, amount, status, payment_date, rent_month, notes',
          )
          .eq('user_id', user.id)
          .order('payment_date', ascending: false);

      List<Map<String, dynamic>> expenses = [];
      String? expenseLoadError;
      try {
        final expensesResponse = await _supabase
            .from('property_expenses')
            .select(
              'property_id, amount, category, expense_date, paid_date, status, notes',
            )
            .eq('user_id', user.id)
            .order('expense_date', ascending: false);
        expenses = List<Map<String, dynamic>>.from(expensesResponse);
      } catch (error) {
        expenseLoadError = error.toString();
      }

      List<Map<String, dynamic>> creditAllocations = [];
      String? creditAllocationLoadError;
      try {
        final allocationResponse = await _supabase
            .from('rent_credit_allocations')
            .select('property_id, source_month, target_month, amount')
            .eq('user_id', user.id);
        creditAllocations = List<Map<String, dynamic>>.from(allocationResponse);
      } catch (error) {
        creditAllocationLoadError = error.toString();
      }

      if (!mounted) return;

      final loadedProperties = List<Map<String, dynamic>>.from(
        propertiesResponse,
      );
      final loadedPayments = List<Map<String, dynamic>>.from(paymentsResponse);

      setState(() {
        _properties = loadedProperties;
        _payments = loadedPayments;
        _creditAllocations = creditAllocations;
        _expenses = expenses;
        _expenseLoadError = expenseLoadError;
        _creditAllocationLoadError = creditAllocationLoadError;
        _selectedPropertyId =
            loadedProperties.any(
              (property) => property['id'].toString() == widget.propertyId,
            )
            ? widget.propertyId
            : loadedProperties.isNotEmpty
            ? loadedProperties.first['id'].toString()
            : null;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load payments: ${error.message}')),
      );
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $error')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property first.')),
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are not logged in.')));
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final savedPayment = {
        'user_id': user.id,
        'property_id': _selectedPropertyId,
        'amount': amount,
        'payment_date': _paidDate.toIso8601String(),
        'rent_month':
            '${_rentMonth.year}-${_rentMonth.month.toString().padLeft(2, '0')}-01',
        'status': _status,
        'notes': _notesController.text.trim(),
      };
      await _supabase.from('payments').insert(savedPayment);

      if (!mounted) return;

      _amountController.clear();
      _notesController.clear();
      setState(() {
        _status = 'paid';
        _paidDate = DateTime.now();
      });

      await _loadData();

      if (!mounted) return;

      if (widget.closeAfterSave) {
        final property = _properties.firstWhere(
          (item) => item['id'].toString() == _selectedPropertyId,
          orElse: () => <String, dynamic>{},
        );
        final tenantEmail = property['tenant_email']?.toString().trim() ?? '';

        if (savedPayment['status'] == 'paid' && tenantEmail.isNotEmpty) {
          final sendReceipt = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Email payment receipt?'),
              content: Text('Prepare a receipt for $tenantEmail to review.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Prepare email'),
                ),
              ],
            ),
          );

          if (!mounted) return;
          if (sendReceipt == true) {
            await _emailPaymentReceipt(savedPayment);
          }
        }

        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment saved successfully.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save payment: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save payment: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _paidDate = picked;
      });
    }
  }

  Future<void> _pickRentMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rentMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'SELECT RENT MONTH',
    );

    if (picked != null) {
      setState(() {
        _rentMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  Future<void> _pickReportMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'SELECT REPORT MONTH',
    );

    if (picked != null && mounted) {
      setState(() {
        _reportMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  List<MonthlyPropertyReport> _getMonthlyReport() {
    return MonthlyRentReport.build(
      properties: _properties,
      payments: _payments,
      allocations: _creditAllocations,
      expenses: _expenses,
      month: _reportMonth,
    );
  }

  Future<void> _exportMonthlyReport() async {
    if (_properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a property before exporting a report.')),
      );
      return;
    }
    if (_expenseLoadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot export a complete report until expense data is available. Apply the property expenses migration, then refresh.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isExportingReport = true;
    });

    try {
      final csv = MonthlyRentReport.toCsv(
        month: _reportMonth,
        reports: _getMonthlyReport(),
      );
      final monthPart =
          '${_reportMonth.year}-${_reportMonth.month.toString().padLeft(2, '0')}';
      await FileSaver.instance.saveFile(
        name: 'rent-report-$monthPart',
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly rent report exported.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export monthly report: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExportingReport = false;
        });
      }
    }
  }

  Widget _buildMonthlyReportCard(MonthlyPropertyReport report) {
    final property = report.property;
    final entry = report.ledgerEntry;
    final currency = property['currency']?.toString() ?? 'KES';
    final tenantName = property['tenant_name']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(property['name']?.toString() ?? 'Property'),
        subtitle: Text(
          '${tenantName.isEmpty ? 'No tenant name' : tenantName} • ${_formatRentMonth(_reportMonth)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _ReportAmountRow(
            label: 'Monthly rent',
            amount: entry.rent,
            currency: currency,
          ),
          _ReportAmountRow(
            label: 'Cash received',
            amount: entry.cashReceived,
            currency: currency,
          ),
          _ReportAmountRow(
            label: 'Pending payments',
            amount: report.pendingAmount,
            currency: currency,
          ),
          _ReportAmountRow(
            label: 'Expenses',
            amount: report.expensesAmount,
            currency: currency,
          ),
          _ReportAmountRow(
            label: 'Planned expenses',
            amount: report.plannedExpensesAmount,
            currency: currency,
          ),
          _ReportAmountRow(
            label: 'Net cash flow',
            amount: report.netCashFlow,
            currency: currency,
          ),
          _ReportAmountRow(
            label: 'Remaining balance',
            amount: entry.amountOwing,
            currency: currency,
          ),
          if (entry.creditApplied > 0)
            _ReportAmountRow(
              label: 'Credit applied',
              amount: entry.creditApplied,
              currency: currency,
            ),
          if (entry.availableCredit > 0)
            _ReportAmountRow(
              label: 'Available credit',
              amount: entry.availableCredit,
              currency: currency,
            ),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Expense details',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (report.expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No expenses recorded for this month.'),
              ),
            )
          else
            ...report.expenses.map((expense) {
              final date = DateTime.tryParse(
                (expense['status'] == 'paid'
                        ? expense['paid_date'] ?? expense['expense_date']
                        : expense['expense_date'])
                    ?.toString() ??
                    '',
              );
              final amount =
                  double.tryParse(expense['amount']?.toString() ?? '') ?? 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${expense['category']?.toString() ?? 'Other'} • ${expense['status'] == 'planned' ? 'Planned' : 'Paid'}',
                ),
                subtitle: Text(
                  '${date == null ? '' : _formatDate(date)}${expense['notes']?.toString().trim().isNotEmpty ?? false ? ' • ${expense['notes']}' : ''}',
                ),
                trailing: Text(_formatCurrency(amount, currency: currency)),
              );
            }),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Payment history',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (report.payments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No payment records for this month.'),
              ),
            )
          else
            ...report.payments.map((payment) {
              final date =
                  DateTime.tryParse(payment['payment_date']?.toString() ?? '') ??
                  _reportMonth;
              final amount =
                  double.tryParse(payment['amount']?.toString() ?? '') ?? 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${_statuses[payment['status']?.toString().toLowerCase()] ?? payment['status'] ?? 'Unknown'} • ${_formatDate(date)}',
                ),
                subtitle: payment['notes']?.toString().trim().isNotEmpty ?? false
                    ? Text(payment['notes'].toString())
                    : null,
                trailing: Text(_formatCurrency(amount, currency: currency)),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMonthlyReport() {
    final reports = _getMonthlyReport();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_expenseLoadError != null) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Expense data is unavailable, so report totals may be incomplete. Apply the property expenses migration and refresh. $_expenseLoadError',
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _pickReportMonth,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Report month',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_formatRentMonth(_reportMonth)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: _isExportingReport ? null : _exportMonthlyReport,
              icon: _isExportingReport
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('CSV'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add a property to view a monthly report.'),
            ),
          )
        else
          ...reports.map(_buildMonthlyReportCard),
      ],
    );
  }

  Future<void> _carryCreditForward(RentLedgerEntry entry) async {
    final property = _properties.firstWhere(
      (item) => item['id'].toString() == _selectedPropertyId,
    );
    final targetMonth = DateTime(entry.month.year, entry.month.month + 1);
    final currency = property['currency']?.toString() ?? 'KES';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Carry rent credit forward?'),
        content: Text(
          'Apply ${_formatCurrency(entry.availableCredit, currency: currency)} from ${_formatRentMonth(entry.month)} to ${_formatRentMonth(targetMonth)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply credit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase.from('rent_credit_allocations').insert({
        'user_id': user.id,
        'property_id': _selectedPropertyId,
        'source_month': _monthValue(entry.month),
        'target_month': _monthValue(targetMonth),
        'amount': entry.availableCredit,
      });

      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Credit applied to ${_formatRentMonth(targetMonth)}.'),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply credit: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not apply credit: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _monthValue(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-01';

  String _formatCurrency(double value, {String currency = 'KES'}) {
    final roundedValue = value.toStringAsFixed(0);
    final formattedValue = roundedValue.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
    return '$currency $formattedValue';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatRentMonth(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _emailPaymentReceipt(Map<String, dynamic> payment) async {
    final property = _properties.firstWhere(
      (item) => item['id'].toString() == payment['property_id'].toString(),
      orElse: () => <String, dynamic>{},
    );
    final tenantEmail = property['tenant_email']?.toString().trim() ?? '';

    if (tenantEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the tenant email to this property first.'),
        ),
      );
      return;
    }

    final amount = double.tryParse(payment['amount']?.toString() ?? '');
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This payment has an invalid amount.')),
      );
      return;
    }

    final status = payment['status']?.toString().toLowerCase();
    if (status != 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A receipt is available only for recorded payments.'),
        ),
      );
      return;
    }

    final paidDate =
        DateTime.tryParse(payment['payment_date']?.toString() ?? '') ??
        DateTime.now();
    final rentMonth =
        DateTime.tryParse(payment['rent_month']?.toString() ?? '') ??
        DateTime(paidDate.year, paidDate.month);
    final ledger = RentCreditLedger.build(
      property: property,
      payments: _payments,
      allocations: _creditAllocations,
      now: paidDate,
    );
    final rentEntry = ledger.firstWhere(
      (entry) =>
          entry.month.year == rentMonth.year &&
          entry.month.month == rentMonth.month,
    );
    final currency = property['currency']?.toString() ?? 'KES';
    final propertyName = property['name']?.toString() ?? 'Rental property';
    final tenantName = property['tenant_name']?.toString().trim() ?? '';
    final unitNumber = property['unit_number']?.toString().trim() ?? '';
    final address = property['address']?.toString().trim() ?? '';
    final greeting = tenantName.isEmpty ? 'Hello,' : 'Hello $tenantName,';
    final subject = 'Rent payment receipt - $propertyName';
    final body = [
      greeting,
      '',
      'This is a receipt for your rent payment.',
      'Property: $propertyName',
      if (unitNumber.isNotEmpty) 'Unit: $unitNumber',
      if (address.isNotEmpty) 'Address: $address',
      'Rent month: ${_formatRentMonth(rentMonth)}',
      'Payment date: ${_formatDate(paidDate)}',
      'Amount received: ${_formatCurrency(amount, currency: currency)}',
      'Total received for this month: ${_formatCurrency(rentEntry.cashReceived, currency: currency)}',
      'Remaining balance: ${_formatCurrency(rentEntry.amountOwing, currency: currency)}',
      if (rentEntry.availableCredit > 0)
        'Available rent credit: ${_formatCurrency(rentEntry.availableCredit, currency: currency)}',
      '',
      'Thank you for your payment.',
    ].join('\n');

    final emailUri = Uri(
      scheme: 'mailto',
      path: tenantEmail,
      queryParameters: {'subject': subject, 'body': body},
    );

    try {
      final opened = await launchUrl(emailUri);
      if (!opened) {
        throw StateError('No email application handled the receipt.');
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open an email app: $error')),
      );
    }
  }

  Widget _buildLedgerTile(RentLedgerEntry entry, String currency) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = entry.status == 'Overdue'
        ? colorScheme.error
        : entry.status == 'Credit'
        ? colorScheme.tertiary
        : colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatRentMonth(entry.month),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  entry.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Rent: ${_formatCurrency(entry.rent, currency: currency)}'),
            Text(
              'Paid: ${_formatCurrency(entry.cashReceived, currency: currency)}',
            ),
            if (entry.creditApplied > 0)
              Text(
                'Credit applied: ${_formatCurrency(entry.creditApplied, currency: currency)}',
              ),
            if (entry.creditTransferred > 0)
              Text(
                'Credit carried forward: ${_formatCurrency(entry.creditTransferred, currency: currency)}',
              ),
            const SizedBox(height: 6),
            Text(
              entry.availableCredit > 0
                  ? '${_formatCurrency(entry.availableCredit, currency: currency)} available credit'
                  : entry.amountOwing > 0
                  ? '${_formatCurrency(entry.amountOwing, currency: currency)} owing'
                  : 'No balance remaining',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (entry.availableCredit > 0 &&
                _creditAllocationLoadError == null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _carryCreditForward(entry),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Carry to next month'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRentLedger() {
    if (_selectedPropertyId == null) {
      return const Text('Add a property to view its rent ledger.');
    }

    if (_creditAllocationLoadError != null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Credit ledger unavailable. Apply the rent credit allocation migration, then refresh. $_creditAllocationLoadError',
          ),
        ),
      );
    }

    final property = _properties.firstWhere(
      (item) => item['id'].toString() == _selectedPropertyId,
    );
    final currency = property['currency']?.toString() ?? 'KES';
    final entries = RentCreditLedger.build(
      property: property,
      payments: _payments,
      allocations: _creditAllocations,
      now: DateTime.now(),
    );

    return Column(
      children: entries
          .map((entry) => _buildLedgerTile(entry, currency))
          .toList(),
    );
  }

  Widget _buildPaymentTile(Map<String, dynamic> payment) {
    final property = _properties.firstWhere(
      (item) => item['id'].toString() == payment['property_id'].toString(),
      orElse: () => <String, dynamic>{'name': 'Property'},
    );
    final propertyName = property['name']?.toString() ?? 'Property';

    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
    final status = (payment['status']?.toString() ?? 'paid').toLowerCase();
    final paidDate =
        DateTime.tryParse(payment['payment_date']?.toString() ?? '') ??
        DateTime.now();
    final rentMonth =
        DateTime.tryParse(payment['rent_month']?.toString() ?? '') ??
        DateTime(paidDate.year, paidDate.month);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            status == 'paid'
                ? Icons.check_circle_outline
                : status == 'overdue'
                ? Icons.warning_amber_outlined
                : status == 'pending'
                ? Icons.pending_actions_outlined
                : Icons.account_balance_wallet_outlined,
          ),
        ),
        title: Text(propertyName),
        subtitle: Text(
          '${_statuses[status] ?? status} • ${_formatDate(paidDate)} • ${_formatRentMonth(rentMonth)}',
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatCurrency(amount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (status == 'paid')
              IconButton(
                tooltip:
                    property['tenant_email']?.toString().trim().isNotEmpty ??
                        false
                    ? 'Email receipt'
                    : 'Add tenant email to email a receipt',
                visualDensity: VisualDensity.compact,
                onPressed:
                    property['tenant_email']?.toString().trim().isNotEmpty ??
                        false
                    ? () => _emailPaymentReceipt(payment)
                    : null,
                icon: const Icon(Icons.receipt_long_outlined),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Tracker')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Record a payment',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_properties.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedPropertyId,
                                  decoration: const InputDecoration(
                                    labelText: 'Property',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _properties
                                      .map(
                                        (property) => DropdownMenuItem<String>(
                                          value: property['id'].toString(),
                                          child: Text(
                                            property['name']?.toString() ??
                                                'Property',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedPropertyId = value;
                                      });
                                    }
                                  },
                                )
                              else
                                const Text(
                                  'Add a property first before recording payments.',
                                ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Amount received',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter the amount';
                                  }
                                  final amount = double.tryParse(value.trim());
                                  if (amount == null || amount <= 0) {
                                    return 'Enter a valid amount';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _pickDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Payment date',
                                    prefixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(_formatDate(_paidDate)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _pickRentMonth,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Rent month',
                                    prefixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(_formatRentMonth(_rentMonth)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                ),
                                items: _statuses.entries
                                    .map(
                                      (entry) => DropdownMenuItem<String>(
                                        value: entry.key,
                                        child: Text(entry.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _status = value;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Notes (optional)',
                                  prefixIcon: Icon(Icons.note_alt_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _isSaving || _properties.isEmpty
                                      ? null
                                      : _savePayment,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _isSaving ? 'Saving...' : 'Save Payment',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Monthly rent report',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildMonthlyReport(),
                    const SizedBox(height: 14),
                    Text(
                      'Monthly rent ledger',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildRentLedger(),
                    const SizedBox(height: 14),
                    Text(
                      'Recent payments',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_payments.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No payment records yet.'),
                        ),
                      )
                    else
                      ..._payments.map(_buildPaymentTile),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ReportAmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;

  const _ReportAmountRow({
    required this.label,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            _formatCurrencyValue(amount, currency),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatCurrencyValue(double amount, String currency) {
    final roundedAmount = amount.toStringAsFixed(2);
    return '$currency $roundedAmount';
  }
}
