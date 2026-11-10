import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/breeding/domain/entities/pregnancy.dart';
import 'package:proj/features/breeding/presentation/providers/pregnancy_provider.dart';
import 'package:proj/features/feed/data/feed_api.dart';
import 'package:proj/features/feed/presentation/providers/feed_provider.dart';
import 'package:proj/features/health/domain/entities/health_record.dart';
import 'package:proj/features/health/presentation/providers/health_providers.dart';
import 'package:proj/features/herd/domain/entities/animal.dart';
import 'package:proj/features/herd/presentation/providers/herd_provider.dart';
import 'package:proj/features/reports/data/report_export_service.dart';
import 'package:proj/features/settings/presentation/providers/farm_access_provider.dart';
import 'package:proj/security/authorization/permissions.dart';
import 'package:proj/security/authorization/roles.dart';

enum _ReportCategory { pregnant, health, feed }

class _ReportEntry {
  const _ReportEntry({
    required this.title,
    required this.subtitle,
    required this.data,
    required this.category,
  });

  final String title;
  final String subtitle;
  final Map<String, dynamic> data;
  final _ReportCategory category;

  String get searchText => '$title $subtitle $data'.toLowerCase();
}

class HerdReportsBrowser extends ConsumerStatefulWidget {
  const HerdReportsBrowser({super.key});

  @override
  ConsumerState<HerdReportsBrowser> createState() => _HerdReportsBrowserState();
}

