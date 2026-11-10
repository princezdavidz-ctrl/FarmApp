import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  String? _plan;
  List<Map<String, dynamic>> _plans = [];
  bool _loadingPlans = true;

  Map<String, dynamic>? get _selectedPlan => _plans
      .cast<Map<String, dynamic>?>()
      .firstWhere((plan) => plan?['code'] == _plan, orElse: () => null);

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final response = await ref.read(dioProvider).get('/subscription-plans');
      final plans = List<Map<String, dynamic>>.from(
        (response.data['data'] as List<dynamic>? ?? []).map(
          (plan) => Map<String, dynamic>.from(plan as Map),
        ),
      );
      if (mounted) {
        setState(() {
          _plans = plans;
          final motherPigCount =
              ref
                  .read(authProvider)
                  .valueOrNull
                  ?.selectedFarm
                  ?.motherPigCount ??
              0;
          final matching = plans.where((plan) {
            final limit = (plan['pig_limit'] as num?)?.toInt();
            return limit == null || motherPigCount <= limit;
          }).toList();
          _plan = matching.isEmpty ? null : matching.first['code'] as String;
          _loadingPlans = false;
        });
      }
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _loadingPlans = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load subscriptions: $error')),
        );
      }
    }
  }

  Future<void> _continue() async {
    if (_selectedPlan == null) return;

    context.go(
      AppRoutes.paymentMethod,
      extra: {'selected_plan': _selectedPlan},
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Subscription')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your subscription',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'This is selected automatically for your farm based on the number of mother pigs in your farm records.',
          ),
          const SizedBox(height: 24),
          if (_loadingPlans)
            const Center(child: CircularProgressIndicator())
          else if (_selectedPlan == null)
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No subscription matches your farm size yet.'),
              ),
            )
          else
            _SubscriptionPlanCard(plan: _selectedPlan!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadingPlans || _selectedPlan == null
                ? null
                : _continue,
            child: const Text('Proceed'),
          ),
        ],
      ),
    ),
  );
}

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({required this.plan});

  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final amount = plan['amount'];
    final currency = plan['currency'] ?? 'KES';
    final pigLimit = plan['pig_limit'];
    final name = plan['name'] ?? 'Subscription';
    final description = plan['description'] ?? 'Farm subscription';

    final color = switch (name.toString().toLowerCase()) {
      'starter' => AppColors.primaryContainer,
      'growth' => AppColors.warningContainer,
      'enterprise' => AppColors.secondaryContainer,
      _ => AppColors.primaryContainer,
    };
    final accentColor = switch (name.toString().toLowerCase()) {
      'starter' => AppColors.primaryGreen,
      'growth' => AppColors.warmGold,
      'enterprise' => AppColors.pigPink,
      _ => AppColors.primaryGreen,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withAlpha(180), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$amount $currency',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Text(
            pigLimit == null
                ? 'Unlimited pig capacity'
                : 'Up to $pigLimit mother pigs',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
