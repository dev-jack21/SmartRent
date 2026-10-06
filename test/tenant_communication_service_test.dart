import 'package:flutter_test/flutter_test.dart';
import 'package:rent_reminder/services/tenant_communication_service.dart';

void main() {
  const service = TenantCommunicationService();

  test('cleans Kenyan 07... numbers to 254...', () {
    expect(service.cleanPhoneNumber('0712345678'), '254712345678');
    expect(service.cleanPhoneNumber('+254 712 345 678'), '254712345678');
    expect(service.cleanPhoneNumber('0112345678'), '254112345678');
    expect(service.cleanPhoneNumber('254712345678'), '254712345678');
  });

  test('builds correct WhatsApp and SMS URIs', () {
    final waUri = service.buildWhatsAppUri(
      phone: '0712345678',
      message: 'Hello Rent!',
    );
    expect(waUri.host, 'wa.me');
    expect(waUri.path, '/254712345678');
    expect(waUri.queryParameters['text'], 'Hello Rent!');

    final smsUri = service.buildSmsUri(
      phone: '0712345678',
      message: 'Hello Rent!',
    );
    expect(smsUri.scheme, 'sms');
    expect(smsUri.path, '254712345678');
    expect(smsUri.queryParameters['body'], 'Hello Rent!');
  });

  test('generates expected reminder templates', () {
    final msg = service.upcomingRentReminderMessage(
      propertyName: 'Palm Court',
      unitNumber: 'B4',
      tenantName: 'Alice',
      amount: 25000,
      currency: 'KES',
      dueDate: DateTime(2026, 11, 5),
    );
    expect(msg, contains('Hello Alice,'));
    expect(msg, contains('Palm Court (B4)'));
    expect(msg, contains('KES 25000.00'));
    expect(msg, contains('5/11/2026'));
  });
}
