import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/recurring_expense_schedule.dart';

void main() {
  test('monthly schedule preserves anchor day after a short month', () {
    final february = RecurringExpenseSchedule.nextDueDate(
      currentDueDate: DateTime(2026, 1, 31),
      frequency: 'monthly',
      anchorMonth: 1,
      anchorDay: 31,
    );
    final march = RecurringExpenseSchedule.nextDueDate(
      currentDueDate: february,
      frequency: 'monthly',
      anchorMonth: 1,
      anchorDay: 31,
    );

    expect(february, DateTime(2026, 2, 28));
    expect(march, DateTime(2026, 3, 31));
  });

  test('yearly schedule preserves leap-day date by clamping', () {
    expect(
      RecurringExpenseSchedule.nextDueDate(
        currentDueDate: DateTime(2024, 2, 29),
        frequency: 'yearly',
        anchorMonth: 2,
        anchorDay: 29,
      ),
      DateTime(2025, 2, 28),
    );
  });
}
