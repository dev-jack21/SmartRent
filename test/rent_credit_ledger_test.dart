import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/rent_credit_ledger.dart';

void main() {
  const property = {'id': 'property-1', 'monthly_rent': 100, 'due_day': 5};
  final now = DateTime(2026, 10, 15);

  test('keeps an overpayment available as credit', () {
    final entries = RentCreditLedger.build(
      property: property,
      payments: [
        {
          'property_id': 'property-1',
          'rent_month': '2026-10-01',
          'amount': 150,
          'status': 'paid',
        },
      ],
      allocations: const [],
      now: now,
    );

    expect(entries.single.status, 'Credit');
    expect(entries.single.amountOwing, 0);
    expect(entries.single.availableCredit, 50);
  });

  test('moves credit from its source month into the target balance', () {
    final entries = RentCreditLedger.build(
      property: property,
      payments: [
        {
          'property_id': 'property-1',
          'rent_month': '2026-10-01',
          'amount': 150,
          'status': 'paid',
        },
      ],
      allocations: [
        {
          'property_id': 'property-1',
          'source_month': '2026-10-01',
          'target_month': '2026-11-01',
          'amount': 50,
        },
      ],
      now: now,
    );

    final october = entries.firstWhere((entry) => entry.month.month == 10);
    final november = entries.firstWhere((entry) => entry.month.month == 11);

    expect(october.status, 'Paid');
    expect(october.availableCredit, 0);
    expect(october.creditTransferred, 50);
    expect(november.creditApplied, 50);
    expect(november.amountOwing, 50);
  });

  test('does not count pending payments as received rent', () {
    final entries = RentCreditLedger.build(
      property: property,
      payments: [
        {
          'property_id': 'property-1',
          'rent_month': '2026-10-01',
          'amount': 100,
          'status': 'pending',
        },
      ],
      allocations: const [],
      now: now,
    );

    expect(entries.single.cashReceived, 0);
    expect(entries.single.amountOwing, 100);
    expect(entries.single.status, 'Overdue');
  });
}
