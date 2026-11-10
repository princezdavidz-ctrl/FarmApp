import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/entities/growth_record.dart';
import '../providers/growth_providers.dart';
import '../widgets/add_weight_dialog.dart';
import '../widgets/growth_overview_card.dart';
import '../widgets/weight_records_section.dart';
import '../widgets/growth_charts_section.dart';
import '../widgets/growth_performance_section.dart';
import '../widgets/measurement_history_section.dart';

class GrowthPage extends ConsumerStatefulWidget {
  const GrowthPage({super.key});

  @override
  ConsumerState<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends ConsumerState<GrowthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Growth Tracking'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.inverseText,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.inverseText,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Records'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildRecordsTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWeightDialog,
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(growthRecordsProvider);
        ref.invalidate(growthOverviewProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        children: [
          _buildOverviewCards(),
          const SizedBox(height: AppDimensions.spacingLarge),
          const Padding(
            padding: EdgeInsets.only(left: AppDimensions.spacingMedium),
            child: Text(
              'Weight Records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          const WeightRecordsSection(),
          const SizedBox(height: AppDimensions.spacingLarge),
          const Padding(
            padding: EdgeInsets.only(left: AppDimensions.spacingMedium),
            child: Text(
              'Growth Performance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          const GrowthPerformanceSection(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return ref
        .watch(growthOverviewProvider)
        .when(
          data: (overview) => GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: AppDimensions.spacingMedium,
            mainAxisSpacing: AppDimensions.spacingMedium,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              GrowthOverviewCard(
                label: 'Average Weight',
                value:
                    '${(overview['average_weight'] ?? 0).toStringAsFixed(1)} kg',
                icon: Icons.balance,
                color: AppColors.info,
              ),
              GrowthOverviewCard(
                label: 'Fastest Growing',
                value: overview['fastest_growing_id'] ?? 'N/A',
                icon: Icons.trending_up,
                color: AppColors.success,
              ),
              GrowthOverviewCard(
                label: 'Weight Gain (Week)',
                value:
                    '${(overview['weekly_gain'] ?? 0).toStringAsFixed(1)} kg',
                icon: Icons.show_chart,
                color: AppColors.warning,
              ),
              GrowthOverviewCard(
                label: 'Growth Target',
                value: '${overview['target_achievement'] ?? 0}%',
                icon: Icons.flag,
                color: AppColors.primaryGreen,
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        );
  }

  Widget _buildRecordsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(growthRecordsProvider);
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: TextField(
              onChanged: (value) {
                ref.read(growthSearchProvider.notifier).state = value;
              },
              decoration: InputDecoration(
                hintText: 'Search by Pig ID',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radius),
                ),
              ),
            ),
          ),
          Expanded(
            child: ref
                .watch(filteredGrowthRecordsProvider)
                .when(
                  data: (records) {
                    if (records.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.scale,
                              size: 64,
                              color: AppColors.outline,
                            ),
                            const SizedBox(height: AppDimensions.spacingMedium),
                            Text(
                              'No weight records',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMedium,
                      ),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return _GrowthRecordCard(record: record);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(growthAnalyticsProvider);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weight Trends',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            const GrowthChartsSection(),
            const SizedBox(height: AppDimensions.spacingLarge),
            const Text(
              'Measurement History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            const MeasurementHistorySection(),
          ],
        ),
      ),
    );
  }

  void _showAddWeightDialog() {
    final dialogContext = context;

    showDialog(
      context: dialogContext,
      builder: (context) => AddWeightDialog(
        onSubmit: (data) async {
          try {
            await ref.read(growthRecordsProvider.notifier).addRecord(data);
            if (!mounted || !dialogContext.mounted) return;

            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
              const SnackBar(
                content: Text('Weight record added successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          } catch (e) {
            if (!mounted || !dialogContext.mounted) return;

            ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        },
      ),
    );
  }
}

class _GrowthRecordCard extends StatelessWidget {
  final GrowthRecord record;

  const _GrowthRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final weightGain = record.weightGain ?? 0;
    final gainColor = weightGain >= 0 ? AppColors.success : AppColors.danger;

    return Card(
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
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(child: Text('Edit')),
                    const PopupMenuItem(child: Text('Delete')),
                  ],
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
                      'Current Weight',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      '${record.currentWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight Gain',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      '${(record.weightGain ?? 0) > 0 ? '+' : ''}${(record.weightGain ?? 0).toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: gainColor,
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
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      '${(record.dailyGain ?? 0).toStringAsFixed(2)} kg/day',
                      style: const TextStyle(
                        fontSize: 14,
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
                record.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.text,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              'Recorded ${record.measurementDate.toLocal().toString().split('.')[0]}',
              style: TextStyle(fontSize: 11, color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}
