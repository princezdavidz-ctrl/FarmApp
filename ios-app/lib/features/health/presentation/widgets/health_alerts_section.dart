import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../providers/health_providers.dart';

class HealthAlertsSection extends ConsumerWidget {
  const HealthAlertsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(healthAlertsProvider)
      .when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return Card(
              color: AppColors.successContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: AppDimensions.spacingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All pigs are healthy',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.success),
                          ),
                          Text(
                            'No urgent cases at this time',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.text),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            itemBuilder: (context, index) => _AlertCard(alert: alerts[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Card(
          color: AppColors.dangerContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: Text(
              'Failed to load alerts',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      );
}

class _AlertCard extends StatelessWidget {
  final dynamic alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.warningContainer,
    margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Row(
        children: [
          Icon(Icons.warning, color: AppColors.warning, size: 32),
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pig ${alert.pigId}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.warning),
                ),
                Text(
                  alert.diagnosis ?? alert.symptoms.join(', '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Pig ${alert.pigId}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (alert.diagnosis != null)
                        Text('Diagnosis: ${alert.diagnosis}'),
                      if (alert.symptoms.isNotEmpty)
                        Text('Symptoms: ${alert.symptoms.join(', ')}'),
                      if (alert.medication != null)
                        Text('Medication: ${alert.medication}'),
                      if (alert.notes != null) Text('Notes: ${alert.notes}'),
                      Text('Status: ${alert.status}'),
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
            ),
            child: const Text('View'),
          ),
        ],
      ),
    ),
  );
}
