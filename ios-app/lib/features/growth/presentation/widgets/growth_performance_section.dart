import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/entities/growth_record.dart';
import '../providers/growth_providers.dart';

class GrowthPerformanceSection extends ConsumerWidget {
  const GrowthPerformanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(growthRecordsProvider)
        .when(
          data: (records) {
            if (records.isEmpty) {
              return const SizedBox.shrink();
            }

            // Get the most recent records grouped by animal
            final Map<String, GrowthRecord> latestByAnimal = {};
            for (final record in records) {
              if (!latestByAnimal.containsKey(record.animalId) ||
                  record.measurementDate.isAfter(
                    latestByAnimal[record.animalId]!.measurementDate,
                  )) {
                latestByAnimal[record.animalId] = record;
              }
            }

            final performanceList = latestByAnimal.values
                .where((r) => r.dailyGain != null && r.targetWeight != null)
                .toList();

            if (performanceList.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                  child: Text(
                    'Insufficient data for performance analysis',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: performanceList.length.clamp(0, 5),
              itemBuilder: (context, index) {
                final record = performanceList[index];
                return _PerformanceCard(record: record);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        );
  }
}

class _PerformanceCard extends StatelessWidget {
  final GrowthRecord record;

  const _PerformanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final dailyGain = record.dailyGain ?? 0;
    final targetWeight = record.targetWeight ?? 0;
    final currentWeight = record.currentWeight;
    final progress = targetWeight > 0
        ? (currentWeight / targetWeight * 100)
        : 0;

    // Determine status color
    Color statusColor;
    String statusLabel;
    if (dailyGain >= 0.3) {
      statusColor = AppColors.success;
      statusLabel = 'On Target';
    } else if (dailyGain >= 0.2) {
      statusColor = AppColors.warning;
      statusLabel = 'Slow Growth';
    } else {
      statusColor = AppColors.danger;
      statusLabel = 'Needs Attention';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSmall),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pig ${record.animalId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Gain',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      '${dailyGain.toStringAsFixed(2)} kg/day',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Weight',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      '${currentWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target Weight',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      '${targetWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress to Target',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      '${progress.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (progress / 100).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppColors.outline,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 100 ? AppColors.success : AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
