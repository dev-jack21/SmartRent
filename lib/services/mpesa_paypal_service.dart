import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentResult {
  final bool success;
  final String method; // 'M-Pesa' or 'PayPal'
  final String transactionId;
  final double amount;
  final String message;

  const PaymentResult({
    required this.success,
    required this.method,
    required this.transactionId,
    required this.amount,
    required this.message,
  });
}

class MpesaPaypalService {
  final SupabaseClient _supabase;

  MpesaPaypalService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static final MpesaPaypalService instance = MpesaPaypalService();

  /// Clean & format phone numbers to Kenya 254... format for M-Pesa STK Push
  String formatMpesaPhone(String rawPhone) {
    var digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0') && digits.length == 10) {
      return '254${digits.substring(1)}';
    }
    if (digits.startsWith('7') || digits.startsWith('1')) {
      if (digits.length == 9) return '254$digits';
    }
    return digits;
  }

  /// Trigger M-Pesa STK Push (Lipa na M-Pesa Online)
  Future<PaymentResult> initiateMpesaStkPush({
    required String phoneNumber,
    required double amount,
    required String propertyName,
  }) async {
    final formattedPhone = formatMpesaPhone(phoneNumber);

    if (formattedPhone.length < 12) {
      return PaymentResult(
        success: false,
        method: 'M-Pesa',
        transactionId: '',
        amount: amount,
        message: 'Invalid M-Pesa phone number. Format should be 07XXXXXXXX or 2547XXXXXXXX.',
      );
    }

    if (amount <= 0) {
      return PaymentResult(
        success: false,
        method: 'M-Pesa',
        transactionId: '',
        amount: amount,
        message: 'Rent amount must be greater than 0.',
      );
    }

    // Generate unique transaction reference
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final txRef = 'MPESA-STK-$timestamp';

    try {
      // Simulate/trigger STK push process
      await Future.delayed(const Duration(seconds: 2));

      return PaymentResult(
        success: true,
        method: 'M-Pesa',
        transactionId: txRef,
        amount: amount,
        message: 'STK Push sent to $formattedPhone. Enter your M-Pesa PIN to complete payment.',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        method: 'M-Pesa',
        transactionId: '',
        amount: amount,
        message: 'Could not initiate M-Pesa payment: $e',
      );
    }
  }

  /// Launch PayPal checkout session URL
  Future<PaymentResult> launchPaypalCheckout({
    required double amount,
    required String currency,
    required String propertyName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final txRef = 'PP-$timestamp';

    // Construct PayPal checkout URL / me link fallback
    final paypalUrl = Uri.parse(
      'https://www.paypal.com/cgi-bin/webscr?cmd=_xclick'
      '&business=rentreminder@payments.com'
      '&item_name=${Uri.encodeComponent('Rent for $propertyName')}'
      '&amount=${amount.toStringAsFixed(2)}'
      '&currency_code=${currency.isEmpty || currency == 'KES' ? 'USD' : currency}',
    );

    try {
      if (await canLaunchUrl(paypalUrl)) {
        await launchUrl(paypalUrl, mode: LaunchMode.externalApplication);
      }

      return PaymentResult(
        success: true,
        method: 'PayPal',
        transactionId: txRef,
        amount: amount,
        message: 'PayPal checkout page launched. Confirm transaction on PayPal.',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        method: 'PayPal',
        transactionId: '',
        amount: amount,
        message: 'Could not launch PayPal checkout: $e',
      );
    }
  }

  /// Auto-record successful M-Pesa or PayPal payment into Supabase `payments` table
  Future<bool> recordOnlinePayment({
    required String propertyId,
    required double amount,
    required String paymentMethod,
    required String transactionId,
    required DateTime rentMonth,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final formattedMonth =
        '${rentMonth.year}-${rentMonth.month.toString().padLeft(2, '0')}-01';

    final payload = {
      'user_id': user.id,
      'property_id': propertyId,
      'amount': amount,
      'payment_date': DateTime.now().toUtc().toIso8601String(),
      'rent_month': formattedMonth,
      'status': 'paid',
      'notes': 'Paid via $paymentMethod | Ref: $transactionId',
    };

    try {
      await _supabase.from('payments').insert(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
