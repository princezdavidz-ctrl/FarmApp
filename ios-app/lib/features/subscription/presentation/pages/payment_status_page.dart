import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';

class PaymentStatusPage extends StatelessWidget {
  const PaymentStatusPage({
    super.key,
    required this.amount,
    required this.currency,
    required this.merchantRequestId,
    required this.checkoutRequestId,
    this.resultDescription,
    this.paymentMethod = 'M-Pesa',
  });

  final num amount;
  final String currency;
  final String merchantRequestId;
  final String checkoutRequestId;
  final String? resultDescription;
  final String paymentMethod;

  factory PaymentStatusPage.fromExtra(Object? extra) {
    final payload = extra is Map
        ? Map<String, dynamic>.from(extra)
        : <String, dynamic>{};
    return PaymentStatusPage(
      amount: payload['amount'] is num
          ? payload['amount'] as num
          : num.tryParse(payload['amount']?.toString() ?? '0') ?? 0,
      currency: (payload['currency'] ?? 'KES').toString(),
      merchantRequestId:
          (payload['merchant_request_id'] ?? payload['merchantRequestId'] ?? '')
              .toString(),
      checkoutRequestId:
          (payload['checkout_request_id'] ?? payload['checkoutRequestId'] ?? '')
              .toString(),
      resultDescription: payload['result_description']?.toString(),
      paymentMethod: (payload['payment_method'] ?? 'M-Pesa').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedMethod = paymentMethod.isEmpty ? 'M-Pesa' : paymentMethod;
    final message =
        resultDescription ??
        'Check your phone and enter your PIN to confirm the payment.';
    final heading = switch (normalizedMethod) {
      'Airtel Money' => 'Airtel Money payment requested',
      'Bank transfer' => 'Bank transfer requested',
      _ => 'M-Pesa payment requested',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Payment status')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            normalizedMethod == 'Bank transfer'
                                ? Icons.account_balance_outlined
                                : Icons.phone_android_outlined,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              heading,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warningContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Awaiting confirmation',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Amount: ${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $currency',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(message),
                      const SizedBox(height: 16),
                      Text(switch (normalizedMethod) {
                        'Airtel Money' =>
                          'Open your Airtel Money wallet and approve the payment request to complete the transaction.',
                        'Bank transfer' =>
                          'Use your banking app or branch transfer to complete the payment for this subscription.',
                        _ =>
                          'Check your phone for the M-Pesa prompt and enter your PIN to complete the transaction.',
                      }, style: Theme.of(context).textTheme.bodyMedium),
                      if (merchantRequestId.isNotEmpty ||
                          checkoutRequestId.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          merchantRequestId.isNotEmpty
                              ? 'Merchant request: $merchantRequestId'
                              : 'Checkout request: $checkoutRequestId',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Back to home'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
