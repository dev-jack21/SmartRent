import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/utility_billing_service.dart';

void main() {
  const service = UtilityBillingService();

  test('calculates units consumed and total correctly', () {
    expect(service.calculateUnitsConsumed(120.5, 145.5), 25.0);
    expect(service.calculateUnitsConsumed(150, 140), 0); // Meter reset/invalid
    expect(service.calculateTotalCharge(unitsConsumed: 25, ratePerUnit: 150), 3750);
  });

  test('formats utility bill message with meter details', () {
    final msg = service.buildUtilityBillNotificationMessage(
      propertyName: 'Green Heights',
      unitNumber: '4A',
      tenantName: 'John',
      utilityType: 'Water',
      totalAmount: 1800,
      currency: 'KES',
      billMonth: 'October 2026',
      unitsConsumed: 12,
      ratePerUnit: 150,
    );

    expect(msg, contains('Hello John,'));
    expect(msg, contains('Green Heights (4A)'));
    expect(msg, contains('Utility: Water'));
    expect(msg, contains('Units Consumed: 12.0 @ KES 150.00/unit'));
    expect(msg, contains('Total Due: KES 1800.00'));
  });
}
