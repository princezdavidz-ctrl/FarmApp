import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/feed/data/feed_api.dart';
import 'package:proj/features/feed/presentation/providers/feed_provider.dart';

class FeedStockSection extends ConsumerWidget {
  const FeedStockSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: AppColors.danger),
              const SizedBox(height: 8),
              Text(
                'Could not load feed stock: $error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(feedProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (snapshot) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Text('Feed stock', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Manage available feed quantities here. Feed usage and schedules remain in Feed.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMedium),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${snapshot.stock.length} feed types',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Total quantity: ${_quantity(snapshot.totalQuantity)} ${_unit(snapshot.stock)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showAddStockDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add feed'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          if (snapshot.stock.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacingLarge),
                child: Text(
                  'No feed stock recorded yet. Add feed to make it available when recording feeding.',
                ),
              ),
            )
          else
            for (final stock in snapshot.stock)
              Card(
                margin: const EdgeInsets.only(
                  bottom: AppDimensions.spacingSmall,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: const Icon(
                      Icons.grass_outlined,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  title: Text(stock.name),
                  subtitle: Text(
                    stock.location?.trim().isNotEmpty == true
                        ? stock.location!
                        : 'Feed available for daily use',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_quantity(stock.quantity)} ${stock.unit}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        stock.quantity <= 50 ? 'Low stock' : 'In stock',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: stock.quantity <= 50
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _showAddStockDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final quantity = TextEditingController();
    final location = TextEditingController();
    var unit = 'kg';
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add feed stock'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Feed name'),
                  ),
                  TextField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: const [
                      DropdownMenuItem(
                        value: 'kg',
                        child: Text('Kilograms (kg)'),
                      ),
                      DropdownMenuItem(value: 'bags', child: Text('Bags')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => unit = value ?? unit),
                  ),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Storage location (optional)',
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
                  final amount = double.tryParse(quantity.text.trim()) ?? 0;
                  if (name.text.trim().isEmpty || amount <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a feed name and a quantity greater than zero.',
                        ),
                      ),
                    );
                    return;
                  }
                  try {
                    await ref
                        .read(feedProvider.notifier)
                        .addStock(
                          name: name.text.trim(),
                          quantity: amount,
                          unit: unit,
                          location: location.text.trim(),
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
                child: const Text('Add stock'),
              ),
            ],
          ),
        ),
      );
    } finally {
      name.dispose();
      quantity.dispose();
      location.dispose();
    }
  }
}

String _quantity(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
String _unit(List<FeedStock> stock) => stock.isEmpty
    ? 'kg'
    : stock.map((item) => item.unit).toSet().length == 1
    ? stock.first.unit
    : 'mixed units';
