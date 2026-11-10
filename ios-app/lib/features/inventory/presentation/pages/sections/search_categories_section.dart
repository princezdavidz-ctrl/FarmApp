import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/inventory/domain/entities/inventory_item.dart';
import 'package:proj/features/inventory/presentation/providers/inventory_providers.dart';

final filteredInventoryItemsProvider = FutureProvider.autoDispose
    .family<
      ({List<InventoryItem> items, Map<String, dynamic> summary}),
      ({String query, String category})
    >((ref, filters) async {
      final inventoryData = await ref.watch(inventoryItemsProvider.future);
      final query = filters.query.trim().toLowerCase();

      final items = inventoryData.items.where((item) {
        final matchesQuery =
            query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.sku.toLowerCase().contains(query) ||
            (item.barcode?.toLowerCase().contains(query) ?? false);
        final matchesCategory =
            filters.category.isEmpty || item.category == filters.category;
        return matchesQuery && matchesCategory;
      }).toList();

      return (items: items, summary: inventoryData.summary);
    });

class SearchCategoriesSection extends ConsumerStatefulWidget {
  const SearchCategoriesSection({super.key});

  @override
  ConsumerState<SearchCategoriesSection> createState() =>
      _SearchCategoriesSectionState();
}

class _SearchCategoriesSectionState
    extends ConsumerState<SearchCategoriesSection> {
  final _searchController = TextEditingController();
  String _selectedCategory = '';

  static const categories = [
    'Feed',
    'Medicines',
    'Vaccines',
    'Equipment',
    'Cleaning Supplies',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text;
    final items = ref.watch(
      filteredInventoryItemsProvider((
        query: searchQuery,
        category: _selectedCategory,
      )),
    );

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name, SKU, or barcode...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radius),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),

        // Categories
        Text('Categories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _selectedCategory.isEmpty,
              onSelected: (_) {
                setState(() => _selectedCategory = '');
              },
            ),
            ...categories.map(
              (category) => FilterChip(
                label: Text(category),
                selected: _selectedCategory == category,
                onSelected: (_) {
                  setState(() => _selectedCategory = category);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLarge),

        // Results
        items.when(
          data: (searchItems) => searchItems.items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                    child: Text(
                      'No items found',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${searchItems.items.length} item${searchItems.items.length == 1 ? '' : 's'} found',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ...searchItems.items.map(
                      (item) => Card(
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getStockColor(
                                item,
                              ).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.inventory_2,
                              color: _getStockColor(item),
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text('${item.category} • SKU: ${item.sku}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                item.stockStatus,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getStockColor(item),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _showItemDetails(context, item),
                        ),
                      ),
                    ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ],
    );
  }

  Color _getStockColor(dynamic item) {
    if (item.isExpired) return AppColors.danger;
    if (item.isExpiringSoon) return AppColors.warning;
    if (item.isLowStock) return AppColors.warmGold;
    return AppColors.primaryGreen;
  }

  void _showItemDetails(BuildContext context, InventoryItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category: ${item.category}'),
              Text('SKU: ${item.sku}'),
              Text('Quantity: ${item.quantity} ${item.unit}'),
              Text('Minimum level: ${item.minimumLevel} ${item.unit}'),
              Text('Cost price: ${item.costPrice}'),
              if (item.supplier.isNotEmpty) Text('Supplier: ${item.supplier}'),
              if (item.expiryDate != null)
                Text('Expiry: ${item.expiryDate!.toString().split(' ')[0]}'),
              if (item.barcode?.isNotEmpty == true)
                Text('Barcode: ${item.barcode}'),
              if (item.storageLocation.isNotEmpty)
                Text('Storage location: ${item.storageLocation}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
