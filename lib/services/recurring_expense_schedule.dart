class RecurringExpenseSchedule {
  const RecurringExpenseSchedule._();

  static DateTime nextDueDate({
    required DateTime currentDueDate,
    required String frequency,
    required int anchorMonth,
    required int anchorDay,
  }) {
    final nextYear = frequency == 'yearly'
        ? currentDueDate.year + 1
        : currentDueDate.year + (currentDueDate.month == 12 ? 1 : 0);
    final nextMonth = frequency == 'yearly'
        ? anchorMonth
        : (currentDueDate.month == 12 ? 1 : currentDueDate.month + 1);
    final daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;

    return DateTime(nextYear, nextMonth, anchorDay.clamp(1, daysInMonth));
  }
}
