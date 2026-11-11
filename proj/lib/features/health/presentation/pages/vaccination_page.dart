import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/health_record.dart';
import '../providers/health_providers.dart';
import '../widgets/add_health_record_page.dart';

class VaccinationPage extends ConsumerWidget {
  const VaccinationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vaccination')),
        body: const Center(child: Text('Select a farm to manage vaccinations.')),
      );
    }

    final records = ref.watch(healthRecordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccination management'),
        actions: [
          IconButton(
            tooltip: 'Refresh vaccinations',
            onPressed: () => ref.invalidate(healthRecordsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddRecord(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record vaccination'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(healthRecordsProvider.future),
        child: records.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              const Center(child: Text('Vaccination records could not be loaded.')),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(healthRecordsProvider),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
          data: (allRecords) {
            final vaccinations = allRecords
                .where((record) => record.type == 'vaccination')
                .toList()
              ..sort((a, b) {
                final aDate = a.nextCheckupDate ?? a.visitDate;
                final bDate = b.nextCheckupDate ?? b.visitDate;
                return aDate.compareTo(bDate);
              });
            final now = DateUtils.dateOnly(DateTime.now());
            final upcoming = vaccinations.where((record) {
              final due = record.nextCheckupDate;
              return due != null && !DateUtils.dateOnly(due).isBefore(now);
            }).length;
            final overdue = vaccinations.where((record) {
              final due = record.nextCheckupDate;
              return due != null && DateUtils.dateOnly(due).isBefore(now);
            }).length;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
              children: [
                _VaccinationOverview(
                  total: vaccinations.length,
                  upcoming: upcoming,
                  overdue: overdue,
                ),
                const SizedBox(height: 22),
                Text(
                  'Vaccination history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Review recorded vaccines, visit dates and next check-ups.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 14),
                if (vaccinations.isEmpty)
                  const _EmptyVaccinationState()
                else
                  for (final record in vaccinations)
                    _VaccinationRecordCard(record: record),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddRecord(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddHealthRecordPage(
          initialType: 'vaccination',
          onSubmit: (data) async {
            await ref.read(healthRecordsProvider.notifier).addRecord(data);
          },
        ),
      ),
    );
    ref.invalidate(healthRecordsProvider);
    ref.invalidate(vaccinationScheduleProvider);
    ref.invalidate(healthOverviewProvider);
  }
}

class _VaccinationOverview extends StatelessWidget {
  const _VaccinationOverview({
    required this.total,
    required this.upcoming,
    required this.overdue,
  });

  final int total;
  final int upcoming;
  final int overdue;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _VaccinationMetric(
              label: 'Recorded',
              value: total,
              icon: Icons.vaccines_outlined,
              color: AppColors.primaryGreen,
            ),
          ),
          Expanded(
            child: _VaccinationMetric(
              label: 'Upcoming',
              value: upcoming,
              icon: Icons.event_available_outlined,
              color: AppColors.info,
            ),
          ),
          Expanded(
            child: _VaccinationMetric(
              label: 'Overdue',
              value: overdue,
              icon: Icons.warning_amber_rounded,
              color: overdue > 0 ? AppColors.danger : AppColors.mutedText,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VaccinationMetric extends StatelessWidget {
  const _VaccinationMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 21),
      const SizedBox(height: 7),
      Text(
        '$value',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.mutedText,
        ),
      ),
    ],
  );
}

class _VaccinationRecordCard extends StatelessWidget {
  const _VaccinationRecordCard({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final dueDate = record.nextCheckupDate;
    final now = DateUtils.dateOnly(DateTime.now());
    final isOverdue = dueDate != null && DateUtils.dateOnly(dueDate).isBefore(now);
    final statusColor = isOverdue ? AppColors.danger : AppColors.info;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.vaccines_outlined, color: AppColors.info),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.medication?.trim().isNotEmpty == true
                            ? record.medication!
                            : record.diagnosis?.trim().isNotEmpty == true
                                ? record.diagnosis!
                                : 'Vaccination',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Pig ${record.pigId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dueDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOverdue ? 'Overdue' : 'Upcoming',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _VaccinationDetail(
              icon: Icons.calendar_today_outlined,
              label: 'Recorded',
              value: _formatDate(record.visitDate),
            ),
            const SizedBox(height: 8),
            _VaccinationDetail(
              icon: Icons.event_outlined,
              label: 'Next check-up',
              value: dueDate == null ? 'Not scheduled' : _formatDate(dueDate),
            ),
            if (record.dosage?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _VaccinationDetail(
                icon: Icons.medication_outlined,
                label: 'Dosage',
                value: record.dosage!,
              ),
            ],
            if (record.veterinarian?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _VaccinationDetail(
                icon: Icons.medical_services_outlined,
                label: 'Veterinarian',
                value: record.veterinarian!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VaccinationDetail extends StatelessWidget {
  const _VaccinationDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.mutedText),
      const SizedBox(width: 8),
      Text(
        '$label: ',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.mutedText,
        ),
      ),
      Expanded(
        child: Text(value, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

class _EmptyVaccinationState extends StatelessWidget {
  const _EmptyVaccinationState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.vaccines_outlined, size: 44, color: AppColors.primaryGreen),
          const SizedBox(height: 12),
          Text(
            'No vaccination records yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Record a vaccine for an animal to build your farm’s vaccination history and track its next check-up.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
