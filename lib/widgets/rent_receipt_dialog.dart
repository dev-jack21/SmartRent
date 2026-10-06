import 'package:flutter/material.dart';
import '../services/rent_receipt_service.dart';
import '../services/tenant_communication_service.dart';

class RentReceiptDialog extends StatelessWidget {
  final Map<String, dynamic> payment;
  final Map<String, dynamic> property;

  const RentReceiptDialog({
    super.key,
    required this.payment,
    required this.property,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> payment,
    required Map<String, dynamic> property,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => RentReceiptDialog(payment: payment, property: property),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentId = payment['id']?.toString() ?? 'N/A';
    final receiptNumber = paymentId.length > 8 ? paymentId.substring(0, 8).toUpperCase() : paymentId;
    final propertyName = property['name']?.toString() ?? 'Rental Property';
    final unitNumber = property['unit_number']?.toString();
    final address = property['address']?.toString();
    final currency = property['currency']?.toString() ?? 'KES';
    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
    final status = payment['status']?.toString() ?? 'paid';
    final notes = payment['notes']?.toString();
    final rentMonth = payment['rent_month']?.toString() ?? 'Current month';
    final tenantName = property['tenant_name']?.toString() ?? 'Tenant';
    final tenantPhone = property['tenant_phone']?.toString();
    final tenantEmail = property['tenant_email']?.toString();
    final paymentDate = DateTime.tryParse(payment['payment_date']?.toString() ?? '') ?? DateTime.now();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.indigo),
          const SizedBox(width: 8),
          const Expanded(child: Text('Rent Receipt')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Receipt #: $receiptNumber',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const Divider(height: 24),
            _infoRow('Property', '$propertyName ${unitNumber != null && unitNumber.isNotEmpty ? "($unitNumber)" : ""}'),
            if (address != null && address.isNotEmpty) _infoRow('Address', address),
            _infoRow('Tenant', tenantName),
            _infoRow('Rent Period', rentMonth),
            _infoRow('Payment Date', '${paymentDate.day}/${paymentDate.month}/${paymentDate.year}'),
            _infoRow('Amount Paid', '$currency ${amount.toStringAsFixed(2)}', isBold: true),
            if (notes != null && notes.isNotEmpty) _infoRow('Reference / Notes', notes),
          ],
        ),
      ),
      actions: [
        if (tenantPhone != null && tenantPhone.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              final message = TenantCommunicationService.instance.paymentReceiptNotificationMessage(
                propertyName: propertyName,
                unitNumber: unitNumber,
                tenantName: tenantName,
                amountPaid: amount,
                currency: currency,
                rentMonth: rentMonth,
                remainingBalance: 0,
              );
              TenantCommunicationService.instance.sendWhatsApp(phone: tenantPhone, message: message);
            },
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('WhatsApp'),
          ),
        FilledButton.tonalIcon(
          onPressed: () async {
            final html = RentReceiptService.instance.generateReceiptHtml(
              receiptNumber: receiptNumber,
              propertyName: propertyName,
              unitNumber: unitNumber,
              propertyAddress: address,
              tenantName: tenantName,
              tenantEmail: tenantEmail,
              tenantPhone: tenantPhone,
              amountPaid: amount,
              currency: currency,
              paymentDate: paymentDate,
              rentMonth: rentMonth,
              paymentStatus: status,
              paymentNotes: notes,
            );
            await RentReceiptService.instance.saveReceiptAsHtml(
              receiptNumber: receiptNumber,
              htmlContent: html,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Receipt file saved. Open in browser to print or export as PDF.')),
            );
          },
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download HTML / PDF'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
