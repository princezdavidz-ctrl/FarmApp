import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/entities/health_record.dart';
import '../providers/health_providers.dart';

class HealthAnalyticsSection extends ConsumerWidget {
  const HealthAnalyticsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(healthRecordsProvider)
      .when(
        data: (records) => RefreshIndicator(
          onRefresh: () => ref.refresh(healthRecordsProvider.future),
          child: _buildAnalytics(context, records),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load health analytics: $error')),
      );

  Widget _buildAnalytics(BuildContext context, List<HealthRecord> records) {
    final totalPigs = records
        .map((record) => record.pigId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final healthy = _distinctPigs(
      records.where((record) => record.status == 'healthy'),
    );
    final sick = _distinctPigs(
      records.where(
        (record) =>
            record.status == 'recovering' || record.status == 'critical',
      ),
    );
    final underTreatment = _distinctPigs(
      records.where(
        (record) => record.type == 'treatment' && record.status == 'recovering',
      ),
    );
    final dueVaccinations = records
        .where(
          (record) => record.type == 'vaccination' && record.status == 'due',
        )
        .length;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recent = records
        .where((record) => !record.visitDate.isBefore(thirtyDaysAgo))
        .toList();
    final diseaseCounts = <String, int>{};
    for (final record in recent.where(
      (record) => record.diagnosis != null || record.symptoms.isNotEmpty,
    )) {
      final diagnosis = record.diagnosis?.trim();
      final label = diagnosis?.isNotEmpty == true
          ? diagnosis!
          : record.symptoms.first;
      diseaseCounts.update(label, (count) => count + 1, ifAbsent: () => 1);
    }
    final statusCounts = <String, int>{
      'Healthy': records.where((record) => record.status == 'healthy').length,
      'Recovering': records
          .where((record) => record.status == 'recovering')
          .length,
      'Critical': records.where((record) => record.status == 'critical').length,
      'Deceased': records.where((record) => record.status == 'deceased').length,
    };
    final completedVaccinations = records
        .where(
          (record) => record.type == 'vaccination' && record.status != 'due',
        )
        .length;
    final recentDeaths = recent
        .where((record) => record.type == 'mortality')
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.pagePadding,
        AppDimensions.pagePadding,
        100,
      ),
      children: [
        Text('Health Overview', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.spacingMedium),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppDimensions.spacingMedium,
          mainAxisSpacing: AppDimensions.spacingMedium,
          children: [
            _AnalyticsCard(
              label: 'Healthy pigs recorded',
              value: healthy.toString(),
              color: AppColors.success,
              icon: Icons.favorite,
            ),
            _AnalyticsCard(
              label: 'Sick pigs recorded',
              value: sick.toString(),
              color: AppColors.warning,
              icon: Icons.local_hospital,
            ),
            _AnalyticsCard(
              label: 'Vaccinations due',
              value: dueVaccinations.toString(),
              color: AppColors.info,
              icon: Icons.vaccines,
            ),
            _AnalyticsCard(
              label: 'Under treatment',
              value: underTreatment.toString(),
              color: AppColors.violet,
              icon: Icons.medical_services_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSmall),
        Text(
          'Based on ${records.length} health records across $totalPigs pigs.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        Text(
          'Disease Incidence',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _RecordDistributionChart(
          title: 'Diagnoses and symptoms · last 30 days',
          values: diseaseCounts,
          emptyMessage:
              'No diagnoses or symptoms recorded in the last 30 days.',
          color: AppColors.warning,
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        Text('Vaccinations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.spacingMedium),
        _RecordDistributionChart(
          title: 'Vaccination records',
          values: {
            'Completed/recorded': completedVaccinations,
            'Due': dueVaccinations,
          },
          emptyMessage: 'No vaccination records yet.',
          color: AppColors.info,
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        Text('Mortality', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.spacingMedium),
        _AnalyticsCard(
          label: 'Mortality records · last 30 days',
          value: recentDeaths.toString(),
          color: AppColors.danger,
          icon: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        Text(
          'Health Status Records',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _RecordDistributionChart(
          title: 'Recorded status counts',
          values: statusCounts,
          emptyMessage: 'No health records yet.',
          color: AppColors.primaryGreen,
        ),
      ],
    );
  }

  int _distinctPigs(Iterable<HealthRecord> records) => records
      .map((record) => record.pigId)
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _RecordDistributionChart extends StatelessWidget {
  const _RecordDistributionChart({
    required this.title,
    required this.values,
    required this.emptyMessage,
    required this.color,
  });

  final String title;
  final Map<String, int> values;
  final String emptyMessage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.isEmpty ? 1 : entries.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppDimensions.spacingMedium),
            if (entries.isEmpty)
              Text(emptyMessage, style: Theme.of(context).textTheme.bodySmall)
            else
              for (final entry in entries) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: entry.value / maxValue,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSmall),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${entry.value}',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSmall),
              ],
          ],
        ),
      ),
    );
  }
}
