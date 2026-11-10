import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../providers/health_providers.dart';

class VeterinaryVisitsSection extends ConsumerWidget {
  const VeterinaryVisitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(healthRecordsProvider)
      .when(
        data: (records) {
          final visits = records.where((r) => r.veterinarian != null).toList();

          if (visits.isEmpty) {
            return Card(
              color: AppColors.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                child: Text(
                  'No veterinary visits recorded',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.text),
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visits.length,
            itemBuilder: (context, index) =>
                _VetVisitCard(record: visits[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Card(
          color: AppColors.dangerContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: Text(
              'Failed to load veterinary visits',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      );
}

class _VetVisitCard extends StatelessWidget {
  final dynamic record;

  const _VetVisitCard({required this.record});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
    child: ExpansionTile(
      leading: const Icon(
        Icons.medical_services,
        color: AppColors.primaryGreen,
      ),
      title: Text(
        'Dr. ${(record.veterinarian as String?) ?? 'Unknown'}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      subtitle: Text(
        (record.visitDate as DateTime).toString().split(' ')[0],
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingLarge * 2,
            0,
            AppDimensions.spacingLarge,
            AppDimensions.spacingLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Pig ID', value: record.pigId),
              if (record.diagnosis != null)
                _DetailRow(label: 'Diagnosis', value: record.diagnosis ?? ''),
              if (record.medication != null) ...[
                _DetailRow(label: 'Medication', value: record.medication ?? ''),
                _DetailRow(label: 'Dosage', value: record.dosage ?? ''),
              ],
              if (record.notes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.notes ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (record.attachmentUrls.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingMedium),
                Text(
                  'Attachments',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: record.attachmentUrls.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radius,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
