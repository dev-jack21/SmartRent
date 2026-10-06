class PropertyFinancialSummary {
  final String propertyId;
  final String propertyName;
  final String currency;
  final double expectedRent;
  final double collectedRent;
  final double totalExpenses;

  const PropertyFinancialSummary({
    required this.propertyId,
    required this.propertyName,
    required this.currency,
    required this.expectedRent,
    required this.collectedRent,
    required this.totalExpenses,
  });

  double get netIncome => collectedRent - totalExpenses;
}

class FinancialAnalyticsReport {
  final DateTime month;
  final double grossRentExpected;
  final double totalRentCollected;
  final double totalExpenses;
  final Map<String, double> expensesByCategory;
  final List<PropertyFinancialSummary> propertySummaries;

  const FinancialAnalyticsReport({
    required this.month,
    required this.grossRentExpected,
    required this.totalRentCollected,
    required this.totalExpenses,
    required this.expensesByCategory,
    required this.propertySummaries,
  });

  double get netOperatingIncome => totalRentCollected - totalExpenses;

  double get collectionRate =>
      grossRentExpected > 0 ? (totalRentCollected / grossRentExpected) * 100 : 0;
}

class FinancialAnalyticsService {
  const FinancialAnalyticsService();

  static const FinancialAnalyticsService instance = FinancialAnalyticsService();

  FinancialAnalyticsReport generateMonthlyReport({
    required List<Map<String, dynamic>> properties,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> expenses,
    required DateTime targetMonth,
  }) {
    final monthStr = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';

    double grossRentExpected = 0;
    double totalRentCollected = 0;
    double totalExpenses = 0;
    final expensesByCategory = <String, double>{};
    final propertySummaries = <PropertyFinancialSummary>[];

    // Filter payments for this month with status 'paid'
    final monthPayments = payments.where((p) {
      final rentMonth = p['rent_month']?.toString() ?? '';
      final paymentDate = p['payment_date']?.toString() ?? '';
      final isMonthMatch = rentMonth.startsWith(monthStr) || paymentDate.startsWith(monthStr);
      final isPaid = p['status']?.toString().toLowerCase() == 'paid';
      return isMonthMatch && isPaid;
    }).toList();

    // Filter expenses for this month
    final monthExpenses = expenses.where((e) {
      final expenseDate = e['expense_date']?.toString() ?? '';
      return expenseDate.startsWith(monthStr);
    }).toList();

    for (final exp in monthExpenses) {
      final amt = double.tryParse(exp['amount']?.toString() ?? '0') ?? 0;
      final cat = exp['category']?.toString() ?? 'Other';
      totalExpenses += amt;
      expensesByCategory[cat] = (expensesByCategory[cat] ?? 0) + amt;
    }

    for (final prop in properties) {
      final propId = prop['id']?.toString() ?? '';
      final propName = prop['name']?.toString() ?? 'Property';
      final currency = prop['currency']?.toString() ?? 'KES';
      final isVacant = prop['is_vacant'] == true;
      final monthlyRent = double.tryParse(prop['monthly_rent']?.toString() ?? '0') ?? 0;

      if (!isVacant) {
        grossRentExpected += monthlyRent;
      }

      final propPayments = monthPayments.where((p) => p['property_id']?.toString() == propId);
      final collected = propPayments.fold<double>(
        0,
        (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0),
      );
      totalRentCollected += collected;

      final propExpenses = monthExpenses.where((e) => e['property_id']?.toString() == propId);
      final expTotal = propExpenses.fold<double>(
        0,
        (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0),
      );

      propertySummaries.add(
        PropertyFinancialSummary(
          propertyId: propId,
          propertyName: propName,
          currency: currency,
          expectedRent: monthlyRent,
          collectedRent: collected,
          totalExpenses: expTotal,
        ),
      );
    }

    return FinancialAnalyticsReport(
      month: DateTime(targetMonth.year, targetMonth.month),
      grossRentExpected: grossRentExpected,
      totalRentCollected: totalRentCollected,
      totalExpenses: totalExpenses,
      expensesByCategory: expensesByCategory,
      propertySummaries: propertySummaries,
    );
  }
}
