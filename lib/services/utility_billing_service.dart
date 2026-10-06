class UtilityBillingService {
  const UtilityBillingService();

  static const UtilityBillingService instance = UtilityBillingService();

  static const List<String> utilityTypes = [
    'Water',
    'Electricity',
    'Internet',
    'Gas',
    'Trash / Service',
    'Other',
  ];

  double calculateUnitsConsumed(double? previousReading, double? currentReading) {
    if (previousReading == null || currentReading == null) return 0;
    if (currentReading < previousReading) return 0;
    return currentReading - previousReading;
  }

  double calculateTotalCharge({
    required double unitsConsumed,
    required double ratePerUnit,
  }) {
    if (unitsConsumed <= 0 || ratePerUnit <= 0) return 0;
    return unitsConsumed * ratePerUnit;
  }

  String buildUtilityBillNotificationMessage({
    required String propertyName,
    String? unitNumber,
    String? tenantName,
    required String utilityType,
    required double totalAmount,
    required String currency,
    required String billMonth,
    double? unitsConsumed,
    double? ratePerUnit,
  }) {
    final greeting = tenantName != null && tenantName.trim().isNotEmpty
        ? 'Hello ${tenantName.trim()},'
        : 'Hello,';
    final unitPart = unitNumber != null && unitNumber.trim().isNotEmpty
        ? ' ($unitNumber)'
        : '';
    final formattedTotal = '$currency ${totalAmount.toStringAsFixed(2)}';
    final meterPart = unitsConsumed != null && unitsConsumed > 0 && ratePerUnit != null
        ? 'Units Consumed: ${unitsConsumed.toStringAsFixed(1)} @ $currency ${ratePerUnit.toStringAsFixed(2)}/unit\n'
        : '';

    return '$greeting\n\n'
        'Utility Bill Notice for $propertyName$unitPart\n'
        'Utility: $utilityType\n'
        'Billing Period: $billMonth\n'
        '$meterPart'
        'Total Due: $formattedTotal\n\n'
        'Kindly settle this alongside your rent or as instructed. Thank you!';
  }
}
