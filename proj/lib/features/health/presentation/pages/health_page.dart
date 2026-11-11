import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../security/authorization/roles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/health_record.dart';
import '../providers/health_providers.dart';
import '../widgets/health_overview_card.dart';
import '../widgets/health_alerts_section.dart';
import '../widgets/vaccination_schedule_section.dart';
import '../widgets/treatment_records_section.dart';
import '../widgets/veterinary_visits_section.dart';
import '../widgets/health_analytics_section.dart';
import '../widgets/add_health_record_page.dart';
import '../widgets/veterinary_requests_tab.dart';
import '../../../../shared/widgets/farm_app_mark.dart';

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({this.initialTypeFilter = 'all', super.key});

  final String initialTypeFilter;

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _typeFilter;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialTypeFilter;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTypeFilter == 'all' ? 0 : 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(healthTypeFilterProvider.notifier).state =
            widget.initialTypeFilter;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).valueOrNull?.user.role;
    final farmName = ref.watch(authProvider).valueOrNull?.selectedFarm?.name ?? 'Your farm';
    final canManageRecords = const {
      UserRole.farmOwner,
      UserRole.farmManager,
    }.contains(role);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const FarmAppMark(size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(switch (widget.initialTypeFilter) {
          'medication' => 'Medication Records',
          'deworming' => 'Deworming Records',
          'mortality' => 'Mortality Records',
          _ => 'Health Management',
        }))],
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.health_and_safety_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.folder_open_outlined), text: 'Records'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
              Tab(icon: Icon(Icons.medical_services_outlined), text: 'Veterinarian'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          _buildOverviewTab(context, ref),
          // Records Tab
          _buildRecordsTab(context, ref, canManageRecords),
          // Analytics Tab
          _buildAnalyticsTab(context, ref),
          VeterinaryRequestsTab(
            dio: ref.watch(dioProvider),
            farmId: ref.watch(authProvider).valueOrNull?.selectedFarm?.id,
            county: ref.watch(authProvider).valueOrNull?.selectedFarm?.location,
            canRequest: canManageRecords,
          ),
        ],
      ),
      floatingActionButton: canManageRecords
          ? FloatingActionButton.extended(
              onPressed: () => _openAddHealthRecordPage(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Record'),
            )
          : null,
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    WidgetRef ref,
  ) => RefreshIndicator(
    onRefresh: () => ref.refresh(healthRecordsProvider.future),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.pagePadding,
        AppDimensions.pagePadding,
        100,
      ),
      children: [
        _HealthHeroCard(farmName: farmName, onViewRecords: () => _tabController.animateTo(1)),
        const SizedBox(height: AppDimensions.spacingLarge),
        // Health Status Overview Cards
        _buildHealthOverview(ref),
        const SizedBox(height: AppDimensions.spacingLarge),

        // Health Alerts Section
        Text('Health Alerts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.spacingMedium),
        const HealthAlertsSection(),
        const SizedBox(height: AppDimensions.spacingLarge),

        // Vaccination Schedule
        Text(
          'Vaccination Schedule',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        const VaccinationScheduleSection(),
        const SizedBox(height: AppDimensions.spacingLarge),

        // Treatment Records
        Text(
          'Treatment Records',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        const TreatmentRecordsSection(),
        const SizedBox(height: AppDimensions.spacingLarge),

        // Veterinary Visits
        Text(
          'Veterinary Visits',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        const VeterinaryVisitsSection(),
      ],
    ),
  );

  Widget _buildRecordsTab(
    BuildContext context,
    WidgetRef ref,
    bool canManageRecords,
  ) => RefreshIndicator(
    onRefresh: () => ref.refresh(healthRecordsProvider.future),
    child: Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search field
              TextField(
                onChanged: (value) {
                  ref.read(healthSearchProvider.notifier).state = value;
                },
                decoration: InputDecoration(
                  hintText: 'Search by pig ID or diagnosis...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radius),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Types',
                      isSelected: _typeFilter == 'all',
                      onSelected: () {
                        setState(() => _typeFilter = 'all');
                        ref.read(healthTypeFilterProvider.notifier).state =
                            'all';
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Vaccination',
                      isSelected: _typeFilter == 'vaccination',
                      onSelected: () {
                        setState(() => _typeFilter = 'vaccination');
                        ref.read(healthTypeFilterProvider.notifier).state =
                            'vaccination';
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Treatment',
                      isSelected: _typeFilter == 'treatment',
                      onSelected: () {
                        setState(() => _typeFilter = 'treatment');
                        ref.read(healthTypeFilterProvider.notifier).state =
                            'treatment';
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Deworming',
                      isSelected: _typeFilter == 'deworming',
                      onSelected: () {
                        setState(() => _typeFilter = 'deworming');
                        ref.read(healthTypeFilterProvider.notifier).state =
                            'deworming';
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Medication',
                      isSelected: _typeFilter == 'medication',
                      onSelected: () {
                        setState(() => _typeFilter = 'medication');
                        ref.read(healthTypeFilterProvider.notifier).state =
                            'medication';
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Mortality',
                      isSelected: _typeFilter == 'mortality',
                      onSelected: () {
                        setState(() => _typeFilter = 'mortality');
                        ref.read(healthTypeFilterProvider.notifier).state =
                            'mortality';
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Filtered Records List
        Expanded(
          child: ref
              .watch(filteredHealthRecordsProvider)
              .when(
                data: (records) {
                  if (records.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.health_and_safety_outlined,
                            size: 64,
                            color: AppColors.mutedText,
                          ),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          Text(
                            'No health records found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.pagePadding,
                      0,
                      AppDimensions.pagePadding,
                      100,
                    ),
                    itemCount: records.length,
                    itemBuilder: (context, index) => _HealthRecordCard(
                      record: records[index],
                      onEdit: canManageRecords
                          ? () => _openEditHealthRecordPage(
                              context,
                              records[index],
                            )
                          : null,
                      onDelete: canManageRecords
                          ? () => _deleteHealthRecord(context, records[index])
                          : null,
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: AppDimensions.spacingMedium),
                      Text(
                        'Failed to load records',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingSmall),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ],
    ),
  );

  Widget _buildAnalyticsTab(BuildContext context, WidgetRef ref) =>
      const HealthAnalyticsSection();

  Widget _buildHealthOverview(WidgetRef ref) {
    return ref
        .watch(healthOverviewProvider)
        .when(
          data: (stats) => GridView.extent(
            maxCrossAxisExtent: 190,
            mainAxisExtent: 148,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppDimensions.spacingMedium,
            mainAxisSpacing: AppDimensions.spacingMedium,
            // The overview cards contain an icon, value, and label. Giving
            // them a little more height prevents their content from clipping
            // on narrow phone screens.
            children: [
              HealthOverviewCard(
                label: 'Healthy Pigs',
                value: stats['healthy']?.toString() ?? '0',
                icon: Icons.favorite,
                color: AppColors.success,
              ),
              HealthOverviewCard(
                label: 'Sick Pigs',
                value: stats['sick']?.toString() ?? '0',
                icon: Icons.local_hospital,
                color: AppColors.warning,
              ),
              HealthOverviewCard(
                label: 'Vaccinated',
                value: stats['vaccinated']?.toString() ?? '0',
                icon: Icons.vaccines,
                color: AppColors.info,
              ),
              HealthOverviewCard(
                label: 'Vaccinations Due',
                value: stats['vaccinations_due']?.toString() ?? '0',
                icon: Icons.notifications_active,
                color: AppColors.aqua,
              ),
              HealthOverviewCard(
                label: 'Under Treatment',
                value: stats['under_treatment']?.toString() ?? '0',
                icon: Icons.medical_services_outlined,
                color: AppColors.violet,
              ),
            ],
          ),
          loading: () => GridView.extent(
            maxCrossAxisExtent: 190,
            mainAxisExtent: 148,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppDimensions.spacingMedium,
            mainAxisSpacing: AppDimensions.spacingMedium,
            children: List.generate(
              4,
              (index) =>
                  const Card(child: Center(child: CircularProgressIndicator())),
            ),
          ),
          error: (error, stackTrace) => Card(
            color: AppColors.dangerContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMedium),
              child: Text(
                'Failed to load health overview',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ),
        );
  }

  Future<void> _openAddHealthRecordPage(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => AddHealthRecordPage(
            initialType: widget.initialTypeFilter == 'medication'
                ? 'treatment'
                : widget.initialTypeFilter == 'all'
                ? 'treatment'
                : widget.initialTypeFilter,
            onSubmit: (data) =>
                ref.read(healthRecordsProvider.notifier).addRecord(data),
          ),
        ),
      );

  Future<void> _openEditHealthRecordPage(
    BuildContext context,
    HealthRecord record,
  ) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => AddHealthRecordPage(
        initialType: record.type,
        initialRecord: record,
        onSubmit: (data) => ref
            .read(healthRecordsProvider.notifier)
            .updateRecord(record.id, data),
      ),
    ),
  );

  Future<void> _deleteHealthRecord(
    BuildContext context,
    HealthRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete health record?'),
        content: Text('Remove the record for pig ${record.pigId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(healthRecordsProvider.notifier).deleteRecord(record.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the health record.')),
        );
      }
    }
  }
}

class _HealthHeroCard extends StatelessWidget {
  const _HealthHeroCard({required this.farmName, required this.onViewRecords});
  final String farmName;
  final VoidCallback onViewRecords;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppDimensions.spacingLarge),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.deepGreen, AppColors.primaryGreen]),
      borderRadius: BorderRadius.circular(AppDimensions.radius),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.health_and_safety_outlined, color: Colors.white, size: 28), const SizedBox(width: 10), Expanded(child: Text(farmName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))), const Icon(Icons.pets_outlined, color: Colors.white70)]),
      const SizedBox(height: 12),
      Text('Herd health at a glance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Track treatments, vaccinations and follow-up care in one place.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
      const SizedBox(height: 16),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: onViewRecords, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)), icon: const Icon(Icons.folder_open_outlined, size: 18), label: const Text('Review health records'))),
    ]),
  );
}

