import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/inventory/presentation/providers/inventory_providers.dart';

class AlertsSection extends ConsumerWidget {
  const AlertsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(inventoryAlertsProvider);

    return alerts.when(
      data: (alertList) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          if (alertList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Alerts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All inventory is in good condition',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alertList.length} Active Alert${alertList.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDimensions.spacingLarge),
                ...alertList.map(
                  (alert) => Card(
                    margin: const EdgeInsets.only(
                      bottom: AppDimensions.spacingMedium,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius,
                        ),
                        border: Border(
                          left: BorderSide(
                            color: _getSeverityColor(alert.severity),
                            width: 4,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          AppDimensions.spacingMedium,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getSeverityColor(
                                      alert.severity,
                                    ).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getAlertIcon(alert.alertType),
                                    color: _getSeverityColor(alert.severity),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(
                                  width: AppDimensions.spacingMedium,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert.alertLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: _getSeverityColor(
                                                alert.severity,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        alert.itemName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(alert.severity.toUpperCase()),
                                  backgroundColor: _getSeverityColor(
                                    alert.severity,
                                  ).withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _getSeverityColor(alert.severity),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              alert.message,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Created: ${alert.createdAt.toString().split(' ')[0]}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    ref
                                        .read(inventoryAlertsProvider.notifier)
                                        .resolveAlert(alert.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${alert.alertLabel} marked as resolved',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Resolve'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppColors.danger;
      case 'warning':
        return AppColors.warning;
      case 'info':
        return AppColors.info;
      default:
        return AppColors.mutedText;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'low_stock':
        return Icons.warning;
      case 'expiring':
        return Icons.access_time;
      case 'expired':
        return Icons.error;
      case 'reorder':
        return Icons.shopping_cart;
      default:
        return Icons.info;
    }
  }
}
