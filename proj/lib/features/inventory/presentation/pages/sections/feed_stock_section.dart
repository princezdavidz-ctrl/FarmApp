import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/feed/data/feed_api.dart';
import 'package:proj/features/feed/presentation/providers/feed_provider.dart';

class FeedStockSection extends ConsumerStatefulWidget {
  const FeedStockSection({super.key});

  @override
  ConsumerState<FeedStockSection> createState() => _FeedStockSectionState();
}

class _FeedStockSectionState extends ConsumerState<FeedStockSection> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _FeedStockError(
        error: error,
        onRetry: () => ref.invalidate(feedProvider),
      ),
      data: (snapshot) {
        final stock = [...snapshot.stock]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final query = _query.trim().toLowerCase();
        final filtered = stock.where((item) {
          return item.name.toLowerCase().contains(query) ||
              (item.location?.toLowerCase().contains(query) ?? false);
        }).toList();
        final unitTotals = <String, double>{};
        for (final item in stock) {
          unitTotals.update(
            item.unit,
            (value) => value + item.quantity,
            ifAbsent: () => item.quantity,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(feedProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            children: [
              Text(
                'Feed stock',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Track available feed by type, quantity and storage location.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              _StockOverview(
                feedTypes: stock.length,
                unitTotals: unitTotals,
                onAdd: _showAddStockDialog,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search feed or storage location',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stock items',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${filtered.length} of ${stock.length}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (stock.isEmpty)
                const _EmptyFeedStock()
              else if (filtered.isEmpty)
                const _NoFeedStockResults()
              else
                for (final item in filtered)
                  _FeedStockCard(stock: item),
              const SizedBox(height: 12),
              Text(
                'Stock totals are grouped by unit. Kilograms, bags and other units are never added together.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddStockDialog() async {
    final name = TextEditingController();
    final quantity = TextEditingController();
    final cost = TextEditingController();
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
                      DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                      DropdownMenuItem(value: 'bags', child: Text('Bags')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => unit = value ?? unit),
                  ),
                  TextField(
                    controller: cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Unit cost (optional)',
                    ),
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
                  final costText = cost.text.trim();
                  final unitCost = costText.isEmpty
                      ? null
                      : double.tryParse(costText);
                  if (name.text.trim().isEmpty ||
                      amount <= 0 ||
                      (costText.isNotEmpty &&
                          (unitCost == null || unitCost < 0))) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a feed name, a quantity greater than zero, and a valid non-negative unit cost.',
                        ),
                      ),
                    );
                    return;
                  }
                  try {
                    await ref.read(feedProvider.notifier).addStock(
                      name: name.text.trim(),
                      quantity: amount,
                      unit: unit,
                      unitCost: unitCost,
                      location: location.text.trim(),
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  } catch (error) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Could not add feed stock: $error')),
                      );
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
      cost.dispose();
      location.dispose();
    }
  }
}

class _StockOverview extends StatelessWidget {
  const _StockOverview({
    required this.feedTypes,
    required this.unitTotals,
    required this.onAdd,
  });

  final int feedTypes;
  final Map<String, double> unitTotals;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primaryContainer,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$feedTypes feed types',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Current recorded stock',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add feed'),
              ),
            ],
          ),
          if (unitTotals.isNotEmpty) ...[
            const Divider(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final entry in unitTotals.entries)
                  _UnitTotal(unit: entry.key, quantity: entry.value),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _UnitTotal extends StatelessWidget {
  const _UnitTotal({required this.unit, required this.quantity});
  final String unit;
  final double quantity;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _formatQuantity(quantity),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        unit,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.mutedText,
        ),
      ),
    ],
  );
}

class _FeedStockCard extends StatelessWidget {
  const _FeedStockCard({required this.stock});
  final FeedStock stock;

  @override
  Widget build(BuildContext context) {
    final empty = stock.quantity <= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryContainer,
          child: const Icon(
            Icons.grass_outlined,
            color: AppColors.primaryGreen,
          ),
        ),
        title: Text(stock.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              stock.location?.trim().isNotEmpty == true
                  ? stock.location!
                  : 'Storage location not specified',
              if (stock.unitCost != null)
                'Unit cost: ${stock.unitCost!.toStringAsFixed(2)} / ${stock.unit}',
            ].join(' · '),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_formatQuantity(stock.quantity)} ${stock.unit}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              empty ? 'Out of stock' : 'Recorded',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: empty ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedStock extends StatelessWidget {
  const _EmptyFeedStock();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        children: [
          Icon(Icons.grass_outlined, size: 42, color: AppColors.primaryGreen),
          SizedBox(height: 10),
          Text(
            'No feed stock recorded yet',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Add the feed stored on your farm. Recorded stock will also be available when logging feed consumption.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _NoFeedStockResults extends StatelessWidget {
  const _NoFeedStockResults();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(AppDimensions.spacingLarge),
      child: Text(
        'No feed stock matches your search. Try another feed name or storage location.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _FeedStockError extends StatelessWidget {
  const _FeedStockError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.danger, size: 36),
          const SizedBox(height: 8),
          const Text(
            'Could not load feed stock',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);