class _RecordTag extends StatelessWidget {
  const _RecordTag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)));
}

// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: isSelected,
    onSelected: (_) => onSelected(),
    selectedColor: AppColors.primaryGreen,
    labelStyle: TextStyle(
      color: isSelected ? AppColors.inverseText : AppColors.text,
    ),
  );
}

// Health Record Card Widget
class _HealthRecordCard extends StatelessWidget {
  final HealthRecord record;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;

  const _HealthRecordCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
    child: ListTile(
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: _getTypeColor(record.type).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(_getTypeIcon(record.type), color: _getTypeColor(record.type))),
      title: Text(
        'Pig ${record.pigId}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (record.diagnosis != null) Text('Diagnosis: ${record.diagnosis}'),
          Text('Recorded ${record.visitDate.toString().split(' ')[0]}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _RecordTag(label: _recordTypeLabel(record.type), color: _getTypeColor(record.type)),
            _RecordTag(label: _recordStatusLabel(record.status), color: _recordStatusColor(record.status)),
          ]),
        ],
      ),
      isThreeLine: false,
      trailing: onEdit == null && onDelete == null
          ? null
          : PopupMenuButton(
              itemBuilder: (context) => [
                if (onEdit != null)
                  PopupMenuItem(child: const Text('Edit'), onTap: onEdit),
                if (onDelete != null)
                  PopupMenuItem(
                    onTap: () {
                      onDelete?.call();
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
    ),
  );

  String _recordTypeLabel(String type) => switch (type) { 'vaccination' => 'Vaccination', 'treatment' => 'Treatment', 'deworming' => 'Deworming', 'mortality' => 'Mortality', _ => 'Health' };

  String _recordStatusLabel(String status) => status.replaceAll('_', ' ').split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');

  Color _recordStatusColor(String status) => switch (status) { 'healthy' => AppColors.success, 'recovering' => AppColors.warning, 'critical' || 'deceased' => AppColors.danger, 'due' => AppColors.info, _ => AppColors.mutedText };

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'vaccination':
        return Icons.vaccines;
      case 'treatment':
        return Icons.local_hospital;
      case 'deworming':
        return Icons.health_and_safety;
      case 'mortality':
        return Icons.highlight_off;
      default:
        return Icons.info;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'vaccination':
        return AppColors.info;
      case 'treatment':
        return AppColors.warning;
      case 'deworming':
        return AppColors.primaryGreen;
      case 'mortality':
        return AppColors.danger;
      default:
        return AppColors.text;
    }
  }
}
