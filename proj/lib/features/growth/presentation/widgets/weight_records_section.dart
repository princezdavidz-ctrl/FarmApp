import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/entities/growth_record.dart';
import '../providers/growth_providers.dart';

class WeightRecordsSection extends ConsumerWidget {
  const WeightRecordsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(growthRecordsProvider)
        .when(
          data: (records) {
            if (records.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                  child: Column(
                    children: [
                      Icon(Icons.scale, size: 48, color: AppColors.outline),
                      const SizedBox(height: AppDimensions.spacingSmall),
                      Text(
                        'No weight records yet',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Show top 5 most recent records
            final topRecords = records.take(5).toList();
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topRecords.length,
              itemBuilder: (context, index) {
                final record = topRecords[index];
                return _WeightRecordTile(record: record);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        );
  }
}

class _WeightRecordTile extends StatelessWidget {
  final GrowthRecord record;

  const _WeightRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final gainColor = (record.weightGain ?? 0) >= 0
        ? AppColors.success
        : AppColors.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          child: Icon(Icons.scale, color: AppColors.primaryGreen),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pig ${record.animalId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Text(
          '${record.measurementDate.toLocal().toString().split(' ')[0]} • ${record.recordedBy ?? 'Unknown'}',
          style: TextStyle(fontSize: 12, color: AppColors.mutedText),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${record.currentWeight.toStringAsFixed(1)} kg',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              '${(record.weightGain ?? 0) > 0 ? '+' : ''}${(record.weightGain ?? 0).toStringAsFixed(1)} kg',
              style: TextStyle(
                fontSize: 12,
                color: gainColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
