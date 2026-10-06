import 'package:url_launcher/url_launcher.dart';

class TenantCommunicationService {
  const TenantCommunicationService();

  static const TenantCommunicationService instance =
      TenantCommunicationService();

  /// Cleans phone numbers to ensure they work smoothly with WhatsApp & SMS.
  /// Handles Kenyan 07... / 01... numbers into 254... if applicable.
  String cleanPhoneNumber(String rawPhone, {String defaultCountryCode = '254'}) {
    var digits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) {
      return digits.substring(1);
    }
    if (digits.startsWith('0') && digits.length == 10) {
      return '$defaultCountryCode${digits.substring(1)}';
    }
    return digits;
  }

  Uri buildWhatsAppUri({required String phone, required String message}) {
    final cleaned = cleanPhoneNumber(phone);
    return Uri.parse(
      'https://wa.me/$cleaned?text=${Uri.encodeComponent(message)}',
    );
  }

  Uri buildSmsUri({required String phone, required String message}) {
    final cleaned = cleanPhoneNumber(phone);
    return Uri(
      scheme: 'sms',
      path: cleaned,
      queryParameters: {'body': message},
    );
  }

  String upcomingRentReminderMessage({
    required String propertyName,
    String? unitNumber,
    String? tenantName,
    required double amount,
    required String currency,
    required DateTime dueDate,
  }) {
    final greeting = tenantName != null && tenantName.trim().isNotEmpty
        ? 'Hello ${tenantName.trim()},'
        : 'Hello,';
    final unitPart = unitNumber != null && unitNumber.trim().isNotEmpty
        ? ' ($unitNumber)'
        : '';
    final dateStr = '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    final formattedAmount = '$currency ${amount.toStringAsFixed(2)}';

    return '$greeting\n\n'
        'This is a friendly reminder that rent for $propertyName$unitPart '
        'of $formattedAmount is due on $dateStr.\n\n'
        'Please let us know once payment has been made. Thank you!';
  }

  String dueTodayReminderMessage({
    required String propertyName,
    String? unitNumber,
    String? tenantName,
    required double amount,
    required String currency,
  }) {
    final greeting = tenantName != null && tenantName.trim().isNotEmpty
        ? 'Hello ${tenantName.trim()},'
        : 'Hello,';
    final unitPart = unitNumber != null && unitNumber.trim().isNotEmpty
        ? ' ($unitNumber)'
        : '';
    final formattedAmount = '$currency ${amount.toStringAsFixed(2)}';

    return '$greeting\n\n'
        'Friendly reminder that rent for $propertyName$unitPart '
        'of $formattedAmount is DUE TODAY.\n\n'
        'Kindly settle at your earliest convenience and share the confirmation. Thank you!';
  }

  String overdueReminderMessage({
    required String propertyName,
    String? unitNumber,
    String? tenantName,
    required double totalOwing,
    required String currency,
    required List<String> overdueMonths,
  }) {
    final greeting = tenantName != null && tenantName.trim().isNotEmpty
        ? 'Hello ${tenantName.trim()},'
        : 'Hello,';
    final unitPart = unitNumber != null && unitNumber.trim().isNotEmpty
        ? ' ($unitNumber)'
        : '';
    final formattedAmount = '$currency ${totalOwing.toStringAsFixed(2)}';
    final monthsStr = overdueMonths.join(', ');

    return '$greeting\n\n'
        'This is a follow-up regarding outstanding rent for $propertyName$unitPart.\n\n'
        'Overdue Period: $monthsStr\n'
        'Total Overdue: $formattedAmount\n\n'
        'Please arrange payment as soon as possible, or reach out if you need to discuss. Thank you!';
  }

  String paymentReceiptNotificationMessage({
    required String propertyName,
    String? unitNumber,
    String? tenantName,
    required double amountPaid,
    required String currency,
    required String rentMonth,
    required double remainingBalance,
  }) {
    final greeting = tenantName != null && tenantName.trim().isNotEmpty
        ? 'Hello ${tenantName.trim()},'
        : 'Hello,';
    final unitPart = unitNumber != null && unitNumber.trim().isNotEmpty
        ? ' ($unitNumber)'
        : '';
    final formattedPaid = '$currency ${amountPaid.toStringAsFixed(2)}';
    final balanceNotice = remainingBalance <= 0
        ? 'Your account is fully settled for $rentMonth.'
        : 'Remaining balance for $rentMonth: $currency ${remainingBalance.toStringAsFixed(2)}.';

    return '$greeting\n\n'
        'Payment Confirmation Received!\n'
        'Property: $propertyName$unitPart\n'
        'Amount Paid: $formattedPaid\n'
        'Rent Period: $rentMonth\n\n'
        '$balanceNotice\n\n'
        'Thank you for your payment!';
  }

  Future<bool> sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    final uri = buildWhatsAppUri(phone: phone, message: message);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> sendSms({
    required String phone,
    required String message,
  }) async {
    final uri = buildSmsUri(phone: phone, message: message);
    return launchUrl(uri);
  }
}
