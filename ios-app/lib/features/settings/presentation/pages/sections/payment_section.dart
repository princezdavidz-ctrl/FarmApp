import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/settings/domain/entities/payment_settings.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';

class PaymentSection extends ConsumerStatefulWidget {
  const PaymentSection({super.key});

  @override
  ConsumerState<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends ConsumerState<PaymentSection> {
  late TextEditingController _mPesaController;
  late TextEditingController _bankAccountController;
  late TextEditingController _bankNameController;
  late TextEditingController _invoicePrefixController;
  late TextEditingController _taxRateController;
  late TextEditingController _vatController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mPesaController = TextEditingController();
    _bankAccountController = TextEditingController();
    _bankNameController = TextEditingController();
    _invoicePrefixController = TextEditingController();
    _taxRateController = TextEditingController();
    _vatController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final paymentSettings = ref.watch(paymentSettingsProvider).valueOrNull;
    if (paymentSettings != null) {
      _mPesaController.text = paymentSettings.mPesaNumber ?? '';
      _bankAccountController.text = paymentSettings.bankAccount ?? '';
      _bankNameController.text = paymentSettings.bankName ?? '';
      _invoicePrefixController.text = paymentSettings.invoicePrefix ?? 'INV';
      _taxRateController.text = paymentSettings.taxRate.toString();
      _vatController.text = paymentSettings.vat.toString();
    }
  }

  @override
  void dispose() {
    _mPesaController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
    _invoicePrefixController.dispose();
    _taxRateController.dispose();
    _vatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final taxRate = double.tryParse(_taxRateController.text.trim());
    final vat = double.tryParse(_vatController.text.trim());
    if (taxRate == null ||
        vat == null ||
        taxRate < 0 ||
        taxRate > 100 ||
        vat < 0 ||
        vat > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter tax and VAT rates from 0 to 100.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(paymentSettingsProvider.notifier)
          .save(
            PaymentSettings(
              mPesaNumber: _mPesaController.text.trim().isEmpty
                  ? null
                  : _mPesaController.text.trim(),
              bankAccount: _bankAccountController.text.trim().isEmpty
                  ? null
                  : _bankAccountController.text.trim(),
              bankName: _bankNameController.text.trim().isEmpty
                  ? null
                  : _bankNameController.text.trim(),
              invoicePrefix: _invoicePrefixController.text.trim().isEmpty
                  ? 'INV'
                  : _invoicePrefixController.text.trim(),
              taxRate: taxRate,
              vat: vat,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment settings saved on this device.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save payment settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentSettings = ref.watch(paymentSettingsProvider);

    return paymentSettings.when(
      data: (_) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          // M-Pesa Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'M-Pesa Payment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  TextField(
                    controller: _mPesaController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'M-Pesa Daraja Account',
                      prefixIcon: Icon(Icons.phone),
                      hintText: '0712345678',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Configure M-Pesa Daraja settings for payment processing',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          // Bank Account Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bank Account',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  TextField(
                    controller: _bankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  TextField(
                    controller: _bankAccountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          // Invoice Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice Settings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  TextField(
                    controller: _invoicePrefixController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Prefix',
                      prefixIcon: Icon(Icons.receipt),
                      hintText: 'INV',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          // Tax & VAT Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tax & VAT',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  TextField(
                    controller: _taxRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tax Rate (%)',
                      prefixIcon: Icon(Icons.percent),
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  TextField(
                    controller: _vatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'VAT (%)',
                      prefixIcon: Icon(Icons.percent),
                      suffixText: '%',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save Payment Settings'),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
