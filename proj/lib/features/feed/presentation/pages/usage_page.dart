import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/feed_api.dart';
import '../providers/feed_provider.dart';

class UsagePage extends ConsumerWidget {
  const UsagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feed usage')),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _UsageError(
          message: '$error',
          onRetry: () => ref.invalidate(feedProvider),
        ),
        data: (snapshot) {
          final records = [...snapshot.usage]
            ..sort((a, b) => b.usedAt.compareTo(a.usedAt));
          final now = DateTime.now();
          final today = records.where((record) => _isSameDay(record.usedAt, now));
          final thisMonth = records.where(
            (record) =>
                record.usedAt.year == now.year &&
                record.usedAt.month == now.month,
          );

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(feedProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Consumption history',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review feed recorded for your farm, with the latest entries first.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 18),
                _UsageSummary(
                  todayCount: today.length,
                  monthCount: thisMonth.length,
                  totalCount: records.length,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All usage records',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${records.length} records',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const _EmptyUsageState()
                else
                  ...records.map((record) => _UsageRecordCard(record: record)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UsageSummary extends StatelessWidget {
  const _UsageSummary({
    required this.todayCount,
    required this.monthCount,
    required this.totalCount,
  });

  final int todayCount;
  final int monthCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _UsageMetric(
              label: 'Today',
              value: todayCount,
              icon: Icons.today_outlined,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _UsageMetric(
              label: 'This month',
              value: monthCount,
              icon: Icons.calendar_month_outlined,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _UsageMetric(
              label: 'All records',
              value: totalCount,
              icon: Icons.receipt_long_outlined,
              color: AppColors.warmGold,
            ),
          ),
        ],
      ),
    ),
  );
}

class _UsageMetric extends StatelessWidget {
  const _UsageMetric({
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
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 19),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.mutedText,
        ),
      ),
    ],
  );
}

class _UsageRecordCard extends StatelessWidget {
  const _UsageRecordCard({required this.record});

  final FeedUsage record;

  @override
  Widget build(BuildContext context) {
    final localDate = record.usedAt.toLocal();
    final time = TimeOfDay.fromDateTime(localDate).format(context);
    final date =
        '${_monthName(localDate.month)} ${localDate.day}, ${localDate.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.aqua.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant_outlined,
                color: AppColors.aqua,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.feedName?.trim().isNotEmpty == true
                        ? record.feedName!
                        : 'Feed consumption',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.notes?.trim().isNotEmpty == true
                        ? record.notes!
                        : 'No additional notes',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: AppColors.mutedText,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '$date · $time',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _quantity(record.quantity),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  record.unit,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedText,
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

class _EmptyUsageState extends StatelessWidget {
  const _EmptyUsageState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: 12),
          Text(
            'No feed usage recorded yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'When you record feed consumption, each entry will appear here with its quantity, unit and date.',
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

class _UsageError extends StatelessWidget {
  const _UsageError({required this.message, required this.onRetry});

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
          Text(
            'Feed usage could not be loaded',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
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

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _quantity(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];
