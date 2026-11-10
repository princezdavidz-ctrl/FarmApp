import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/inventory/presentation/providers/inventory_providers.dart';

class SuppliersSection extends ConsumerWidget {
  const SuppliersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);

    return suppliers.when(
      data: (supplierList) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          if (supplierList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                child: Text(
                  'No suppliers yet',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...supplierList.map(
              (supplier) => Card(
                margin: const EdgeInsets.only(
                  bottom: AppDimensions.spacingMedium,
                ),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  title: Text(supplier.name),
                  subtitle: Text(supplier.contact),
                  trailing: Badge(
                    label: Text(supplier.outstandingOrders.toString()),
                    child: Icon(
                      Icons.shopping_cart,
                      color: supplier.outstandingOrders > 0
                          ? AppColors.warning
                          : AppColors.mutedText,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(
                        AppDimensions.spacingMedium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(label: 'Email', value: supplier.email),
                          const Divider(),
                          _InfoRow(label: 'Contact', value: supplier.contact),
                          const Divider(),
                          Text(
                            'Products Supplied',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: supplier.products
                                .map(
                                  (product) => Chip(
                                    label: Text(product),
                                    backgroundColor: AppColors.leaf.withValues(
                                      alpha: 0.2,
                                    ),
                                    labelStyle: const TextStyle(fontSize: 12),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          if (supplier.lastDeliveryDate != null)
                            _InfoRow(
                              label: 'Last Delivery',
                              value: supplier.lastDeliveryDate.toString().split(
                                ' ',
                              )[0],
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _openContact(
                                      context,
                                      Uri(
                                        scheme: 'tel',
                                        path: supplier.contact,
                                      ),
                                      'phone app',
                                    );
                                  },
                                  icon: const Icon(Icons.phone),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _openContact(
                                      context,
                                      Uri(
                                        scheme: 'mailto',
                                        path: supplier.email,
                                        queryParameters: {
                                          'subject':
                                              'Farm App supplier inquiry',
                                        },
                                      ),
                                      'email app',
                                    );
                                  },
                                  icon: const Icon(Icons.email),
                                  label: const Text('Email'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    _openContact(
                                      context,
                                      Uri(
                                        scheme: 'mailto',
                                        path: supplier.email,
                                        queryParameters: {
                                          'subject': 'Purchase order request',
                                          'body':
                                              'Hello ${supplier.name},\n\n'
                                              'Please send us a quotation for:\n'
                                              '${supplier.products.map((product) => '- $product').join('\n')}\n\n'
                                              'Farm: ',
                                        },
                                      ),
                                      'email app',
                                    );
                                  },
                                  icon: const Icon(Icons.add_shopping_cart),
                                  label: const Text('Order'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _openContact(
    BuildContext context,
    Uri uri,
    String service,
  ) async {
    try {
      final opened = await launchUrl(uri);
      if (!context.mounted || opened) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open the $service.')));
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the $service: $error')),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}
