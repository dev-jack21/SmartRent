import 'package:flutter/material.dart';
import '../services/mpesa_paypal_service.dart';

class DigitalPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> property;
  final double defaultAmount;

  const DigitalPaymentDialog({
    super.key,
    required this.property,
    required this.defaultAmount,
  });

  @override
  State<DigitalPaymentDialog> createState() => _DigitalPaymentDialogState();
}

class _DigitalPaymentDialogState extends State<DigitalPaymentDialog> {
  final MpesaPaypalService _service = MpesaPaypalService.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isProcessing = false;
  String _selectedCurrency = 'KES';
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _phoneController.text =
        widget.property['tenant_phone']?.toString().trim() ?? '';
    _amountController.text = widget.defaultAmount > 0
        ? widget.defaultAmount.toStringAsFixed(2)
        : (widget.property['monthly_rent']?.toString() ?? '0');
    _selectedCurrency =
        widget.property['currency']?.toString().trim() ?? 'KES';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  Future<void> _payWithMpesa() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an M-Pesa phone number.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Sending M-Pesa STK Push to $phone...';
    });

    final result = await _service.initiateMpesaStkPush(
      phoneNumber: phone,
      amount: _amount,
      propertyName: widget.property['name']?.toString() ?? 'Property',
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _statusMessage = result.message;
      });

      // Record payment into database
      await _service.recordOnlinePayment(
        propertyId: widget.property['id'].toString(),
        amount: _amount,
        paymentMethod: 'M-Pesa STK Push ($phone)',
        transactionId: result.transactionId,
        rentMonth: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('M-Pesa payment of $_selectedCurrency ${_amount.toStringAsFixed(2)} confirmed!'),
          backgroundColor: Colors.green[700],
        ),
      );

      Navigator.pop(context, true);
    } else {
      setState(() {
        _isProcessing = false;
        _statusMessage = result.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _payWithPaypal() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Launching PayPal checkout...';
    });

    final result = await _service.launchPaypalCheckout(
      amount: _amount,
      currency: _selectedCurrency,
      propertyName: widget.property['name']?.toString() ?? 'Property',
    );

    if (!mounted) return;

    if (result.success) {
      // Record payment into database
      await _service.recordOnlinePayment(
        propertyId: widget.property['id'].toString(),
        amount: _amount,
        paymentMethod: 'PayPal Online',
        transactionId: result.transactionId,
        rentMonth: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PayPal transaction initiated! Proof recorded.'),
          backgroundColor: Colors.blue[700],
        ),
      );

      Navigator.pop(context, true);
    } else {
      setState(() {
        _isProcessing = false;
        _statusMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final propertyName =
        widget.property['name']?.toString() ?? 'Rental Property';

    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        titlePadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pay Rent for $propertyName'),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.phone_android), text: 'M-Pesa STK'),
                Tab(icon: Icon(Icons.payment), text: 'PayPal / Card'),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: TabBarView(
            children: [
              // Tab 1: M-Pesa STK Push
              SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.touch_app, color: Colors.green),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Lipa na M-Pesa Online (STK Push)\nSends instant payment prompt to your phone.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'M-Pesa Phone Number',
                        hintText: 'e.g. 0712345678 or 254712345678',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Rent Amount ($_selectedCurrency)',
                        border: const OutlineInputBorder(),
                        prefixText: '$_selectedCurrency ',
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green[700],
                        ),
                        onPressed: _isProcessing ? null : _payWithMpesa,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_to_mobile),
                        label: Text(_isProcessing ? 'Processing STK...' : 'Pay with M-Pesa'),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab 2: PayPal
              SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.credit_card, color: Colors.blue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'PayPal & Credit/Debit Cards\nPay securely via PayPal checkout.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                      items: ['KES', 'USD', 'EUR', 'GBP']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCurrency = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Rent Amount',
                        border: const OutlineInputBorder(),
                        prefixText: '$_selectedCurrency ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                        ),
                        onPressed: _isProcessing ? null : _payWithPaypal,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.open_in_browser),
                        label: Text(_isProcessing ? 'Opening PayPal...' : 'Pay via PayPal'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
