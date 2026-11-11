import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/pregnancy.dart';
import '../providers/pregnancy_provider.dart';

class MatingPage extends ConsumerWidget {
  const MatingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(pregnancyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mating records')),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 12),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(pregnancyProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          final sorted = [...items]
            ..sort((a, b) => b.matingDate.compareTo(a.matingDate));

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(pregnancyProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Mating history',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review insemination dates, semen details, and the current status of each record.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 18),
                _MatingCountCard(count: sorted.length),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All records',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${sorted.length} total',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sorted.isEmpty)
                  const _EmptyMatingState()
                else
                  ...sorted.map((record) => _MatingRecordCard(record: record)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MatingCountCard extends StatelessWidget {
  const _MatingCountCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.pigPink.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.favorite_outline,
              color: AppColors.pigPink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Recorded inseminations',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MatingRecordCard extends StatelessWidget {
  const _MatingRecordCard({required this.record});

  final Pregnancy record;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      'confirmed' => AppColors.success,
      'high_risk' => AppColors.danger,
      'farrowed' => AppColors.info,
      'aborted' => AppColors.mutedText,
      _ => AppColors.warmGold,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.pigPink.withValues(alpha: .12),
                  child: const Icon(
                    Icons.pets_outlined,
                    color: AppColors.pigPink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.sowTag ?? 'Sow ${record.sowId}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Pig ID ${record.sowId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.status.replaceAll('_', ' '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MatingDetail(
              label: 'Insemination date',
              value: _formatDate(record.matingDate),
              icon: Icons.calendar_month_outlined,
            ),
            const SizedBox(height: 10),
            _MatingDetail(
              label: 'Semen used',
              value: record.semenUsed?.trim().isNotEmpty == true
                  ? record.semenUsed!
                  : 'Not recorded',
              icon: Icons.science_outlined,
            ),
            const SizedBox(height: 10),
            _MatingDetail(
              label: 'Expected farrowing',
              value: _formatDate(record.expectedFarrowingDate),
              icon: Icons.event_available_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatingDetail extends StatelessWidget {
  const _MatingDetail({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.mutedText),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ],
  );
}

class _EmptyMatingState extends StatelessWidget {
  const _EmptyMatingState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.favorite_border,
            size: 42,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: 12),
          Text(
            'No mating records yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Insemination records created in pregnancy tracking will appear here.',
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

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
