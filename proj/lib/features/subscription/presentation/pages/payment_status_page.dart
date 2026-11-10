import 'dart:async';

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
    this.farmId = '',
    this.paymentId = '',
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
  String? _receipt;
  String? _description;
  bool _checking = false;
  bool _checkFailed = false;

  @override
  void initState() {
    super.initState();
    _description = widget.resultDescription;
    if (widget.farmId.isNotEmpty && widget.paymentId.isNotEmpty) {
      _refreshStatus();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _refreshStatus(),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (_checking || !mounted || _status != 'pending') return;
    _checking = true;
    try {
      final response = await ref.read(dioProvider).get(
        '/farms/${widget.farmId}/payments',
      );
      final records = response.data is Map ? response.data['data'] : null;
      if (records is List) {
        for (final item in records) {
          if (item is! Map || item['id']?.toString() != widget.paymentId) {
            continue;
          }
          final nextStatus = (item['status'] ?? 'pending').toString().toLowerCase();
          if (!mounted) return;
          setState(() {
            _status = nextStatus;
            _receipt = item['receipt']?.toString();
            _description = item['description']?.toString() ?? _description;
            _checkFailed = false;
          });
          if (_status == 'paid' || _status == 'failed') {
            _pollTimer?.cancel();
          }
          break;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _checkFailed = true);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.paymentMethod.isEmpty ? 'M-Pesa' : widget.paymentMethod;
    final heading = switch (method) {
      'Airtel Money' => 'Airtel Money payment requested',
      'Bank transfer' => 'Bank transfer requested',
      _ => 'M-Pesa payment requested',
    };
    final isPaid = _status == 'paid';
    final isFailed = _status == 'failed';
    final statusLabel = isPaid
        ? 'Payment successful'
        : isFailed
            ? 'Payment failed'
            : 'Awaiting confirmation';
    final statusColor = isPaid
        ? AppColors.success
        : isFailed
            ? AppColors.danger
            : AppColors.warning;

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
                            isPaid ? Icons.check_circle_outline : isFailed
                                ? Icons.error_outline
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
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Amount: ${widget.amount.toStringAsFixed(widget.amount.truncateToDouble() == widget.amount ? 0 : 2)} ${widget.currency}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _description ??
                            'Check your phone and enter your PIN to confirm the payment.',
                      ),
                      if (!isPaid && !isFailed) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Check your phone for the M-Pesa prompt and enter your PIN. This screen will update automatically when Safaricom confirms the payment.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (_checkFailed)
                          TextButton.icon(
                            onPressed: _refreshStatus,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry status check'),
                          ),
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                      if (_receipt != null && _receipt!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'M-Pesa receipt: $_receipt',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
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