class _HerdReportsBrowserState extends ConsumerState<HerdReportsBrowser> {
  final _searchController = TextEditingController();
  _ReportCategory? _category;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).valueOrNull;
    final permissions = session == null
        ? const <AppPermission>{}
        : ref
                  .watch(farmAccessProvider)
                  .valueOrNull
                  ?.permissionsFor(session.user.id) ??
              RolePermissions.all[session.user.role] ??
              const <AppPermission>{};
    final canViewHerd =
        session?.user.role == UserRole.farmOwner ||
        session?.user.role == UserRole.superAdmin ||
        permissions.contains(AppPermission.manageHerd);
    if (session?.selectedFarm == null) {
      return const Center(child: Text('Select a farm to view herd reports.'));
    }
    if (!canViewHerd) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You do not have permission to view herd reports.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final animals = ref.watch(herdProvider).valueOrNull ?? const <Animal>[];
    final pregnancyState = ref.watch(pregnancyProvider);
    final healthState = ref.watch(healthRecordsProvider);
    final feedState = ref.watch(feedProvider);
    final pregnant = (pregnancyState.valueOrNull ?? const <Pregnancy>[]).map((
      item,
    ) {
      final sow = _findAnimal(animals, item.sowId, item.sowTag);
      final tag = item.sowTag ?? sow?.tag ?? 'Pig ${item.sowId}';
      return _ReportEntry(
        title: tag,
        subtitle: '${item.status} · due ${_date(item.expectedFarrowingDate)}',
        category: _ReportCategory.pregnant,
        data: {
          'pig': tag,
          'boar': item.boarTag ?? item.boarId ?? '',
          'status': item.status,
          'mating_date': _date(item.matingDate),
          'confirmation_date': item.confirmationDate == null
              ? ''
              : _date(item.confirmationDate!),
          'expected_farrowing_date': _date(item.expectedFarrowingDate),
          'actual_farrowing_date': item.actualFarrowingDate == null
              ? ''
              : _date(item.actualFarrowingDate!),
          'expected_litter_size': item.expectedLitterSize ?? '',
          'born_alive': item.bornAlive ?? '',
          'stillborn': item.stillborn ?? '',
          'mummified': item.mummified ?? '',
          'weaned': item.weaned ?? '',
          'notes': item.notes ?? '',
        },
      );
    }).toList();
    final health = (healthState.valueOrNull ?? const <HealthRecord>[]).map((
      item,
    ) {
      final animal = _findAnimal(animals, item.pigId, item.pigId);
      return _ReportEntry(
        title: animal?.tag ?? item.pigId,
        subtitle: '${item.type} · ${item.status} · ${_date(item.visitDate)}',
        category: _ReportCategory.health,
        data: {
          'pig': animal?.tag ?? item.pigId,
          'type': item.type,
          'status': item.status,
          'visit_date': _date(item.visitDate),
          'diagnosis': item.diagnosis ?? '',
          'medication': item.medication ?? '',
          'veterinarian': item.veterinarian ?? '',
          'notes': item.notes ?? '',
        },
      );
    }).toList();
    final feed = <_ReportEntry>[
      for (final item in feedState.valueOrNull?.stock ?? const <FeedStock>[])
        _ReportEntry(
          title: item.name,
          subtitle: 'Stock · ${item.quantity} ${item.unit}',
          category: _ReportCategory.feed,
          data: {
            'feed': item.name,
            'record_type': 'stock',
            'quantity': item.quantity,
            'unit': item.unit,
            'unit_cost': item.unitCost ?? '',
            'location': item.location ?? '',
          },
        ),
      for (final item in feedState.valueOrNull?.usage ?? const <FeedUsage>[])
        _ReportEntry(
          title: item.feedName ?? 'Feed usage',
          subtitle:
              'Used ${item.quantity} ${item.unit} · ${_date(item.usedAt)}',
          category: _ReportCategory.feed,
          data: {
            'feed': item.feedName ?? 'Feed usage',
            'record_type': 'usage',
            'quantity': item.quantity,
            'unit': item.unit,
            'used_at': _date(item.usedAt),
            'notes': item.notes ?? '',
          },
        ),
    ];

    final selectedEntries = switch (_category) {
      _ReportCategory.pregnant => pregnant,
      _ReportCategory.health => health,
      _ReportCategory.feed => feed,
      null => const <_ReportEntry>[],
    };
    final visibleEntries = selectedEntries
        .where((entry) => entry.searchText.contains(_query))
        .toList();
    final allEntries = [
      ...pregnant,
      ...health,
      ...feed,
    ].where((entry) => entry.searchText.contains(_query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: _category == null
                ? 'Search herd reports'
                : 'Search ${_label(_category!).toLowerCase()} reports',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        if (_category == null && _query.isEmpty) ...[
          Text('Herd reports', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimensions.spacingMedium),
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              crossAxisCount: constraints.maxWidth > 620 ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisExtent: 170,
              crossAxisSpacing: AppDimensions.spacingMedium,
              mainAxisSpacing: AppDimensions.spacingMedium,
              children: [
                _CategoryCard(
                  title: 'Pregnancy',
                  subtitle: 'Pregnancy and farrowing',
                  count: pregnant.length,
                  icon: Icons.favorite_outline,
                  color: AppColors.pigPink,
                  loading: pregnancyState.isLoading,
                  onTap: () =>
                      setState(() => _category = _ReportCategory.pregnant),
                ),
                _CategoryCard(
                  title: 'Health',
                  subtitle: 'Treatments and vaccinations',
                  count: health.length,
                  icon: Icons.health_and_safety_outlined,
                  color: AppColors.info,
                  loading: healthState.isLoading,
                  onTap: () =>
                      setState(() => _category = _ReportCategory.health),
                ),
                _CategoryCard(
                  title: 'Feed',
                  subtitle: 'Feed stock and usage',
                  count: feed.length,
                  icon: Icons.grass_outlined,
                  color: AppColors.leaf,
                  loading: feedState.isLoading,
                  onTap: () => setState(() => _category = _ReportCategory.feed),
                ),
              ],
            ),
          ),
          if (pregnancyState.hasError ||
              healthState.hasError ||
              feedState.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingMedium),
              child: Text(
                'Some report categories could not load. Refresh and try again.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ] else if (_category == null) ...[
          Text(
            'Matching herd reports',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          if (pregnancyState.isLoading ||
              healthState.isLoading ||
              feedState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (allEntries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.spacingLarge),
                child: Text('No herd reports match your search.'),
              ),
            )
          else
            _recordGrid(context, allEntries),
        ] else ...[
          Row(
            children: [
              IconButton(
                tooltip: 'Back to herd reports',
                onPressed: () => setState(() => _category = null),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '${_label(_category!)} reports',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (visibleEntries.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Export ${_label(_category!)} report',
                  onSelected: (format) => _exportEntries(
                    context,
                    visibleEntries,
                    _category!,
                    format,
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                    PopupMenuItem(value: 'xlsx', child: Text('Export Excel')),
                  ],
                  icon: const Icon(Icons.download_outlined),
                ),
              Text('${visibleEntries.length}'),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          if (_categoryLoading(
            _category!,
            pregnancyState,
            healthState,
            feedState,
          ))
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_categoryError(
            _category!,
            pregnancyState,
            healthState,
            feedState,
          ))
            Card(
              child: ListTile(
                title: Text('Could not load ${_label(_category!)} reports.'),
                trailing: IconButton(
                  tooltip: 'Retry',
                  onPressed: () => _retry(ref),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (visibleEntries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                child: Text(
                  _query.isEmpty
                      ? 'No ${_label(_category!).toLowerCase()} records found.'
                      : 'No reports match “${_searchController.text}”.',
                ),
              ),
            )
          else
            _recordGrid(context, visibleEntries),
        ],
      ],
    );
  }

  Widget _recordGrid(BuildContext context, List<_ReportEntry> entries) =>
      LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 700
                ? 3
                : constraints.maxWidth >= 480
                ? 2
                : 1,
            mainAxisExtent: 165,
            crossAxisSpacing: AppDimensions.spacingMedium,
            mainAxisSpacing: AppDimensions.spacingMedium,
          ),
          itemBuilder: (context, index) => _RecordCard(
            category: _label(entries[index].category),
            entry: entries[index],
            onExport: (format) => _export(
              context,
              entries[index],
              entries[index].category,
              format,
            ),
          ),
        ),
      );

  Future<void> _export(
    BuildContext context,
    _ReportEntry entry,
    _ReportCategory category,
    String format,
  ) async {
    try {
      final path = await ReportExportService().exportReport(
        reportName: '${_label(category)}_${entry.title}',
        format: format,
        data: {
          'report_category': _label(category),
          ...entry.data,
          'records': [entry.data],
        },
      );
      if (!context.mounted) return;
      await _shareReport(
        context,
        path,
        '${entry.title} ${_label(category)} report',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report downloaded: $path')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report export failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _exportEntries(
    BuildContext context,
    List<_ReportEntry> entries,
    _ReportCategory category,
    String format,
  ) async {
    try {
      final path = await ReportExportService().exportReport(
        reportName: '${_label(category)}_Report',
        format: format,
        data: {
          'report_category': _label(category),
          'record_count': entries.length,
          'records': entries.map((entry) => entry.data).toList(),
        },
      );
      if (!context.mounted) return;
      await _shareReport(context, path, '${_label(category)} reports');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report downloaded: $path')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report export failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _shareReport(
    BuildContext context,
    String path,
    String subject,
  ) async {
    final renderObject = context.findRenderObject();
    final box = renderObject is RenderBox ? renderObject : null;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: subject,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _retry(WidgetRef ref) {
    switch (_category!) {
      case _ReportCategory.pregnant:
        ref.invalidate(pregnancyProvider);
      case _ReportCategory.health:
        ref.invalidate(healthRecordsProvider);
      case _ReportCategory.feed:
        ref.invalidate(feedProvider);
    }
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(loading ? 'Loading…' : '$count reports'),
          ],
        ),
      ),
    ),
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.category,
    required this.entry,
    required this.onExport,
  });

  final String category;
  final _ReportEntry entry;
  final ValueChanged<String> onExport;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Download $category report',
                onSelected: onExport,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'pdf', child: Text('Download PDF')),
                  PopupMenuItem(value: 'xlsx', child: Text('Download Excel')),
                  PopupMenuItem(value: 'doc', child: Text('Download Word')),
                ],
                icon: const Icon(Icons.download_outlined),
              ),
            ],
          ),
          const Spacer(),
          Text(entry.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            'Download PDF, Excel or Word',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

Animal? _findAnimal(List<Animal> animals, String id, String? tag) {
  for (final animal in animals) {
    if (animal.id == id || (tag != null && animal.tag == tag)) return animal;
  }
  return null;
}

String _label(_ReportCategory category) => switch (category) {
  _ReportCategory.pregnant => 'Pregnancy',
  _ReportCategory.health => 'Health',
  _ReportCategory.feed => 'Feed',
};

bool _categoryLoading(
  _ReportCategory category,
  AsyncValue<List<Pregnancy>> pregnancies,
  AsyncValue<List<HealthRecord>> health,
  AsyncValue<FeedSnapshot> feed,
) => switch (category) {
  _ReportCategory.pregnant => pregnancies.isLoading,
  _ReportCategory.health => health.isLoading,
  _ReportCategory.feed => feed.isLoading,
};

bool _categoryError(
  _ReportCategory category,
  AsyncValue<List<Pregnancy>> pregnancies,
  AsyncValue<List<HealthRecord>> health,
  AsyncValue<FeedSnapshot> feed,
) => switch (category) {
  _ReportCategory.pregnant => pregnancies.hasError,
  _ReportCategory.health => health.hasError,
  _ReportCategory.feed => feed.hasError,
};

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
