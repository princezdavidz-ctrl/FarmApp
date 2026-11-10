import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  late Future<_BillingData> _billing;

  @override
  void initState() {
    super.initState();
    _billing = _load();
  }

  Future<_BillingData> _load() async {
    final session = ref.read(authProvider).valueOrNull;
    final farm = session?.selectedFarm ?? session?.farms.firstOrNull;
    if (farm == null) throw StateError('Select a farm to view billing.');

    final dio = ref.read(dioProvider);
    final responses = await Future.wait([
      dio.get<Map<String, dynamic>>('/subscription-plans'),
      dio.get<Map<String, dynamic>>('/farms/${farm.id}/payments'),
    ]);
    final plans = (responses[0].data?['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final payments = (responses[1].data?['data'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final currentPlan = plans.cast<Map<String, dynamic>?>().firstWhere(
      (plan) => plan?['code'] == farm.subscriptionPlan,
      orElse: () => null,
    );

    return _BillingData(
      plan: currentPlan,
      planCode: farm.subscriptionPlan,
      farmName: farm.name,
      payments: payments,
    );
  }

  Future<void> _refresh() async {
    final request = _load();
    setState(() => _billing = request);
    await request;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Billing & subscription')),
    body: FutureBuilder<_BillingData>(
      future: _billing,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load billing details. Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _billing = _load()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                data.farmName,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _CurrentPlanCard(
                plan: data.plan,
                planCode: data.planCode,
                latestPayment: data.payments.firstOrNull,
                onChangePlan: () => context.go(AppRoutes.subscription),
              ),
              const SizedBox(height: 24),
              Text(
                'Payment history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (data.payments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No subscription payments yet.'),
                  ),
                )
              else
                for (final payment in data.payments)
                  _PaymentTile(payment: payment),
            ],
          ),
        );
      },
    ),
  );
}

class _BillingData {
  const _BillingData({
    required this.plan,
    required this.planCode,
    required this.farmName,
    required this.payments,
  });

  final Map<String, dynamic>? plan;
  final String? planCode;
  final String farmName;
  final List<Map<String, dynamic>> payments;
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.plan,
    required this.planCode,
    required this.latestPayment,
    required this.onChangePlan,
  });

  final Map<String, dynamic>? plan;
  final String? planCode;
  final Map<String, dynamic>? latestPayment;
  final VoidCallback onChangePlan;

  @override
  Widget build(BuildContext context) {
    final planName = plan?['name']?.toString() ?? planCode ?? 'No active plan';
    final description = plan?['description']?.toString();
    final amount = plan?['amount'];
    final currency = plan?['currency']?.toString() ?? 'KES';
    final pigLimit = plan?['pig_limit'];
    final latestStatus = latestPayment?['status']?.toString();
    final latestStatusColor = _paymentStatusColor(latestStatus);

    return Card(
      color: AppColors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('Current subscription')),
              ],
            ),
            if (latestStatus != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: latestStatusColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Latest payment: ${_paymentStatusLabel(latestStatus)}',
                  style: TextStyle(
                    color: latestStatusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              planName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (amount != null) ...[
              const SizedBox(height: 8),
              Text(
                '$amount $currency',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
            if (plan != null) ...[
              const SizedBox(height: 6),
              Text(
                pigLimit == null
                    ? 'Unlimited mother pigs'
                    : 'Up to $pigLimit mother pigs',
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onChangePlan,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('View plans & payment options'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final status = payment['status']?.toString() ?? 'unknown';
    final color = _paymentStatusColor(status);
    final date = DateTime.tryParse(
      payment['paid_at']?.toString() ?? payment['created_at']?.toString() ?? '',
    );
    final amount = _formatAmount(payment['amount']);
    final currency = payment['currency']?.toString() ?? '';
    final receipt = payment['receipt']?.toString();
    final description = payment['description']?.toString();

    return Card(
      child: ListTile(
        leading: Icon(Icons.receipt_long_outlined, color: color),
        title: Text(
          '$amount $currency'.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            payment['plan_code']?.toString() ?? 'Subscription',
            if (date != null) _formatDate(date),
            if (receipt != null && receipt.isNotEmpty) 'Receipt $receipt',
            if (description != null && description.isNotEmpty) description,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          constraints: const BoxConstraints(maxWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _paymentStatusLabel(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

Color _paymentStatusColor(String? status) => switch (status?.toLowerCase()) {
  'paid' => AppColors.success,
  'failed' => AppColors.danger,
  _ => AppColors.warning,
};

String _paymentStatusLabel(String status) {
  final normalized = status.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) return 'Unknown';
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _formatAmount(Object? value) {
  final amount = num.tryParse(value?.toString() ?? '');
  if (amount == null) return '—';
  return amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2);
}
