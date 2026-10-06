
class ScannedReceiptData {
  final double? amount;
  final String? vendor;
  final DateTime? date;
  final String? category;
  final String rawText;

  const ScannedReceiptData({
    this.amount,
    this.vendor,
    this.date,
    this.category,
    required this.rawText,
  });
}
 
class ExpenseOcrService {
  const ExpenseOcrService();

  static const ExpenseOcrService instance = ExpenseOcrService();

  /// Parses text extracted from a receipt to find amounts, vendor names, dates, and categories.
  ScannedReceiptData parseReceiptText(String text) {
    double? detectedAmount;
    String? detectedVendor;
    DateTime? detectedDate;
    String? detectedCategory;

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Amount Extraction (Find lines with Total, Amount, Grand Total or Currency symbols)
    final amountRegExp = RegExp(
      r'(?:TOTAL|AMOUNT|BAL|SUM|PAID|GRAND TOTAL)[\s:]*[$€£KSh]*\s*([0-9]+(?:[.,][0-9]{2})?)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = amountRegExp.firstMatch(line);
      if (match != null) {
        final rawVal = match.group(1)?.replaceAll(',', '');
        if (rawVal != null) {
          detectedAmount = double.tryParse(rawVal);
          if (detectedAmount != null) break;
        }
      }
    }

    // Fallback amount search for standalone currency numbers
    if (detectedAmount == null) {
      final fallbackRegExp = RegExp(r'[$€£]\s*([0-9]+\.[0-9]{2})');
      for (final line in lines) {
        final match = fallbackRegExp.firstMatch(line);
        if (match != null) {
          detectedAmount = double.tryParse(match.group(1) ?? '');
          if (detectedAmount != null) break;
        }
      }
    }

    // 2. Vendor / Store Name (Usually first non-empty line)
    if (lines.isNotEmpty) {
      detectedVendor = lines.first;
    }

    // 3. Category Detection
    final lowerText = text.toLowerCase();
    if (lowerText.contains('plumb') || lowerText.contains('pipe') || lowerText.contains('water')) {
      detectedCategory = 'Plumbing';
    } else if (lowerText.contains('electric') || lowerText.contains('wire') || lowerText.contains('power')) {
      detectedCategory = 'Electricity';
    } else if (lowerText.contains('paint') || lowerText.contains('hardware') || lowerText.contains('depot')) {
      detectedCategory = 'Repairs & Maintenance';
    } else if (lowerText.contains('tax') || lowerText.contains('city') || lowerText.contains('council')) {
      detectedCategory = 'Property Tax';
    } else if (lowerText.contains('insurance')) {
      detectedCategory = 'Insurance';
    } else {
      detectedCategory = 'General Expense';
    }

    // 4. Date Extraction (e.g. 2025-02-15 or 15/02/2025)
    final dateRegExp = RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})|(\d{1,2}[-/]\d{1,2}[-/]\d{4})');
    final dateMatch = dateRegExp.firstMatch(text);
    if (dateMatch != null) {
      detectedDate = DateTime.tryParse(dateMatch.group(0) ?? '');
    }

    return ScannedReceiptData(
      amount: detectedAmount,
      vendor: detectedVendor,
      date: detectedDate ?? DateTime.now(),
      category: detectedCategory,
      rawText: text,
    );
  }
}
