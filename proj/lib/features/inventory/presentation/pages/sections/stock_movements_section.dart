import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/inventory/presentation/providers/inventory_providers.dart';

class StockMovementsSection extends ConsumerStatefulWidget {
  const StockMovementsSection({super.key});

  @override
  ConsumerState<StockMovementsSection> createState() =>
      _StockMovementsSectionState();
}

class _StockMovementsSectionState extends ConsumerState<StockMovementsSection> {
  String _selectedType = '';

  @override
  Widget build(BuildContext context) {
    final movements = ref.watch(stockMovementsProvider);
    final types = ['in', 'out', 'damaged', 'returned', 'transfer'];
    final typeLabels = [
      'Stock In',
      'Stock Out',
      'Damaged',
      'Returned',
      'Transfer',
    ];

    return movements.when(
      data: (movementList) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          // Filter by type
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedType.isEmpty,
                  onSelected: (_) {
                    setState(() => _selectedType = '');
                  },
                ),
                const SizedBox(width: 8),
                ...List.generate(types.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(typeLabels[index]),
                      selected: _selectedType == types[index],
                      onSelected: (_) {
                        setState(() => _selectedType = types[index]);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),

          // Movements list
          if (movementList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                child: Text(
                  'No stock movements yet',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...movementList
                .where(
                  (m) =>
                      _selectedType.isEmpty || m.movementType == _selectedType,
                )
                .map(
                  (movement) => Card(
                    margin: const EdgeInsets.only(
                      bottom: AppDimensions.spacingMedium,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getMovementColor(
                            movement.movementType,
                          ).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getMovementIcon(movement.movementType),
                          color: _getMovementColor(movement.movementType),
                        ),
                      ),
                      title: Text(movement.itemName),
                      subtitle: Text(
                        '${movement.movementLabel} • ${movement.quantity} ${movement.unit}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            movement.createdAt.toString().split(' ')[0],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (movement.reference != null)
                            Text(
                              'Ref: ${movement.reference}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.primaryGreen),
                            ),
                        ],
                      ),
                      onTap: () {
                        _showMovementDetails(context, movement);
                      },
                    ),
                  ),
                ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Color _getMovementColor(String type) {
    switch (type) {
      case 'in':
        return AppColors.success;
      case 'out':
        return AppColors.info;
      case 'damaged':
        return AppColors.danger;
      case 'returned':
        return AppColors.warning;
      case 'transfer':
        return AppColors.violet;
      default:
        return AppColors.mutedText;
    }
  }

  IconData _getMovementIcon(String type) {
    switch (type) {
      case 'in':
        return Icons.arrow_downward;
      case 'out':
        return Icons.arrow_upward;
      case 'damaged':
        return Icons.error_outline;
      case 'returned':
        return Icons.undo;
      case 'transfer':
        return Icons.swap_horiz;
      default:
        return Icons.info;
    }
  }

  void _showMovementDetails(BuildContext context, dynamic movement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(movement.movementLabel),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Item', movement.itemName),
              _DetailRow('Quantity', '${movement.quantity} ${movement.unit}'),
              _DetailRow('Type', movement.movementLabel),
              _DetailRow('Date', movement.createdAt.toString().split(' ')[0]),
              if (movement.reference != null)
                _DetailRow('Reference', movement.reference),
              if (movement.fromLocation != null)
                _DetailRow('From', movement.fromLocation),
              if (movement.toLocation != null)
                _DetailRow('To', movement.toLocation),
              if (movement.notes != null) _DetailRow('Notes', movement.notes),
              _DetailRow('Recorded By', movement.createdBy),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
        ),
        Text(
          value ?? 'N/A',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
