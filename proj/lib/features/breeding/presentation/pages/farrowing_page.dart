import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/pregnancy.dart';
import '../providers/pregnancy_provider.dart';

class FarrowingPage extends ConsumerWidget {
  const FarrowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pregnancies = ref.watch(pregnancyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Farrowing')),
      body: pregnancies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FarrowingError(
          message: '$error',
          onRetry: () => ref.invalidate(pregnancyProvider),
        ),
        data: (items) {
          final pending = items
              .where(
                (item) => item.status != 'farrowed' && item.status != 'aborted',
              )
              .toList()
            ..sort(
              (a, b) => a.expectedFarrowingDate.compareTo(
                b.expectedFarrowingDate,
              ),
            );
          final dueSoon = pending.where((item) => item.isDueSoon).length;
          final overdue = pending.where((item) => item.isOverdue).length;

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(pregnancyProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Farrowing management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prepare for each litter and record outcomes when piglets arrive.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 18),
                _FarrowingSummary(
                  pending: pending.length,
                  dueSoon: dueSoon,
                  overdue: overdue,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Upcoming farrowings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${pending.length} pending',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  const _EmptyFarrowingState()
                else
                  ...pending.map(
                    (item) => _FarrowingCard(pregnancy: item),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}


class _FarrowingSummary extends StatelessWidget {
  const _FarrowingSummary({
    required this.pending,
    required this.dueSoon,
    required this.overdue,
  });

  final int pending;
  final int dueSoon;
  final int overdue;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _FarrowingMetric(
              label: 'Pending',
              value: pending,
              color: AppColors.primaryGreen,
              icon: Icons.pets_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FarrowingMetric(
              label: 'Due soon',
              value: dueSoon,
              color: AppColors.warmGold,
              icon: Icons.event_available_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FarrowingMetric(
              label: 'Overdue',
              value: overdue,
              color: AppColors.danger,
              icon: Icons.warning_amber_rounded,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FarrowingMetric extends StatelessWidget {
  const _FarrowingMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 8),
      Text(
        '$value',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _EmptyFarrowingState extends StatelessWidget {
  const _EmptyFarrowingState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 42,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: 12),
          Text(
            'No upcoming farrowings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Active pregnancy records will appear here, ordered by their expected farrowing date.',
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

class _FarrowingError extends StatelessWidget {
  const _FarrowingError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _FarrowingCard extends StatelessWidget {
  const _FarrowingCard({required this.pregnancy});

  final Pregnancy pregnancy;

  @override
  Widget build(BuildContext context) {
    final days = pregnancy.daysUntilFarrowing;
    final dueText = days == null
        ? 'Date pending'
        : days < 0
        ? '${days.abs()} days overdue'
        : days == 0
        ? 'Due today'
        : '$days days remaining';
    final statusColor = pregnancy.isOverdue
        ? AppColors.danger
        : pregnancy.isDueSoon
        ? AppColors.warmGold
        : AppColors.primaryGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pregnancy.sowTag ?? 'Sow ${pregnancy.sowId}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expected ${_formatDate(pregnancy.expectedFarrowingDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    _statusLabel(pregnancy.status),
                    style: TextStyle(color: statusColor),
                  ),
                  backgroundColor: statusColor.withValues(alpha: .12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 18, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    dueText,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showOutcomeSheet(context, pregnancy),
                icon: const Icon(Icons.pets_outlined),
                label: const Text('Record outcome'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOutcomeSheet(
    BuildContext context,
    Pregnancy pregnancy,
  ) async {
    final ref = ProviderScope.containerOf(context, listen: false);
    var actualDate = DateTime.now();
    final bornAliveController = TextEditingController(text: '0');
    final stillbornController = TextEditingController(text: '0');
    final mummifiedController = TextEditingController(text: '0');
    final weanedController = TextEditingController(text: '0');
    final notesController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farrowing outcome',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Actual farrowing date'),
                  subtitle: Text(_formatDate(actualDate)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: pregnancy.matingDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: actualDate,
                    );
                    if (picked != null) {
                      setState(() => actualDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bornAliveController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Born alive'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stillbornController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stillborn'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mummifiedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mummified'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: weanedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weaned'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Save record'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      bornAliveController.dispose();
      stillbornController.dispose();
      mummifiedController.dispose();
      weanedController.dispose();
      notesController.dispose();
      return;
    }

    final bornAlive = int.tryParse(bornAliveController.text) ?? 0;
    await ref
        .read(pregnancyProvider.notifier)
        .recordFarrowingOutcome(
          pregnancyId: pregnancy.id,
          actualFarrowingDate: actualDate,
          bornAlive: bornAlive,
          stillborn: int.tryParse(stillbornController.text),
          mummified: int.tryParse(mummifiedController.text),
          weaned: int.tryParse(weanedController.text),
          notes: notesController.text,
        );

    bornAliveController.dispose();
    stillbornController.dispose();
    mummifiedController.dispose();
    weanedController.dispose();
    notesController.dispose();
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _statusLabel(String value) => value.replaceAll('_', ' ');
