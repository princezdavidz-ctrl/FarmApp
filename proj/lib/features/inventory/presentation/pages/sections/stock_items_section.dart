import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/inventory/domain/entities/inventory_item.dart';
import 'package:proj/features/inventory/presentation/providers/inventory_providers.dart';

class StockItemsSection extends ConsumerWidget {
  const StockItemsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryItemsProvider);

    return items.when(
      data: (inventoryData) {
        final inventoryItems = inventoryData.items;
        return ListView(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          children: [
            if (inventoryItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                  child: Text(
                    'No inventory items yet',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...inventoryItems.map(
                (item) => Card(
                  margin: const EdgeInsets.only(
                    bottom: AppDimensions.spacingMedium,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getStockColor(
                                  item,
                                ).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                color: _getStockColor(item),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingMedium),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.category} • ${item.sku}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(
                                item.stockStatus,
                                style: TextStyle(
                                  color: _getStockColor(item),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: _getStockColor(
                                item,
                              ).withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Stock',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${item.quantity} ${item.unit}',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Minimum Level',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${item.minimumLevel} ${item.unit}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cost Price',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'KES ${item.costPrice.toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Supplier',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  item.supplier,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            if (item.expiryDate != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Expires',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  Text(
                                    item.expiryDate.toString().split(' ')[0],
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: item.isExpired
                                              ? AppColors.danger
                                              : null,
                                        ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
                        Row(
                          children: [
                            Text(
                              'Location: ${item.storageLocation}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (item.barcode != null)
                              Expanded(
                                child: Text(
                                  ' • Barcode: ${item.barcode}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _showEditDialog(context, ref, item),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () =>
                                  _showMovementDialog(context, ref, item),
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Movement'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Color _getStockColor(dynamic item) {
    if (item.isExpired) return AppColors.danger;
    if (item.isExpiringSoon) return AppColors.warning;
    if (item.isLowStock) return AppColors.warmGold;
    return AppColors.primaryGreen;
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final nameController = TextEditingController(text: item.name);
    final minimumController = TextEditingController(
      text: item.minimumLevel.toString(),
    );
    final costController = TextEditingController(
      text: item.costPrice.toString(),
    );
    final formKey = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit inventory item'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an item name.'
                      : null,
                ),
                TextFormField(
                  controller: minimumController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Minimum level'),
                  validator: _validateNumber,
                ),
                TextFormField(
                  controller: costController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Cost price'),
                  validator: _validateNumber,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  await ref
                      .read(updateInventoryItemProvider.notifier)
                      .updateItem(
                        item.id,
                        name: nameController.text.trim(),
                        minimumLevel: double.parse(minimumController.text),
                        costPrice: double.parse(costController.text),
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
      minimumController.dispose();
      costController.dispose();
    }
  }

  Future<void> _showMovementDialog(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var type = 'stock_in';

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Record movement: ${item.name}'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'stock_in',
                        child: Text('Stock in'),
                      ),
                      DropdownMenuItem(
                        value: 'stock_out',
                        child: Text('Stock out'),
                      ),
                      DropdownMenuItem(
                        value: 'adjustment',
                        child: Text('Adjustment'),
                      ),
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Expired'),
                      ),
                    ],
                    onChanged: (value) => setState(() => type = value ?? type),
                  ),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Quantity (${item.unit})',
                    ),
                    validator: _validatePositiveNumber,
                  ),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  try {
                    await ref
                        .read(recordMovementProvider.notifier)
                        .recordMovement(
                          item.id,
                          type: type,
                          quantity: double.parse(quantityController.text),
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                        );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (error) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(SnackBar(content: Text('$error')));
                    }
                  }
                },
                child: const Text('Record'),
              ),
            ],
          ),
        ),
      );
    } finally {
      quantityController.dispose();
      notesController.dispose();
    }
  }

  String? _validateNumber(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number < 0 ? 'Enter a valid amount.' : null;
  }

  String? _validatePositiveNumber(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number <= 0
        ? 'Enter an amount greater than zero.'
        : null;
  }
}
