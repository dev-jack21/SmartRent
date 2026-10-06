import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/overdue_rent_follow_up.dart';

void main() {
  final now = DateTime(2026, 10, 15);

  test('includes unpaid months from lease start and excludes paid months', () {
    final followUps = OverdueRentFollowUp.build(
      properties: [
        {
          'id': 'property-1',
          'name': 'Central Apartments',
          'monthly_rent': 100,
          'due_day': 5,
          'lease_start_date': '2026-08-01',
        },
      ],
      payments: [
        {
          'property_id': 'property-1',
          'rent_month': '2026-08-01',
          'amount': 100,
          'status': 'paid',
        },
        {
          'property_id': 'property-1',
          'rent_month': '2026-09-01',
          'amount': 40,
          'status': 'paid',
        },
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

    expect(followUps, hasLength(1));
    expect(followUps.single.overdueEntries.map((entry) => entry.month.month), [
      9,
      10,
    ]);
    expect(followUps.single.totalOwing, 160);
  });

  test('does not include rent due today or a future lease', () {
    final followUps = OverdueRentFollowUp.build(
      properties: [
        {
          'id': 'due-today',
          'name': 'Due Today',
          'monthly_rent': 100,
          'due_day': 15,
          'lease_start_date': '2026-10-01',
        },
        {
          'id': 'future',
          'name': 'Future Lease',
          'monthly_rent': 100,
          'due_day': 5,
          'lease_start_date': '2026-11-01',
        },
      ],
      payments: const [],
      allocations: const [],
      now: now,
    );

    expect(followUps, isEmpty);
  });
}
