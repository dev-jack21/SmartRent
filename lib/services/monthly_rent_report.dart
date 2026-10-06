import 'rent_credit_ledger.dart';

class MonthlyPropertyReport {
  final Map<String, dynamic> property;
  final RentLedgerEntry ledgerEntry;
  final double pendingAmount;
  final List<Map<String, dynamic>> payments;
  final double expensesAmount;
  final double plannedExpensesAmount;
  final List<Map<String, dynamic>> expenses;
  final double netCashFlow;

  const MonthlyPropertyReport({
    required this.property,
    required this.ledgerEntry,
    required this.pendingAmount,
    required this.payments,
    required this.expensesAmount,
    required this.plannedExpensesAmount,
    required this.expenses,
    required this.netCashFlow,
  });
}

class MonthlyRentReport {
  const MonthlyRentReport._();

  static List<MonthlyPropertyReport> build({
    required List<Map<String, dynamic>> properties,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> allocations,
    List<Map<String, dynamic>> expenses = const [],
    required DateTime month,
  }) {
    final reportMonth = DateTime(month.year, month.month);

    return properties.map((property) {
      final propertyId = property['id'].toString();
      final monthPayments = payments.where((payment) {
        if (payment['property_id'].toString() != propertyId) return false;
        final paymentMonth =
            _parseMonth(payment['rent_month']) ??
            _parseMonth(payment['payment_date']);
        return paymentMonth == reportMonth;
      }).toList();

      final pendingAmount = monthPayments
          .where(
            (payment) =>
                payment['status']?.toString().toLowerCase() == 'pending',
          )
          .fold<double>(
            0,
            (total, payment) =>
                total +
                (double.tryParse(payment['amount']?.toString() ?? '') ?? 0),
          );
      final monthExpenses = expenses.where((expense) {
        if (expense['property_id'].toString() != propertyId) return false;
        final expenseDate = expense['status']?.toString() == 'paid'
            ? expense['paid_date'] ?? expense['expense_date']
            : expense['expense_date'];
        final expenseMonth = _parseMonth(expenseDate);
        return expenseMonth == reportMonth;
      }).toList();
      final expensesAmount = monthExpenses
          .where((expense) => expense['status']?.toString() != 'planned')
          .fold<double>(
        0,
        (total, expense) =>
            total + (double.tryParse(expense['amount']?.toString() ?? '') ?? 0),
      );
      final plannedExpensesAmount = monthExpenses
          .where((expense) => expense['status']?.toString() == 'planned')
          .fold<double>(
            0,
            (total, expense) =>
                total +
                (double.tryParse(expense['amount']?.toString() ?? '') ?? 0),
          );

      final ledger = RentCreditLedger.build(
        property: property,
        payments: payments,
        allocations: allocations,
        now: reportMonth,
      );
      final ledgerEntry = ledger.firstWhere(
        (entry) =>
            entry.month.year == reportMonth.year &&
            entry.month.month == reportMonth.month,
      );

      return MonthlyPropertyReport(
        property: property,
        ledgerEntry: ledgerEntry,
        pendingAmount: pendingAmount,
        payments: monthPayments,
        expensesAmount: expensesAmount,
        plannedExpensesAmount: plannedExpensesAmount,
        expenses: monthExpenses,
        netCashFlow: ledgerEntry.cashReceived - expensesAmount,
      );
    }).toList();
  }

  static String toCsv({
    required DateTime month,
    required List<MonthlyPropertyReport> reports,
  }) {
    final rows = <List<String>>[
      [
        'Report month',
        'Record type',
        'Property',
        'Tenant',
        'Unit',
        'Currency',
        'Payment date',
        'Payment status',
        'Payment amount',
        'Monthly rent',
        'Cash received',
        'Pending amount',
        'Remaining balance',
        'Available credit',
        'Expenses',
        'Planned expenses',
        'Net cash flow',
        'Expense date',
        'Expense category',
        'Expense amount',
        'Expense status',
        'Notes',
      ],
    ];

    for (final report in reports) {
      final property = report.property;
      final entry = report.ledgerEntry;
      rows.add([
        _monthString(month),
        'Monthly summary',
        property['name']?.toString() ?? '',
        property['tenant_name']?.toString() ?? '',
        property['unit_number']?.toString() ?? '',
        property['currency']?.toString() ?? 'KES',
        '',
        '',
        '',
        _number(entry.rent),
        _number(entry.cashReceived),
        _number(report.pendingAmount),
        _number(entry.amountOwing),
        _number(entry.availableCredit),
        _number(report.expensesAmount),
        _number(report.plannedExpensesAmount),
        _number(report.netCashFlow),
        '',
        '',
        '',
        '',
        '',
      ]);

      for (final payment in report.payments) {
        rows.add([
          _monthString(month),
          'Payment detail',
          property['name']?.toString() ?? '',
          property['tenant_name']?.toString() ?? '',
          property['unit_number']?.toString() ?? '',
          property['currency']?.toString() ?? 'KES',
          payment['payment_date']?.toString() ?? '',
          payment['status']?.toString() ?? '',
          payment['amount']?.toString() ?? '',
          ...List.filled(12, ''),
          payment['notes']?.toString() ?? '',
        ]);
      }

      for (final expense in report.expenses) {
        rows.add([
          _monthString(month),
          'Expense detail',
          property['name']?.toString() ?? '',
          property['tenant_name']?.toString() ?? '',
          property['unit_number']?.toString() ?? '',
          property['currency']?.toString() ?? 'KES',
          ...List.filled(11, ''),
          (expense['status']?.toString() == 'paid'
                  ? expense['paid_date'] ?? expense['expense_date']
                  : expense['expense_date'])
              ?.toString() ??
              '',
          expense['category']?.toString() ?? '',
          expense['amount']?.toString() ?? '',
          expense['status']?.toString() ?? 'paid',
          expense['notes']?.toString() ?? '',
        ]);
      }
    }

    return '\uFEFF${rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n')}';
  }

  static DateTime? _parseMonth(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? null : DateTime(date.year, date.month);
  }

  static String _monthString(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  static String _number(double value) => value.toStringAsFixed(2);

  static String _escapeCsv(String value) {
    var safeValue = value;
    if (RegExp(r'^[\s]*[=+\-@]').hasMatch(safeValue)) {
      safeValue = "'$safeValue";
    }
    return '"${safeValue.replaceAll('"', '""')}"';
  }
}
