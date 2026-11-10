import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/inventory/presentation/providers/inventory_providers.dart';

class InventoryOverviewSection extends ConsumerWidget {
  const InventoryOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final alertsAsync = ref.watch(inventoryAlertsProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
      data: (itemsData) {
        return alertsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (alertsData) {
            final items = itemsData.items;
            final summary = itemsData.summary;
            final lowStock = alertsData
                .where((alert) => alert.alertType == 'low_stock')
                .length;
            final expiring = alertsData
                .where((alert) => alert.alertType == 'expiring')
                .length;
            final expired = alertsData
                .where((alert) => alert.alertType == 'expired')
                .length;

            return ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              children: [
                Text(
                  'Inventory Summary',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimensions.spacingLarge),
                // Summary Cards Grid
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppDimensions.spacingMedium,
                  mainAxisSpacing: AppDimensions.spacingMedium,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _SummaryCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Total Items',
                      value: (summary['totalItems'] ?? 0).toString(),
                      color: AppColors.primaryGreen,
                    ),
                    _SummaryCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Low Stock',
                      value: lowStock.toString(),
                      color: AppColors.warmGold,
                    ),
                    _SummaryCard(
                      icon: Icons.access_time_rounded,
                      label: 'Expiring Soon',
                      value: expiring.toString(),
                      color: AppColors.warning,
                    ),
                    _SummaryCard(
                      icon: Icons.attach_money_rounded,
                      label: 'Total Value',
                      value:
                          'KES ${(summary['inventoryValue'] ?? 0).toStringAsFixed(0)}',
                      color: AppColors.navy,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingLarge),
                // Category Distribution
                if (items.isNotEmpty) ...[
                  Text(
                    'Items by Category',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _CategoryDistribution(items: items),
                ],
                const SizedBox(height: AppDimensions.spacingLarge),
                // Recent Alerts
                if (lowStock + expiring + expired > 0) ...[
                  Text(
                    'Alerts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  if (lowStock > 0)
                    _AlertCard(
                      icon: Icons.warning,
                      title: 'Low Stock Items',
                      count: lowStock,
                      color: AppColors.warmGold,
                    ),
                  if (expiring > 0)
                    _AlertCard(
                      icon: Icons.access_time,
                      title: 'Expiring Soon',
                      count: expiring,
                      color: AppColors.warning,
                    ),
                  if (expired > 0)
                    _AlertCard(
                      icon: Icons.error,
                      title: 'Expired Items',
                      count: expired,
                      color: AppColors.danger,
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDistribution extends StatelessWidget {
  final List items;

  const _CategoryDistribution({required this.items});

  @override
  Widget build(BuildContext context) {
    final categories = <String, int>{};
    for (final item in items) {
      final category = item.category as String;
      categories[category] = (categories[category] ?? 0) + 1;
    }

    return Column(
      children: categories.entries.map((entry) {
        final percentage = (entry.value / items.length * 100).toStringAsFixed(
          1,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
          child: Row(
            children: [
              Expanded(child: Text(entry.key)),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.value / items.length,
                    minHeight: 8,
                    backgroundColor: AppColors.outline,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              SizedBox(
                width: 50,
                child: Text(
                  '${entry.value} ($percentage%)',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            count.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
