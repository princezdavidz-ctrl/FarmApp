import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../providers/growth_providers.dart';

class MeasurementHistorySection extends ConsumerWidget {
  const MeasurementHistorySection({super.key});

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
                      Icon(Icons.history, size: 48, color: AppColors.outline),
                      const SizedBox(height: AppDimensions.spacingSmall),
                      Text(
                        'No measurement history',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                final isFirst = index == 0;
                final isLast = index == records.length - 1;

                return _TimelineItem(
                  record: record,
                  isFirst: isFirst,
                  isLast: isLast,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        );
  }
}

class _TimelineItem extends StatelessWidget {
  final dynamic record;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.record,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final measurementDate = (record.measurementDate as DateTime)
        .toLocal()
        .toString()
        .split('.')[0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.scale,
                color: AppColors.inverseText,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 60, color: AppColors.outline),
          ],
        ),
        const SizedBox(width: AppDimensions.spacingMedium),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pig ${record.animalId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (record.photoUrl != null)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: AppColors.surfaceMuted,
                            ),
                            child: const Icon(
                              Icons.image,
                              size: 20,
                              color: AppColors.mutedText,
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
                              'Weight',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedText,
                              ),
                            ),
                            Text(
                              '${(record.currentWeight as double).toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Gain',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.mutedText,
                              ),
                            ),
                            Text(
                              '${(record.dailyGain ?? 0).toStringAsFixed(2)} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (record.notes != null) ...[
                      const SizedBox(height: AppDimensions.spacingSmall),
                      Text(
                        'Notes: ${record.notes}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.text,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.spacingSmall),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          measurementDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedText,
                          ),
                        ),
                        if (record.recordedBy != null)
                          Text(
                            'By: ${record.recordedBy}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedText,
                            ),
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
    );
  }
}
