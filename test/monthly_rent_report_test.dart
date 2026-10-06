import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/monthly_rent_report.dart';

int _csvColumnCount(String row) {
  var inQuotes = false;
  var columns = 1;
  for (var index = 0; index < row.length; index++) {
    final character = row[index];
    if (character == '"') {
      if (inQuotes && index + 1 < row.length && row[index + 1] == '"') {
        index++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (character == ',' && !inQuotes) {
      columns++;
    }
  }
  return columns;
}

void main() {
  test(
    'summarizes selected month with received, pending, and balance amounts',
    () {
      final reports = MonthlyRentReport.build(
        properties: [
          {
            'id': 'property-1',
            'name': 'Central Apartments',
            'tenant_name': 'Sam Tenant',
            'unit_number': 'A2',
            'monthly_rent': 1000,
            'currency': 'KES',
            'due_day': 5,
          },
        ],
        payments: [
          {
            'property_id': 'property-1',
            'amount': 600,
            'status': 'paid',
            'payment_date': '2026-10-03',
            'rent_month': '2026-10-01',
          },
          {
            'property_id': 'property-1',
            'amount': 100,
            'status': 'pending',
            'payment_date': '2026-10-04',
            'rent_month': '2026-10-01',
          },
          {
            'property_id': 'property-1',
            'amount': 500,
            'status': 'paid',
            'payment_date': '2026-09-02',
            'rent_month': '2026-09-01',
          },
        ],
        allocations: const [],
        expenses: [
          {
            'property_id': 'property-1',
            'amount': 75,
            'category': 'Repairs',
            'expense_date': '2026-10-07',
            'paid_date': '2026-10-08',
            'status': 'paid',
            'notes': 'Leak repair',
          },
          {
            'property_id': 'property-1',
            'amount': 20,
            'category': 'Utilities',
            'expense_date': '2026-09-30',
            'paid_date': '2026-09-30',
            'status': 'paid',
          },
          {
            'property_id': 'property-1',
            'amount': 30,
            'category': 'Insurance',
            'expense_date': '2026-10-15',
            'status': 'planned',
          },
        ],
        month: DateTime(2026, 10, 22),
      );

      expect(reports, hasLength(1));
      expect(reports.single.ledgerEntry.rent, 1000);
      expect(reports.single.ledgerEntry.cashReceived, 600);
      expect(reports.single.pendingAmount, 100);
      expect(reports.single.ledgerEntry.amountOwing, 400);
      expect(reports.single.payments, hasLength(2));
      expect(reports.single.expensesAmount, 75);
      expect(reports.single.plannedExpensesAmount, 30);
      expect(reports.single.expenses, hasLength(2));
      expect(reports.single.netCashFlow, 525);
    },
  );

  test('CSV export includes summaries and safely escapes payment notes', () {
    final reports = MonthlyRentReport.build(
      properties: [
        {
          'id': 'property-1',
          'name': 'Central, Apartments',
          'tenant_name': 'Sam "Tenant"',
          'unit_number': 'A2',
          'monthly_rent': 1000,
          'currency': 'KES',
          'due_day': 5,
        },
      ],
      payments: [
        {
          'property_id': 'property-1',
          'amount': 1000,
          'status': 'paid',
          'payment_date': '2026-10-03',
          'rent_month': '2026-10-01',
          'notes': '=SUM(1,2)',
        },
      ],
      expenses: [
        {
          'property_id': 'property-1',
          'amount': 125,
          'category': 'Repairs',
          'expense_date': '2026-10-10',
          'paid_date': '2026-10-10',
          'status': 'paid',
          'notes': 'Replaced, fixtures',
        },
        {
          'property_id': 'property-1',
          'amount': 35,
          'category': 'Insurance',
          'expense_date': '2026-10-20',
          'status': 'planned',
          'notes': 'Upcoming premium',
        },
      ],
      allocations: const [],
      month: DateTime(2026, 10),
    );

    final csv = MonthlyRentReport.toCsv(
      month: DateTime(2026, 10),
      reports: reports,
    );

    expect(csv, startsWith('\uFEFF'));
    expect(csv, contains('"2026-10","Monthly summary","Central, Apartments"'));
    expect(csv, contains('"Sam ""Tenant"""'));
    expect(csv, contains("\"'=SUM(1,2)\""));
    expect(csv, contains('"Expenses","Planned expenses","Net cash flow"'));
    expect(csv, contains('"Expense detail","Central, Apartments"'));
    expect(csv, contains('"Repairs","125","paid","Replaced, fixtures"'));
    expect(csv, contains('"35","planned","Upcoming premium"'));
    expect(csv.split('\r\n').every((row) => '"'.allMatches(row).length % 2 == 0), isTrue);
    expect(
      csv
          .split('\r\n')
          .every((row) => _csvColumnCount(row) == 22),
      isTrue,
    );
  });
}
