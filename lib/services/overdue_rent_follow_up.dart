import 'rent_credit_ledger.dart';

class OverdueRentFollowUp {
  final Map<String, dynamic> property;
  final List<RentLedgerEntry> overdueEntries;

  const OverdueRentFollowUp({
    required this.property,
    required this.overdueEntries,
  });

  double get totalOwing =>
      overdueEntries.fold(0, (total, entry) => total + entry.amountOwing);

  static List<OverdueRentFollowUp> build({
    required List<Map<String, dynamic>> properties,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> allocations,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final followUps = <OverdueRentFollowUp>[];

    for (final property in properties) {
      final startDate =
          DateTime.tryParse(property['lease_start_date']?.toString() ?? '') ??
          DateTime.tryParse(property['created_at']?.toString() ?? '');
      if (startDate != null &&
          DateTime(
            startDate.year,
            startDate.month,
          ).isAfter(DateTime(now.year, now.month))) {
        continue;
      }

      final overdueEntries =
          RentCreditLedger.build(
            property: property,
            payments: payments,
            allocations: allocations,
            now: now,
            startMonth: startDate,
          ).where((entry) {
            return entry.dueDate.isBefore(today) && entry.amountOwing > 0;
          }).toList();
      overdueEntries.sort(
        (first, second) => first.month.compareTo(second.month),
      );

      if (overdueEntries.isNotEmpty) {
        followUps.add(
          OverdueRentFollowUp(
            property: property,
            overdueEntries: overdueEntries,
          ),
        );
      }
    }

    followUps.sort(
      (first, second) => second.totalOwing.compareTo(first.totalOwing),
    );
    return followUps;
  }
}
