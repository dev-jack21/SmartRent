import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/expense_ocr_service.dart';
import '../../services/recurring_expense_schedule.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  static const _categories = [
    'Repairs',
    'Insurance',
    'Taxes',
    'Utilities',
    'Management',
    'Other',
  ];

  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _recurringRules = [];
  String? _selectedPropertyId;
  String _category = _categories.first;
  String _frequency = 'monthly';
  bool _isRecurring = false;
  DateTime _expenseDate = DateTime.now();
  DateTime _nextRecurringDate = DateTime.now();
  DateTime _filterMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _isLoading = false;
        _loadError = 'You are not logged in. Please log in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        _supabase
            .from('properties')
            .select('id, name, currency')
            .eq('user_id', user.id)
            .order('created_at', ascending: false),
        _supabase
            .from('property_expenses')
            .select(
              'id, property_id, amount, category, expense_date, paid_date, status, recurring_rule_id, notes',
            )
            .eq('user_id', user.id)
            .order('expense_date', ascending: false),
        _supabase
            .from('recurring_expense_rules')
            .select(
              'id, property_id, amount, category, frequency, next_due_date, notes, is_active',
            )
            .eq('user_id', user.id)
            .order('next_due_date'),
      ]);

      if (!mounted) return;
      final properties = List<Map<String, dynamic>>.from(results[0]);
      setState(() {
        _properties = properties;
        _expenses = List<Map<String, dynamic>>.from(results[1]);
        _recurringRules = List<Map<String, dynamic>>.from(results[2]);
        if (!properties.any(
          (property) => property['id'].toString() == _selectedPropertyId,
        )) {
          _selectedPropertyId = properties.isEmpty
              ? null
              : properties.first['id'].toString();
        }
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'Could not load expenses: ${error.message}. Apply the property expenses and recurring expenses migrations, then try again.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load expenses: $error';
      });
    }
  }

  Future<void> _scanReceiptDialog() async {
    final controller = TextEditingController();
    final data = await showDialog<ScannedReceiptData>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Smart Scan Receipt / Invoice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste receipt text, invoice notes, or scanned vendor bill:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'e.g.,\nPlumbing Depot\nInvoice #4021\nTOTAL: \$180.00\nDate: 2025-02-15',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final result = ExpenseOcrService.instance.parseReceiptText(controller.text);
                Navigator.pop(context, result);
              },
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan & Fill'),
            ),
          ],
        );
      },
    );

    if (data != null && mounted) {
      if (data.amount != null) {
        _amountController.text = data.amount!.toStringAsFixed(2);
      }
      if (data.vendor != null) {
        _notesController.text = data.vendor!;
      }
      if (data.category != null && _categories.contains(data.category)) {
        setState(() {
          _category = data.category!;
        });
      }
      if (data.date != null) {
        setState(() {
          _expenseDate = data.date!;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Auto-filled: ${data.amount != null ? '\$${data.amount!.toStringAsFixed(2)}' : 'Receipt data'} extracted successfully!',
          ),
        ),
      );
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are not logged in.')));
      return;
    }
    if (_selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a property first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final amount = double.parse(_amountController.text.trim());
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      if (_isRecurring) {
        await _supabase.from('recurring_expense_rules').insert({
          'user_id': user.id,
          'property_id': _selectedPropertyId,
          'amount': amount,
          'category': _category,
          'frequency': _frequency,
          'next_due_date': _dateOnly(_nextRecurringDate),
          'anchor_month': _nextRecurringDate.month,
          'anchor_day': _nextRecurringDate.day,
          'notes': notes,
        });
      } else {
        await _supabase.from('property_expenses').insert({
          'user_id': user.id,
          'property_id': _selectedPropertyId,
          'amount': amount,
          'category': _category,
          'expense_date': _dateOnly(_expenseDate),
          'paid_date': _dateOnly(_expenseDate),
          'status': 'paid',
          'notes': notes,
        });
      }
      if (!mounted) return;
      _amountController.clear();
      _notesController.clear();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRecurring
                ? 'Recurring expense saved. Due items will be created as planned expenses for review.'
                : 'Expense saved successfully.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save expense: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save expense: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generateDueExpenses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are not logged in.')));
      return;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    var createdCount = 0;

    setState(() => _isSaving = true);
    try {
      for (final rule in _recurringRules.where(
        (rule) => rule['is_active'] == true,
      )) {
        final ruleId = rule['id']?.toString();
        if (ruleId == null || ruleId.isEmpty) continue;
        final parsedDueDate = DateTime.tryParse(
          rule['next_due_date']?.toString() ?? '',
        );
        if (parsedDueDate == null) {
          throw FormatException(
            'Recurring expense $ruleId has an invalid date.',
          );
        }
        var dueDate = parsedDueDate;

        final frequency = rule['frequency']?.toString() ?? '';
        final anchorMonth =
            int.tryParse(rule['anchor_month']?.toString() ?? '') ??
            dueDate.month;
        final anchorDay =
            int.tryParse(rule['anchor_day']?.toString() ?? '') ?? dueDate.day;

        while (!DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
        ).isAfter(todayDate)) {
          final occurrenceDate = _dateOnly(dueDate);
          final inserted = await _supabase
              .from('property_expenses')
              .upsert(
                {
                  'user_id': user.id,
                  'property_id': rule['property_id'],
                  'amount': rule['amount'],
                  'category': rule['category'],
                  'expense_date': occurrenceDate,
                  'status': 'planned',
                  'recurring_rule_id': ruleId,
                  'recurrence_date': occurrenceDate,
                  'notes': rule['notes'],
                },
                onConflict: 'recurring_rule_id,recurrence_date',
                ignoreDuplicates: true,
              )
              .select('id');
          if (inserted.isNotEmpty) createdCount++;

          dueDate = RecurringExpenseSchedule.nextDueDate(
            currentDueDate: dueDate,
            frequency: frequency,
            anchorMonth: anchorMonth,
            anchorDay: anchorDay,
          );
          await _supabase
              .from('recurring_expense_rules')
              .update({'next_due_date': _dateOnly(dueDate)})
              .eq('id', ruleId)
              .eq('user_id', user.id);
        }
      }

      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            createdCount == 0
                ? 'No recurring expenses are due yet.'
                : 'Added $createdCount planned ${createdCount == 1 ? 'expense' : 'expenses'} for review.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not generate planned expenses: ${error.message}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate planned expenses: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _markExpensePaid(Map<String, dynamic> expense) async {
    final user = _supabase.auth.currentUser;
    final expenseId = expense['id']?.toString();
    if (user == null || expenseId == null || expenseId.isEmpty) return;

    try {
      final today = DateTime.now();
      await _supabase
          .from('property_expenses')
          .update({'status': 'paid', 'paid_date': _dateOnly(today)})
          .eq('id', expenseId)
          .eq('user_id', user.id)
          .eq('status', 'planned');
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense marked as paid.')));
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not mark expense paid: ${error.message}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark expense paid: $error')),
      );
    }
  }

  Future<void> _toggleRule(Map<String, dynamic> rule) async {
    final user = _supabase.auth.currentUser;
    final ruleId = rule['id']?.toString();
    if (user == null || ruleId == null || ruleId.isEmpty) return;

    try {
      await _supabase
          .from('recurring_expense_rules')
          .update({'is_active': rule['is_active'] != true})
          .eq('id', ruleId)
          .eq('user_id', user.id);
      if (!mounted) return;
      await _loadData();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update recurring expense: ${error.message}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update recurring expense: $error')),
      );
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final expenseId = expense['id']?.toString();
    if (expenseId == null || expenseId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This expense will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _supabase
          .from('property_expenses')
          .delete()
          .eq('id', expenseId)
          .eq('user_id', user.id);
      if (!mounted) return;
      await _loadData();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete expense: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete expense: $error')),
      );
    }
  }

  Future<void> _pickDate({required bool reportFilter}) async {
    final selected = reportFilter
        ? _filterMonth
        : _isRecurring
        ? _nextRecurringDate
        : _expenseDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: reportFilter ? 'SELECT EXPENSE MONTH' : 'SELECT EXPENSE DATE',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (reportFilter) {
        _filterMonth = DateTime(picked.year, picked.month);
      } else if (_isRecurring) {
        _nextRecurringDate = picked;
      } else {
        _expenseDate = picked;
      }
    });
  }

  String _dateOnly(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _formatMonth(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> get _filteredExpenses {
    return _expenses.where((expense) {
      final date = DateTime.tryParse(
        (expense['status'] == 'paid'
                    ? expense['paid_date'] ?? expense['expense_date']
                    : expense['expense_date'])
                ?.toString() ??
            '',
      );
      return date != null &&
          date.year == _filterMonth.year &&
          date.month == _filterMonth.month;
    }).toList();
  }

  String _currencyFor(String? propertyId) {
    for (final property in _properties) {
      if (property['id'].toString() == propertyId) {
        return property['currency']?.toString() ?? 'KES';
      }
    }
    return 'KES';
  }

  String get _monthlyTotalLabel {
    final totalsByCurrency = <String, double>{};
    for (final expense in _filteredExpenses.where(
      (expense) => expense['status'] != 'planned',
    )) {
      final currency = _currencyFor(expense['property_id']?.toString());
      final amount = double.tryParse(expense['amount']?.toString() ?? '') ?? 0;
      totalsByCurrency.update(
        currency,
        (total) => total + amount,
        ifAbsent: () => amount,
      );
    }

    if (totalsByCurrency.isEmpty) return 'No expenses';
    return totalsByCurrency.entries
        .map((entry) => '${entry.key} ${entry.value.toStringAsFixed(2)}')
        .join(' · ');
  }

  String get _plannedTotalLabel {
    final totalsByCurrency = <String, double>{};
    for (final expense in _filteredExpenses.where(
      (expense) => expense['status'] == 'planned',
    )) {
      final currency = _currencyFor(expense['property_id']?.toString());
      final amount = double.tryParse(expense['amount']?.toString() ?? '') ?? 0;
      totalsByCurrency.update(
        currency,
        (total) => total + amount,
        ifAbsent: () => amount,
      );
    }
    if (totalsByCurrency.isEmpty) return 'None';
    return totalsByCurrency.entries
        .map((entry) => '${entry.key} ${entry.value.toStringAsFixed(2)}')
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Expenses'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Record an expense',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                OutlinedButton.icon(
                                  onPressed: _scanReceiptDialog,
                                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                                  label: const Text('Scan Receipt', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_properties.isEmpty)
                              const Text(
                                'Add a property before recording expenses.',
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: _selectedPropertyId,
                                decoration: const InputDecoration(
                                  labelText: 'Property',
                                  border: OutlineInputBorder(),
                                ),
                                items: _properties
                                    .map(
                                      (property) => DropdownMenuItem(
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
                                    setState(() => _selectedPropertyId = value);
                                  }
                                },
                              ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixIcon: Icon(Icons.payments_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final amount = double.tryParse(
                                  value?.trim() ?? '',
                                );
                                if (amount == null || amount <= 0) {
                                  return 'Enter an amount greater than zero';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _category = value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Make this recurring'),
                              subtitle: const Text(
                                'Create planned entries for review when they become due.',
                              ),
                              value: _isRecurring,
                              onChanged: (value) {
                                setState(() => _isRecurring = value);
                              },
                            ),
                            if (_isRecurring) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _frequency,
                                decoration: const InputDecoration(
                                  labelText: 'Repeat frequency',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('Monthly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'yearly',
                                    child: Text('Yearly'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _frequency = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _pickDate(reportFilter: false),
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: Text(
                                  'Next due: ${_formatDate(_nextRecurringDate)}',
                                ),
                              ),
                            ] else
                              OutlinedButton.icon(
                                onPressed: () => _pickDate(reportFilter: false),
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: Text(
                                  'Expense date: ${_formatDate(_expenseDate)}',
                                ),
                              ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _isSaving || _properties.isEmpty
                                  ? null
                                  : _saveExpense,
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
                                _isSaving
                                    ? 'Saving...'
                                    : _isRecurring
                                    ? 'Save recurring rule'
                                    : 'Save expense',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recurring expenses',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isSaving ? null : _generateDueExpenses,
                        icon: const Icon(Icons.playlist_add_outlined),
                        label: const Text('Create due items'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Due recurring expenses are added as planned entries; they do not count as paid until confirmed.',
                  ),
                  const SizedBox(height: 8),
                  if (_recurringRules.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No recurring expense rules yet.'),
                      ),
                    )
                  else
                    ..._recurringRules.map((rule) {
                      final property = _properties.firstWhere(
                        (item) =>
                            item['id'].toString() ==
                            rule['property_id'].toString(),
                        orElse: () => <String, dynamic>{'name': 'Property'},
                      );
                      final nextDue = DateTime.tryParse(
                        rule['next_due_date']?.toString() ?? '',
                      );
                      final active = rule['is_active'] == true;
                      final amount =
                          double.tryParse(rule['amount']?.toString() ?? '') ??
                          0;
                      final currency = _currencyFor(
                        rule['property_id']?.toString(),
                      );
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.autorenew),
                          ),
                          title: Text(
                            '${rule['category'] ?? 'Other'} • ${property['name'] ?? 'Property'}',
                          ),
                          subtitle: Text(
                            '${rule['frequency'] == 'yearly' ? 'Yearly' : 'Monthly'} • $currency ${amount.toStringAsFixed(2)} • Next: ${nextDue == null ? 'Unknown' : _formatDate(nextDue)}${active ? '' : ' • Paused'}',
                          ),
                          trailing: IconButton(
                            tooltip: active ? 'Pause rule' : 'Resume rule',
                            onPressed: () => _toggleRule(rule),
                            icon: Icon(
                              active
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  Text(
                    'Expense history',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(reportFilter: true),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('Month: ${_formatMonth(_filterMonth)}'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paid: $_monthlyTotalLabel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Planned: $_plannedTotalLabel'),
                  const SizedBox(height: 12),
                  if (_filteredExpenses.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No expenses recorded for this month.'),
                      ),
                    )
                  else
                    ..._filteredExpenses.map((expense) {
                      final property = _properties.firstWhere(
                        (item) =>
                            item['id'].toString() ==
                            expense['property_id'].toString(),
                        orElse: () => <String, dynamic>{'name': 'Property'},
                      );
                      final isPlanned = expense['status'] == 'planned';
                      final date = DateTime.tryParse(
                        (isPlanned
                                    ? expense['expense_date']
                                    : expense['paid_date'] ??
                                          expense['expense_date'])
                                ?.toString() ??
                            '',
                      );
                      final currency = _currencyFor(
                        expense['property_id']?.toString(),
                      );
                      final amount =
                          double.tryParse(
                            expense['amount']?.toString() ?? '',
                          ) ??
                          0;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.receipt_long_outlined),
                          ),
                          title: Text(
                            '${expense['category'] ?? 'Other'} • ${property['name'] ?? 'Property'}${isPlanned ? ' • Planned' : ''}',
                          ),
                          subtitle: Text(
                            '${isPlanned ? 'Due' : 'Paid'}: ${date == null ? '' : _formatDate(date)}${expense['notes'] == null ? '' : ' • ${expense['notes']}'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$currency ${amount.toStringAsFixed(2)}'),
                              if (isPlanned)
                                IconButton(
                                  tooltip: 'Mark as paid',
                                  onPressed: () => _markExpensePaid(expense),
                                  icon: const Icon(Icons.check_circle_outline),
                                ),
                              IconButton(
                                tooltip: 'Delete expense',
                                onPressed: () => _deleteExpense(expense),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
