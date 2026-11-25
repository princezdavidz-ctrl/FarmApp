import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class PaymentStatusPage extends ConsumerStatefulWidget {
  const PaymentStatusPage({
    super.key,
    required this.amount,
    required this.currency,
    required this.merchantRequestId,
    required this.checkoutRequestId,
    required this.farmId,
    required this.paymentId,
    this.resultDescription,
    this.paymentMethod = 'M-Pesa',
  });

  final num amount;
  final String currency;
  final String merchantRequestId;
  final String checkoutRequestId;
  final String farmId;
  final String paymentId;
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
      farmId: (payload['farm_id'] ?? '').toString(),
      paymentId: (payload['payment_id'] ?? '').toString(),
      resultDescription: payload['result_description']?.toString(),
      paymentMethod: (payload['payment_method'] ?? 'M-Pesa').toString(),
    );
  }

  @override
  ConsumerState<PaymentStatusPage> createState() => _PaymentStatusPageState();
}

class _PaymentStatusPageState extends ConsumerState<PaymentStatusPage> {
  Timer? _pollTimer;
  String _status = 'pending';
  String? _description;
  bool _isRefreshing = false;
  bool _pollingExpired = false;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    _description = widget.resultDescription;
    if (widget.farmId.isNotEmpty && widget.paymentId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshStatus();
        _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (!mounted || _status != 'pending') return;
          if (_pollCount >= 36) {
            _pollTimer?.cancel();
            setState(() => _pollingExpired = true);
            return;
          }
          _pollCount++;
          _refreshStatus();
        });
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (_isRefreshing || !mounted) return;
    setState(() => _isRefreshing = true);
    try {
      final response = await ref.read(dioProvider).get(
        '/farms/${widget.farmId}/payments/${widget.paymentId}',
      );
      final payload = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final payment = payload['payment'] is Map
          ? Map<String, dynamic>.from(payload['payment'] as Map)
          : <String, dynamic>{};
      final nextStatus = (payment['status'] ?? 'pending').toString().toLowerCase();
      if (!mounted) return;
      setState(() {
        if (nextStatus == 'paid' || nextStatus == 'failed' || nextStatus == 'pending') {
          _status = nextStatus;
        }
        _description = payment['description']?.toString() ?? _description;
        _pollingExpired = false;
      });
      if (_status != 'pending') _pollTimer?.cancel();
    } on DioException {
      // A transient network failure must not be mistaken for a failed payment.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String get _statusLabel => switch (_status) {
    'paid' => 'Payment confirmed',
    'failed' => 'Payment failed',
    _ => 'Awaiting confirmation',
  };

  Color _statusColor(BuildContext context) => switch (_status) {
    'paid' => AppColors.success,
    'failed' => AppColors.danger,
    _ => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final normalizedMethod = widget.paymentMethod.isEmpty ? 'M-Pesa' : widget.paymentMethod;
    final heading = switch (normalizedMethod) {
      'Airtel Money' => 'Airtel Money payment',
      'Bank transfer' => 'Bank transfer',
      _ => 'M-Pesa payment',
    };
    final message = _description ??
        'Check your phone and enter your PIN to confirm the payment.';
    final statusColor = _statusColor(context);

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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isRefreshing && _status == 'pending') ...[
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                            ] else ...[
                              Icon(
                                _status == 'paid'
                                    ? Icons.check_circle_outline
                                    : _status == 'failed'
                                        ? Icons.error_outline
                                        : Icons.hourglass_top,
                                size: 16,
                                color: statusColor,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _statusLabel,
                              style: TextStyle(fontWeight: FontWeight.w600, color: statusColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Amount: ${widget.amount.toStringAsFixed(widget.amount.truncateToDouble() == widget.amount ? 0 : 2)} ${widget.currency}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_status == 'paid'
                          ? 'Your payment has been verified. Your subscription is active.'
                          : _status == 'failed'
                              ? (message.isEmpty ? 'The payment was not completed. You can try again.' : message)
                              : message),
                      if (_status == 'pending') ...[
                        const SizedBox(height: 16),
                        Text(
                          'Keep this screen open while FarmApp checks the payment confirmation. Do not pay again while this request is pending.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (_pollingExpired && _status == 'pending') ...[
                        const SizedBox(height: 12),
                        Text(
                          'Confirmation is taking longer than expected. You can check again; do not start a second payment unless this one is confirmed as failed.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_status == 'paid' && paymentReceiptAvailable) ...[
                        const SizedBox(height: 12),
                        Text('Receipt: ${_description ?? ''}'),
                      ],
                      if (widget.merchantRequestId.isNotEmpty ||
                          widget.checkoutRequestId.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          widget.merchantRequestId.isNotEmpty
                              ? 'Merchant request: ${widget.merchantRequestId}'
                              : 'Checkout request: ${widget.checkoutRequestId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_status == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isRefreshing ? null : _refreshStatus,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Check payment status'),
                          ),
                        ),
                      if (_status == 'failed')
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => context.go('/subscription'),
                            child: const Text('Try payment again'),
                          ),
                        ),
                      if (_status == 'paid')
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.go('/'),
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('Continue to FarmApp'),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Back to home'),
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

  bool get paymentReceiptAvailable => false;
}
