class AiPropertyAssistantService {
  const AiPropertyAssistantService();

  static const AiPropertyAssistantService instance =
      AiPropertyAssistantService();

  /// Generate professional late rent reminder draft
  String generatePoliteRentReminder({
    required String tenantName,
    required String propertyName,
    required double amount,
    required String currency,
    required DateTime dueDate,
  }) {
    final dateStr = '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    final formattedAmount = '$currency ${amount.toStringAsFixed(2)}';

    return 'Dear ${tenantName.isEmpty ? 'Tenant' : tenantName},\n\n'
        'This is a courteous reminder regarding rent for $propertyName ($formattedAmount) which was due on $dateStr.\n\n'
        'Please arrange payment at your earliest convenience or let us know if you require an extension. Thank you for your prompt attention!';
  }

  /// Generate professional lease renewal proposal draft
  String generateLeaseRenewalProposal({
    required String tenantName,
    required String propertyName,
    required double currentRent,
    required double proposedRent,
    required String currency,
    required DateTime newLeaseEnd,
  }) {
    final dateStr = '${newLeaseEnd.day}/${newLeaseEnd.month}/${newLeaseEnd.year}';
    return 'Dear ${tenantName.isEmpty ? 'Tenant' : tenantName},\n\n'
        'We hope you are enjoying your stay at $propertyName.\n\n'
        'We would love to invite you to renew your lease agreement through $dateStr. '
        'The proposed monthly rent for the upcoming term will be $currency ${proposedRent.toStringAsFixed(2)}.\n\n'
        'Please confirm your acceptance via the app Digital Lease screen. Best regards!';
  }

  /// Answer general property management queries
  String answerPropertyQuery(String question) {
    final q = question.toLowerCase();
    if (q.contains('deposit') || q.contains('deduction')) {
      return 'Security deposits are held as security against unpaid rent or physical damages. '
          'Use the Move-Out Inspection checklist to itemize repair deductions before issuing a net deposit refund.';
    } else if (q.contains('evict') || q.contains('notice')) {
      return 'Standard rental regulations require a written 30-day notice prior to lease termination or eviction proceedings.';
    } else if (q.contains('tax') || q.contains('expense')) {
      return 'All property repair expenses, utility payments, and management fees can be deducted from gross rental income to calculate taxable net income.';
    } else {
      return 'Property Assistant: I am ready to help draft lease renewal letters, rent reminders, or answer property management questions!';
    }
  }
}
