import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/domain/entities/farm.dart';
import '../../../auth/domain/entities/session.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class PaymentMethodPage extends ConsumerStatefulWidget {
  const PaymentMethodPage({super.key, required this.selectedPlan});

  final Map<String, dynamic> selectedPlan;

  factory PaymentMethodPage.fromExtra(Object? extra) {
    final payload = extra is Map
        ? Map<String, dynamic>.from(extra)
        : <String, dynamic>{};
    return PaymentMethodPage(
      selectedPlan: Map<String, dynamic>.from(
        payload['selected_plan'] is Map
            ? payload['selected_plan'] as Map
            : <String, dynamic>{},
      ),
    );
  }

  @override
  ConsumerState<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends ConsumerState<PaymentMethodPage> {
  String _selectedMethod = 'M-Pesa';
  bool _isSubmitting = false;
  Farm? _selectedFarm;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final session = ref.read(authProvider).valueOrNull;
    final farms = session?.farms ?? const <Farm>[];
    _selectedFarm = session?.selectedFarm ?? (farms.isNotEmpty ? farms.first : null);
    _phoneController = TextEditingController(
      text: ref.read(authProvider).valueOrNull?.user.phone ?? '',
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _normalizeKenyanPhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final cleaned = digits.startsWith('+') ? digits.substring(1) : digits;

    if (cleaned.startsWith('0')) {
      return '254${cleaned.substring(1)}';
    }

    if (cleaned.startsWith('254')) {
      return cleaned;
    }

    return cleaned.isEmpty ? null : '254$cleaned';
  }

  Future<void> _handleProceed() async {
    final amount = widget.selectedPlan['amount'];
    final currency = widget.selectedPlan['currency'] ?? 'KES';
    final planCode = widget.selectedPlan['code'] ?? widget.selectedPlan['name'];
    final session = ref.read(authProvider).valueOrNull;
    final selectedFarm =
        _selectedFarm ??
        session?.selectedFarm ??
        (session?.farms.isNotEmpty ?? false ? session!.farms.first : null);
    final phone = _normalizeKenyanPhone(_phoneController.text);

    if (_selectedMethod != 'M-Pesa') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_selectedMethod is not available for this payment flow yet.',
          ),
        ),
      );
      return;
    }

    if (phone == null || !RegExp(r'^254[17]\d{8}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Kenyan M-Pesa number.')),
      );
      return;
    }

    if (selectedFarm == null || selectedFarm.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a farm before starting the payment.'),
        ),
      );
      return;
    }

    if (planCode == null || planCode.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This plan is missing its payment code.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '/farms/${selectedFarm.id}/subscription/payment',
            data: {'plan': planCode.toString(), 'phone': phone},
          );

      final payment = response.data['payment'] is Map
          ? Map<String, dynamic>.from(response.data['payment'] as Map)
          : <String, dynamic>{};

      if (!mounted) return;

      final resultDescription =
          (payment['result_description'] ??
                  'M-Pesa prompt sent. Check your phone and enter your PIN.')
              .toString();

      context.go(
        AppRoutes.paymentStatus,
        extra: {
          'amount': amount,
          'currency': currency,
          'payment_method': _selectedMethod,
          'merchant_request_id': payment['merchant_request_id'] ?? '',
          'checkout_request_id': payment['checkout_request_id'] ?? '',
          'result_description': resultDescription,
        },
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data is Map
          ? Map<String, dynamic>.from(error.response!.data as Map)
          : <String, dynamic>{};
      final message = (data['message'] ?? data['error'] ??
              'Unable to start the M-Pesa payment.')
          .toString();
      final details = [
        if (data['provider_code'] != null) 'Code ${data['provider_code']}',
        if (data['reference'] != null) 'Reference ${data['reference']}',
      ];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(details.isEmpty ? message : '$message (${details.join(', ')})')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start the M-Pesa payment: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.selectedPlan['amount'];
    final currency = widget.selectedPlan['currency'] ?? 'KES';
    final planName = widget.selectedPlan['name'] ?? 'Selected plan';

    return Scaffold(
      appBar: AppBar(title: const Text('Payment method')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How would you like to pay?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Your selected plan: $planName',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.card_membership_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$amount $currency',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if ((ref.watch(authProvider).valueOrNull?.farms ?? const <Farm>[]).isNotEmpty) ...[
                DropdownButtonFormField<Farm>(
                  value: _selectedFarm,
                  decoration: const InputDecoration(
                    labelText: 'Farm',
                    prefixIcon: Icon(Icons.agriculture_outlined),
                  ),
                  items: (ref.watch(authProvider).valueOrNull?.farms ?? const <Farm>[])
                      .map(
                        (farm) => DropdownMenuItem<Farm>(
                          value: farm,
                          child: Text(farm.name),
                        ),
                      )
                      .toList(),
                  onChanged: (farm) {
                    if (farm == null) return;
                    final session = ref.read(authProvider).valueOrNull;
                    if (session == null) return;
                    ref.read(authProvider.notifier).setSession(
                      Session(
                        accessToken: session.accessToken,
                        refreshToken: session.refreshToken,
                        user: session.user,
                        farms: session.farms,
                        selectedFarm: farm,
                      ),
                    );
                    setState(() => _selectedFarm = farm);
                  },
                ),
                const SizedBox(height: 16),
              ],
              _PaymentOption(
                title: 'M-Pesa',
                subtitle: 'Pay directly from your phone wallet',
                value: 'M-Pesa',
                selected: _selectedMethod,
                onSelected: (value) => setState(() => _selectedMethod = value),
              ),
              if (_selectedMethod == 'M-Pesa') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa phone number',
                    hintText: '0712 345 678',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _PaymentOption(
                title: 'Airtel Money',
                subtitle: 'Quick mobile money payment',
                value: 'Airtel Money',
                selected: _selectedMethod,
                onSelected: (value) => setState(() => _selectedMethod = value),
              ),
              const SizedBox(height: 12),
              _PaymentOption(
                title: 'Bank transfer',
                subtitle: 'Pay through your bank account',
                value: 'Bank transfer',
                selected: _selectedMethod,
                onSelected: (value) => setState(() => _selectedMethod = value),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _handleProceed,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Proceed'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value == 'M-Pesa'
                  ? Icons.phone_android_outlined
                  : value == 'Airtel Money'
                  ? Icons.account_balance_wallet_outlined
                  : Icons.account_balance_outlined,
              color: isSelected ? AppColors.primaryGreen : AppColors.text,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (choice) => onSelected(choice ?? value),
              child: Radio<String>(value: value),
            ),
          ],
        ),
      ),
    );
  }
}
