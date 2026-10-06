class RentLedgerEntry {
  final DateTime month;
  final double rent;
  final double cashReceived;
  final double creditApplied;
  final double creditTransferred;
  final double amountOwing;
  final double availableCredit;
  final DateTime dueDate;
  final int daysUntilDue;
  final String status;

  const RentLedgerEntry({
    required this.month,
    required this.rent,
    required this.cashReceived,
    required this.creditApplied,
    required this.creditTransferred,
    required this.amountOwing,
    required this.availableCredit,
    required this.dueDate,
    required this.daysUntilDue,
    required this.status,
  });
}

class RentCreditLedger {
  const RentCreditLedger._();

  static List<RentLedgerEntry> build({
    required Map<String, dynamic> property,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> allocations,
    required DateTime now,
    DateTime? startMonth,
  }) {
    final propertyId = property['id'].toString();
    final currentMonth = DateTime(now.year, now.month);
    final firstTrackedMonth = startMonth == null
        ? currentMonth
        : DateTime(startMonth.year, startMonth.month);
    final totals = <DateTime, _MonthTotals>{};

    _MonthTotals totalsFor(DateTime month) {
      final normalizedMonth = DateTime(month.year, month.month);
      return totals.putIfAbsent(normalizedMonth, _MonthTotals.new);
    }

    totalsFor(firstTrackedMonth);
    totalsFor(currentMonth);

    for (final payment in payments) {
      if (payment['property_id'].toString() != propertyId ||
          payment['status']?.toString().toLowerCase() != 'paid') {
        continue;
      }

      final month =
          _parseMonth(payment['rent_month']) ??
          _parseMonth(payment['payment_date']);
      if (month == null) continue;
      if (startMonth != null && month.isBefore(firstTrackedMonth)) continue;

      final amount = double.tryParse(payment['amount']?.toString() ?? '') ?? 0;
      totalsFor(month).cashReceived += amount;
    }

    for (final allocation in allocations) {
      if (allocation['property_id'].toString() != propertyId) continue;

      final sourceMonth = _parseMonth(allocation['source_month']);
      final targetMonth = _parseMonth(allocation['target_month']);
      final amount =
          double.tryParse(allocation['amount']?.toString() ?? '') ?? 0;
      if (sourceMonth == null || targetMonth == null || amount <= 0) continue;
      if (startMonth != null &&
          (sourceMonth.isBefore(firstTrackedMonth) ||
              targetMonth.isBefore(firstTrackedMonth))) {
        continue;
      }

      totalsFor(sourceMonth).creditTransferred += amount;
      totalsFor(targetMonth).creditApplied += amount;
    }

    final months = totals.keys.toList()..sort();
    final firstMonth = months.first;
    final lastMonth = months.last;
    final monthlyRent =
        double.tryParse(property['monthly_rent']?.toString() ?? '') ?? 0;
    final dueDay = int.tryParse(property['due_day']?.toString() ?? '') ?? 1;
    final today = DateTime(now.year, now.month, now.day);
    final entries = <RentLedgerEntry>[];

    for (
      var month = firstMonth;
      !month.isAfter(lastMonth);
      month = DateTime(month.year, month.month + 1)
    ) {
      final monthTotals = totalsFor(month);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      final dueDate = DateTime(
        month.year,
        month.month,
        dueDay.clamp(1, daysInMonth).toInt(),
      );
      final netBalance =
          monthlyRent -
          monthTotals.cashReceived -
          monthTotals.creditApplied +
          monthTotals.creditTransferred;
      final amountOwing = netBalance > 0 ? netBalance : 0.0;
      final availableCredit = netBalance < 0 ? -netBalance : 0.0;
      final daysUntilDue = dueDate.difference(today).inDays;

      final status = availableCredit > 0
          ? 'Credit'
          : amountOwing == 0
          ? 'Paid'
          : daysUntilDue < 0
          ? 'Overdue'
          : daysUntilDue <= 7
          ? 'Due soon'
          : 'Upcoming';

      entries.add(
        RentLedgerEntry(
          month: month,
          rent: monthlyRent,
          cashReceived: monthTotals.cashReceived,
          creditApplied: monthTotals.creditApplied,
          creditTransferred: monthTotals.creditTransferred,
          amountOwing: amountOwing,
          availableCredit: availableCredit,
          dueDate: dueDate,
          daysUntilDue: daysUntilDue,
          status: status,
        ),
      );
    }

    return entries.reversed.toList();
  }

  static DateTime? _parseMonth(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? null : DateTime(date.year, date.month);
  }
}

class _MonthTotals {
  double cashReceived = 0;
  double creditApplied = 0;
  double creditTransferred = 0;
}
