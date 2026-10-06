import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/financial_analytics_service.dart';

void main() {
  const service = FinancialAnalyticsService();

  test('calculates gross rent, collected rent, expenses, and NOI correctly', () {
    final properties = [
      {'id': 'prop-1', 'name': 'Unit 1', 'monthly_rent': 20000, 'currency': 'KES', 'is_vacant': false},
      {'id': 'prop-2', 'name': 'Unit 2', 'monthly_rent': 15000, 'currency': 'KES', 'is_vacant': false},
      {'id': 'prop-3', 'name': 'Unit 3 (Vacant)', 'monthly_rent': 18000, 'currency': 'KES', 'is_vacant': true},
    ];

    final payments = [
      {'property_id': 'prop-1', 'amount': 20000, 'status': 'paid', 'rent_month': '2026-10-01'},
      {'property_id': 'prop-2', 'amount': 10000, 'status': 'paid', 'rent_month': '2026-10-01'},
      {'property_id': 'prop-2', 'amount': 5000, 'status': 'pending', 'rent_month': '2026-10-01'},
    ];

    final expenses = [
      {'property_id': 'prop-1', 'amount': 3000, 'category': 'Repairs', 'expense_date': '2026-10-05'},
      {'property_id': 'prop-2', 'amount': 2000, 'category': 'Utilities', 'expense_date': '2026-10-12'},
    ];

    final report = service.generateMonthlyReport(
      properties: properties,
      payments: payments,
      expenses: expenses,
      targetMonth: DateTime(2026, 10),
    );

    // Expected: prop-1 (20000) + prop-2 (15000) = 35000 (prop-3 is vacant)
    expect(report.grossRentExpected, 35000);
    // Collected: 20000 + 10000 = 30000 (pending is excluded)
    expect(report.totalRentCollected, 30000);
    // Expenses: 3000 + 2000 = 5000
    expect(report.totalExpenses, 5000);
    // NOI: 30000 - 5000 = 25000
    expect(report.netOperatingIncome, 25000);
    // Collection rate: (30000 / 35000) * 100 ≈ 85.71%
    expect(report.collectionRate, closeTo(85.71, 0.05));
    // Category check
    expect(report.expensesByCategory['Repairs'], 3000);
    expect(report.expensesByCategory['Utilities'], 2000);
  });
}
