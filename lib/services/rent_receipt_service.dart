import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

class RentReceiptService {
  const RentReceiptService();

  static const RentReceiptService instance = RentReceiptService();

  String generateReceiptHtml({
    required String receiptNumber,
    required String propertyName,
    String? unitNumber,
    String? propertyAddress,
    String? tenantName,
    String? tenantEmail,
    String? tenantPhone,
    required double amountPaid,
    required String currency,
    required DateTime paymentDate,
    required String rentMonth,
    required String paymentStatus,
    String? paymentNotes,
    double? balanceRemaining,
    String? landlordName,
  }) {
    final unitText = unitNumber != null && unitNumber.isNotEmpty ? 'Unit $unitNumber' : '';
    final formattedDate = '${paymentDate.day}/${paymentDate.month}/${paymentDate.year}';
    final formattedAmount = '$currency ${amountPaid.toStringAsFixed(2)}';
    final balanceText = balanceRemaining != null
        ? '$currency ${balanceRemaining.toStringAsFixed(2)}'
        : '0.00';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Rent Receipt - $receiptNumber</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; color: #1e293b; margin: 0; padding: 24px; }
    .receipt-container { max-width: 620px; margin: 0 auto; background: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); overflow: hidden; }
    .header { background: #4f46e5; color: #ffffff; padding: 24px; }
    .header-title { font-size: 24px; font-weight: 700; margin: 0; }
    .header-sub { font-size: 13px; opacity: 0.9; margin-top: 4px; }
    .content { padding: 24px; }
    .grid { display: flex; justify-content: space-between; margin-bottom: 20px; }
    .col { flex: 1; }
    .label { font-size: 12px; font-weight: 600; text-transform: uppercase; color: #64748b; margin-bottom: 4px; }
    .value { font-size: 15px; font-weight: 500; color: #0f172a; }
    .badge { display: inline-block; padding: 4px 10px; border-radius: 9999px; font-size: 12px; font-weight: 700; text-transform: uppercase; background: #dcfce7; color: #15803d; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; margin-bottom: 24px; }
    th { text-align: left; padding: 10px 12px; background: #f1f5f9; font-size: 12px; font-weight: 600; color: #475569; border-bottom: 1px solid #cbd5e1; }
    td { padding: 12px; border-bottom: 1px solid #e2e8f0; font-size: 14px; }
    .total-row { font-weight: 700; font-size: 16px; background: #f8fafc; }
    .footer { padding: 16px 24px; background: #f8fafc; border-top: 1px solid #e2e8f0; text-align: center; font-size: 12px; color: #64748b; }
    @media print {
      body { background: #ffffff; padding: 0; }
      .receipt-container { box-shadow: none; border: none; max-width: 100%; }
    }
  </style>
</head>
<body>
  <div class="receipt-container">
    <div class="header">
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <h1 class="header-title">RENT PAYMENT RECEIPT</h1>
          <div class="header-sub">Official Proof of Payment</div>
        </div>
        <div style="text-align: right;">
          <div style="font-size: 14px; font-weight: 600;">Receipt #: $receiptNumber</div>
          <div style="font-size: 12px; opacity: 0.85;">Date: $formattedDate</div>
        </div>
      </div>
    </div>

    <div class="content">
      <div class="grid">
        <div class="col">
          <div class="label">Received From:</div>
          <div class="value">${tenantName ?? 'Tenant'}</div>
          ${tenantEmail != null ? '<div style="font-size: 13px; color: #64748b;">$tenantEmail</div>' : ''}
          ${tenantPhone != null ? '<div style="font-size: 13px; color: #64748b;">$tenantPhone</div>' : ''}
        </div>
        <div class="col" style="text-align: right;">
          <div class="label">Property Details:</div>
          <div class="value">$propertyName ${unitText.isNotEmpty ? '• $unitText' : ''}</div>
          ${propertyAddress != null ? '<div style="font-size: 13px; color: #64748b;">$propertyAddress</div>' : ''}
        </div>
      </div>

      <table>
        <thead>
          <tr>
            <th>Description</th>
            <th>Rent Period</th>
            <th>Status</th>
            <th style="text-align: right;">Amount Paid</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Rent payment for $propertyName $unitText</td>
            <td>$rentMonth</td>
            <td><span class="badge">$paymentStatus</span></td>
            <td style="text-align: right; font-weight: 600;">$formattedAmount</td>
          </tr>
          ${paymentNotes != null && paymentNotes.isNotEmpty ? '<tr><td colspan="4" style="color: #64748b; font-size: 13px;"><em>Note / Ref: $paymentNotes</em></td></tr>' : ''}
          <tr class="total-row">
            <td colspan="3">Total Paid</td>
            <td style="text-align: right; color: #4f46e5;">$formattedAmount</td>
          </tr>
          <tr>
            <td colspan="3" style="color: #64748b;">Balance Remaining for Period</td>
            <td style="text-align: right; font-weight: 500;">$balanceText</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="footer">
      Generated via Rent Reminder • ${landlordName != null ? 'Issued by $landlordName' : 'Thank you for your timely payment.'}
    </div>
  </div>
</body>
</html>
''';
  }

  Future<String?> saveReceiptAsHtml({
    required String receiptNumber,
    required String htmlContent,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(htmlContent));
    return FileSaver.instance.saveFile(
      name: 'receipt_$receiptNumber.html',
      bytes: bytes,
    );
  }
}
