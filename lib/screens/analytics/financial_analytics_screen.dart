import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/financial_analytics_service.dart';

class FinancialAnalyticsScreen extends StatefulWidget {
  const FinancialAnalyticsScreen({super.key});

  @override
  State<FinancialAnalyticsScreen> createState() =>
      _FinancialAnalyticsScreenState();
}

class _FinancialAnalyticsScreenState extends State<FinancialAnalyticsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _expenses = [];

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
      List<Map<String, dynamic>> props = [];
      List<Map<String, dynamic>> pmts = [];
      List<Map<String, dynamic>> exps = [];

      try {
        final propRes = await _supabase
            .from('properties')
            .select('id, name, monthly_rent, currency, tenant_name, tenant_email')
            .eq('user_id', user.id);
        props = List<Map<String, dynamic>>.from(propRes);
      } catch (_) {}

      try {
        final pmtRes = await _supabase
            .from('payments')
            .select('property_id, amount, status, payment_date, rent_month')
            .eq('user_id', user.id);
        pmts = List<Map<String, dynamic>>.from(pmtRes);
      } catch (_) {}

      try {
        final expRes = await _supabase
            .from('property_expenses')
            .select('property_id, amount, category, expense_date')
            .eq('user_id', user.id);
        exps = List<Map<String, dynamic>>.from(expRes);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _properties = props;
        _payments = pmts;
        _expenses = exps;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load analytics: $e';
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final report = FinancialAnalyticsService.instance.generateMonthlyReport(
      properties: _properties,
      payments: _payments,
      expenses: _expenses,
      targetMonth: _selectedMonth,
    );
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial & Property Analytics'),
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Month Navigator
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _previousMonth,
                            ),
                            Text(
                              _formatMonthYear(_selectedMonth),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Net Operating Income Card
                    Card(
                      color: report.netOperatingIncome >= 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: report.netOperatingIncome >= 0
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'NET OPERATING INCOME (NOI)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: report.netOperatingIncome >= 0
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${report.netOperatingIncome >= 0 ? "+" : ""}${_formatCurrency(report.netOperatingIncome)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: report.netOperatingIncome >= 0
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rent Collected: ${_formatCurrency(report.totalRentCollected)}  •  Expenses: ${_formatCurrency(report.totalExpenses)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Visual Revenue & Expense Comparison Bars
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Revenue vs Expense Ratio',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Gross Collected:'),
                                Text(
                                  _formatCurrency(report.totalRentCollected),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: 1.0,
                                minHeight: 8,
                                color: Colors.green[700],
                                backgroundColor: Colors.green[100],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Operating Expenses:'),
                                Text(
                                  _formatCurrency(report.totalExpenses),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: colors.error),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: report.totalRentCollected > 0
                                    ? (report.totalExpenses / report.totalRentCollected).clamp(0.0, 1.0)
                                    : (report.totalExpenses > 0 ? 1.0 : 0.0),
                                minHeight: 8,
                                color: colors.error,
                                backgroundColor: colors.errorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Summary Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Gross Expected',
                            _formatCurrency(report.grossRentExpected),
                            Icons.request_quote_outlined,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'Rent Collected',
                            _formatCurrency(report.totalRentCollected),
                            Icons.check_circle_outline,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Total Expenses',
                            _formatCurrency(report.totalExpenses),
                            Icons.money_off_csred_outlined,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'Collection Rate',
                            '${report.collectionRate.toStringAsFixed(1)}%',
                            Icons.pie_chart_outline,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Expense Breakdown by Category
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.category_outlined, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Expense Distribution',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (report.expensesByCategory.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No expenses logged for this month.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            else
                              ...report.expensesByCategory.entries.map((entry) {
                                final pct = report.totalExpenses > 0
                                    ? entry.value / report.totalExpenses
                                    : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          Text(
                                            '${_formatCurrency(entry.value)} (${(pct * 100).toStringAsFixed(1)}%)',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 6,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Property Performance Table
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.apartment_outlined, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Performance by Property',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (report.propertySummaries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No properties available.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            else
                              ...report.propertySummaries.map((item) {
                                final isProfit = item.netIncome >= 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.propertyName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Collected: ${item.currency} ${_formatCurrency(item.collectedRent)}  •  Exp: ${item.currency} ${_formatCurrency(item.totalExpenses)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${isProfit ? "+" : ""}${item.currency} ${_formatCurrency(item.netIncome)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
