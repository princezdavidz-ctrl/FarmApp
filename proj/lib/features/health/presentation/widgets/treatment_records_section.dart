import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../providers/health_providers.dart';

class TreatmentRecordsSection extends ConsumerWidget {
  const TreatmentRecordsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(treatmentRecordsProvider)
      .when(
        data: (treatments) {
          if (treatments.isEmpty) {
            return Card(
              color: AppColors.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                child: Text(
                  'No treatment records available',
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
            itemCount: treatments.length,
            itemBuilder: (context, index) =>
                _TreatmentCard(record: treatments[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Card(
          color: AppColors.dangerContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: Text(
              'Failed to load treatments',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      );
}

class _TreatmentCard extends StatelessWidget {
  final dynamic record;

  const _TreatmentCard({required this.record});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pig ${record.pigId}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      record.diagnosis ?? 'Treatment',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(_getStatusLabel(record.status)),
                backgroundColor: _getStatusColor(
                  record.status,
                ).withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _getStatusColor(record.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          if (record.medication != null) ...[
            _InfoRow(label: 'Medication', value: record.medication ?? ''),
            _InfoRow(label: 'Dosage', value: record.dosage ?? ''),
            _InfoRow(
              label: 'Started',
              value: record.visitDate.toString().split(' ')[0],
            ),
            if (record.nextCheckupDate != null)
              _InfoRow(
                label: 'Next Checkup',
                value: record.nextCheckupDate.toString().split(' ')[0],
              ),
            if (record.veterinarian != null)
              _InfoRow(label: 'Veterinarian', value: record.veterinarian ?? ''),
          ],
        ],
      ),
    ),
  );

  String _getStatusLabel(String status) {
    switch (status) {
      case 'healthy':
        return 'Recovered';
      case 'recovering':
        return 'Recovering';
      case 'critical':
        return 'Critical';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'healthy':
        return AppColors.success;
      case 'recovering':
        return AppColors.warning;
      case 'critical':
        return AppColors.danger;
      default:
        return AppColors.mutedText;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
