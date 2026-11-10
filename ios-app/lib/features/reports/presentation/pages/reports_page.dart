import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/reports/domain/entities/report_metrics.dart';
import 'package:proj/features/reports/presentation/pages/animal_report_page.dart';
import 'package:proj/features/reports/presentation/providers/reports_providers.dart';
import 'package:proj/features/reports/presentation/widgets/herd_reports_browser.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(reportMetricsProvider);
    final dateRange = ref.watch(selectedDateRangeProvider);
    final currency =
        ref.watch(userPreferencesProvider).valueOrNull?.currency ?? 'KES';

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(
          children: [
            _DateRangeFilter(
              selectedRange: dateRange,
              onRangeChanged: (range) {
                ref.read(selectedDateRangeProvider.notifier).state = range;
                ref.invalidate(reportMetricsProvider);
              },
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius,
                        ),
                      ),
                      child: TabBar(
                        tabs: const [
                          Tab(text: 'Finance'),
                          Tab(text: 'Herd'),
                          Tab(text: 'Analytics'),
                        ],
                        labelColor: AppColors.primaryGreen,
                        indicatorColor: AppColors.primaryGreen,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              metrics.when(
                                data: (data) => _ReportsDashboard(
                                  metrics: data,
                                  currency: currency,
                                ),
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (error, _) =>
                                    Center(child: Text('Error: $error')),
                              ),
                              const SizedBox(
                                height: AppDimensions.spacingLarge,
                              ),
                              Text(
                                'Report library',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(
                                height: AppDimensions.spacingMedium,
                              ),
                              const _ReportCategories(),
                            ],
                          ),
                          const SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: HerdReportsBrowser(),
                          ),
                          ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              Text(
                                'Analytics overview',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(
                                height: AppDimensions.spacingMedium,
                              ),
                              _AnalyticsCharts(
                                metrics: metrics,
                                currency: currency,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeFilter extends StatelessWidget {
  const _DateRangeFilter({
    required this.selectedRange,
    required this.onRangeChanged,
  });

  final String selectedRange;
  final Function(String) onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final ranges = ['Today', 'Week', 'Month', 'Year'];
    final rangeValues = ['today', 'week', 'month', 'year'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Range', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...List.generate(ranges.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(ranges[index]),
                    selected: selectedRange == rangeValues[index],
                    onSelected: (_) => onRangeChanged(rangeValues[index]),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportsDashboard extends StatelessWidget {
  const _ReportsDashboard({required this.metrics, required this.currency});

  final ReportMetrics metrics;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.spacingMedium),
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            crossAxisCount: constraints.maxWidth < 360 ? 1 : 2,
            crossAxisSpacing: AppDimensions.spacingMedium,
            mainAxisSpacing: AppDimensions.spacingMedium,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricCard(
                icon: Icons.attach_money,
                label: 'Total revenue',
                value: '$currency ${metrics.totalRevenue.toStringAsFixed(0)}',
                color: AppColors.primaryGreen,
              ),
              _MetricCard(
                icon: Icons.warning,
                label: 'Mortality Rate',
                value: '${metrics.mortalityRate.toStringAsFixed(1)}%',
                color: AppColors.danger,
              ),
              _MetricCard(
                icon: Icons.trending_up,
                label: 'Average Growth',
                value: '${metrics.averageGrowth.toStringAsFixed(1)} kg',
                color: AppColors.primaryGreen,
              ),
              _MetricCard(
                icon: Icons.restaurant,
                label: 'Feed consumed',
                value: metrics.feedConsumption.toStringAsFixed(1),
                color: AppColors.aqua,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AnalyticsCharts extends StatelessWidget {
  const _AnalyticsCharts({required this.metrics, required this.currency});

  final AsyncValue<ReportMetrics> metrics;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return metrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Could not load analytics: $error'),
      data: (data) => LayoutBuilder(
        builder: (context, constraints) => GridView.count(
          crossAxisCount: constraints.maxWidth < 360 ? 1 : 2,
          crossAxisSpacing: AppDimensions.spacingMedium,
          mainAxisSpacing: AppDimensions.spacingMedium,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _AnalyticsMetricCard(
              title: 'Total revenue',
              value: '$currency ${data.totalRevenue.toStringAsFixed(2)}',
              icon: Icons.payments_outlined,
            ),
            _AnalyticsMetricCard(
              title: 'Feed consumed',
              value: data.feedConsumption.toStringAsFixed(1),
              icon: Icons.restaurant_outlined,
            ),
            _AnalyticsMetricCard(
              title: 'Average weight gain',
              value: '${data.averageGrowth.toStringAsFixed(1)} kg',
              icon: Icons.trending_up,
            ),
            _AnalyticsMetricCard(
              title: 'Animals marked sold',
              value: '${data.salesCount}',
              icon: Icons.sell_outlined,
            ),
            _AnalyticsMetricCard(
              title: 'Current mortality rate',
              value: '${data.mortalityRate.toStringAsFixed(1)}%',
              icon: Icons.warning_amber_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMetricCard extends StatelessWidget {
  const _AnalyticsMetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.primaryGreen),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _ReportCategories extends ConsumerWidget {
  const _ReportCategories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = [
      ('Individual Pig Report', Icons.pets, AppColors.primaryGreen),
    ];

    return GridView.count(
      crossAxisCount: reports.length == 1 ? 1 : 2,
      childAspectRatio: reports.length == 1 ? 2.8 : 1,
      crossAxisSpacing: AppDimensions.spacingMedium,
      mainAxisSpacing: AppDimensions.spacingMedium,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: reports
          .map(
            (report) => Card(
              child: InkWell(
                onTap: () {
                  _showReportDetails(context, report.$1, report.$2, report.$3);
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(report.$2, color: report.$3, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        report.$1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _showReportDetails(
    BuildContext context,
    String reportType,
    IconData icon,
    Color color,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AnimalReportPage(reportType: reportType),
      ),
    );
  }
}
