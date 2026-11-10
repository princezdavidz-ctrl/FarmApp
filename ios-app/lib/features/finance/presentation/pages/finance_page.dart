import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../breeding/domain/entities/pregnancy.dart';
import '../../../breeding/presentation/providers/pregnancy_provider.dart';
import '../../../feed/data/feed_api.dart';
import '../../../feed/presentation/providers/feed_provider.dart';
import '../../../health/domain/entities/health_record.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../herd/domain/entities/animal.dart';
import '../../../herd/presentation/providers/herd_provider.dart';
import '../../../reports/data/report_export_service.dart';
import '../../../reports/domain/entities/animal_report.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../data/farm_finance_api.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/farm_access_provider.dart';
import '../../../../security/authorization/permissions.dart';
import '../../../../security/authorization/roles.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../providers/farm_finance_provider.dart';

class FinancePage extends ConsumerWidget {
  const FinancePage({super.key, this.typeFilter});

  final String? typeFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final access = ref.watch(farmAccessProvider).valueOrNull;
    final role = session?.user.role;
    final permissions = session == null
        ? const <AppPermission>{}
        : access?.permissionsFor(session.user.id) ?? const <AppPermission>{};
    final hasFarm = session?.selectedFarm != null;
    final canView =
        role == UserRole.farmOwner ||
        role == UserRole.accountant ||
        permissions.contains(AppPermission.manageFinance);
    final canManage =
        hasFarm &&
        (role == UserRole.farmOwner ||
            role == UserRole.accountant ||
            permissions.contains(AppPermission.manageFinance));
    final finance = canView && hasFarm
        ? ref.watch(farmFinanceProvider)
        : const AsyncData<FarmFinanceState>(FarmFinanceState());
    final title = switch (typeFilter) {
      'income' => 'Income',
      'expense' => 'Expenses',
      _ => 'Finance',
    };

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            tooltip: 'Open menu',
            icon: const Icon(Icons.menu),
            onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Finance'),
              Tab(text: 'Herd'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () => ref.refresh(farmFinanceProvider.future),
              child: !canView || !hasFarm
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 140),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              !hasFarm
                                  ? 'Select a farm to view its finances.'
                                  : 'You do not have permission to view this farm’s finances.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    )
                  : finance.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(
                          AppDimensions.pagePadding,
                        ),
                        children: [
                          const SizedBox(height: 100),
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load farm finances.\n$error',
                            textAlign: TextAlign.center,
                          ),
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  ref.invalidate(farmFinanceProvider),
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      ),
                      data: (state) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(
                          AppDimensions.pagePadding,
                        ),
                        children: [
                          Card(
                            color: AppColors.deepGreen,
                            child: Padding(
                              padding: const EdgeInsets.all(
                                AppDimensions.spacingLarge,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session?.selectedFarm?.name ??
                                        'Farm finances',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppColors.inverseText,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Recorded income and expenses for this calendar month.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.inverseMutedText,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingLarge),
                          Text(
                            'This month',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppDimensions.spacingSmall),
                          if (state.totals.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(18),
                                child: Text(
                                  'No transactions recorded this month yet.',
                                ),
                              ),
                            )
                          else
                            ...state.totals.map(
                              (totals) => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        totals.currency,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 10),
                                      _SummaryLine(
                                        label: 'Income',
                                        value: _money(
                                          totals.currency,
                                          totals.income,
                                        ),
                                        color: AppColors.success,
                                      ),
                                      _SummaryLine(
                                        label: 'Expenses',
                                        value: _money(
                                          totals.currency,
                                          totals.expenses,
                                        ),
                                        color: AppColors.warning,
                                      ),
                                      const Divider(),
                                      _SummaryLine(
                                        label: 'Net',
                                        value: _money(
                                          totals.currency,
                                          totals.profit,
                                        ),
                                        color: AppColors.primaryGreen,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (canManage) ...[
                            const SizedBox(height: AppDimensions.spacingMedium),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _showTransactionDialog(
                                      context,
                                      ref,
                                      type: 'income',
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Record income'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showTransactionDialog(
                                      context,
                                      ref,
                                      type: 'expense',
                                    ),
                                    icon: const Icon(Icons.remove),
                                    label: const Text('Record expense'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppDimensions.spacingLarge),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  typeFilter == 'income'
                                      ? 'Income history'
                                      : typeFilter == 'expense'
                                      ? 'Expense history'
                                      : 'Transaction history',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Download finance report',
                                onSelected: (format) => _exportFinanceReport(
                                  context,
                                  state,
                                  format,
                                ),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'pdf',
                                    child: Text('PDF'),
                                  ),
                                  PopupMenuItem(
                                    value: 'xlsx',
                                    child: Text('Excel'),
                                  ),
                                  PopupMenuItem(
                                    value: 'doc',
                                    child: Text('Word'),
                                  ),
                                ],
                                icon: const Icon(Icons.download_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacingSmall),
                          ...state.transactions
                              .where(
                                (transaction) =>
                                    typeFilter == null ||
                                    transaction.type == typeFilter,
                              )
                              .map(
                                (transaction) => Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          (transaction.type == 'income'
                                                  ? AppColors.success
                                                  : AppColors.warning)
                                              .withValues(alpha: 0.14),
                                      child: Icon(
                                        transaction.type == 'income'
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        color: transaction.type == 'income'
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                    title: Text(transaction.description),
                                    subtitle: Text(
                                      '${transaction.category} · ${_date(transaction.occurredAt)}',
                                    ),
                                    trailing: Text(
                                      '${transaction.type == 'income' ? '+' : '−'}${_money(transaction.currency, transaction.amount)}',
                                      style: TextStyle(
                                        color: transaction.type == 'income'
                                            ? AppColors.success
                                            : AppColors.warning,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          if (state.transactions
                              .where(
                                (transaction) =>
                                    typeFilter == null ||
                                    transaction.type == typeFilter,
                              )
                              .isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(18),
                                child: Text('No transactions recorded yet.'),
                              ),
                            ),
                          if (state.transactions.length >= 100)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Showing the 100 most recent transactions.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const _HerdReportsTab(),
            const _FinanceAnalyticsTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _exportFinanceReport(
    BuildContext context,
    FarmFinanceState state,
    String format,
  ) async {
    try {
      final filePath = await ReportExportService().exportReport(
        reportName: 'Farm_Finance_Report',
        format: format,
        data: {
          'report': 'Finance',
          'period': DateTime.now().toIso8601String().substring(0, 7),
          'totals': [
            for (final total in state.totals)
              {
                'currency': total.currency,
                'income': total.income,
                'expenses': total.expenses,
                'net': total.profit,
              },
          ],
          'records': [
            for (final transaction in state.transactions.where(
              (transaction) =>
                  typeFilter == null || transaction.type == typeFilter,
            ))
              {
                'date': _date(transaction.occurredAt),
                'type': transaction.type,
                'category': transaction.category,
                'description': transaction.description,
                'amount': transaction.amount,
                'currency': transaction.currency,
              },
          ],
        },
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Finance report exported: $filePath')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finance report export failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showTransactionDialog(
    BuildContext context,
    WidgetRef ref, {
    required String type,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _TransactionDialog(
        type: type,
        onSave:
            ({
              required category,
              required description,
              required amount,
              required currency,
              required occurredAt,
            }) => ref
                .read(farmFinanceProvider.notifier)
                .record(
                  type: type,
                  category: category,
                  description: description,
                  amount: amount,
                  currency: currency,
                  occurredAt: occurredAt,
                ),
      ),
    );
  }

  static String _money(String currency, double amount) =>
      '$currency ${amount.toStringAsFixed(2)}';

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

enum _HerdReportCategory { pregnant, health, feed }

class _HerdReportEntry {
  const _HerdReportEntry({
    required this.title,
    required this.subtitle,
    required this.data,
    this.animalId,
  });

  final String title;
  final String subtitle;
  final Map<String, dynamic> data;
  final String? animalId;

  String get searchText => '$title $subtitle $data'.toLowerCase();
}

class _HerdReportsTab extends ConsumerStatefulWidget {
  const _HerdReportsTab();

  @override
  ConsumerState<_HerdReportsTab> createState() => _HerdReportsTabState();
}

class _HerdReportsTabState extends ConsumerState<_HerdReportsTab> {
  final _searchController = TextEditingController();
  _HerdReportCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).valueOrNull;
    final farmId = session?.selectedFarm?.id;
    final role = session?.user.role;
    final access = ref.watch(farmAccessProvider).valueOrNull;
    final permissions = session == null
        ? const <AppPermission>{}
        : access?.permissionsFor(session.user.id) ?? const <AppPermission>{};
    final canViewHerd =
        role == UserRole.farmOwner ||
        role == UserRole.superAdmin ||
        permissions.contains(AppPermission.manageHerd);
    final herd = canViewHerd
        ? ref.watch(herdProvider)
        : const AsyncValue<List<Animal>>.data([]);
    final pregnancies = canViewHerd
        ? ref.watch(pregnancyProvider)
        : const AsyncValue<List<Pregnancy>>.data([]);
    final healthRecords = canViewHerd
        ? ref.watch(healthRecordsProvider)
        : const AsyncValue<List<HealthRecord>>.data([]);
    final feed = canViewHerd
        ? ref.watch(feedProvider)
        : const AsyncValue<FeedSnapshot>.data(
            FeedSnapshot(stock: [], usage: []),
          );

    if (farmId == null) {
      return const Center(child: Text('Select a farm to view herd reports.'));
    }
    if (!canViewHerd) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You do not have permission to view herd, health, or feed reports.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final animals = herd.valueOrNull ?? const <Animal>[];
    final pregnantItems = (pregnancies.valueOrNull ?? const <Pregnancy>[])
        .where(
          (pregnancy) =>
              !{'farrowed', 'aborted'}.contains(pregnancy.status.toLowerCase()),
        )
        .map((pregnancy) {
          final sow = _animalFor(animals, pregnancy.sowId, pregnancy.sowTag);
          final title =
              pregnancy.sowTag ?? sow?.tag ?? 'Pig ${pregnancy.sowId}';
          return _HerdReportEntry(
            title: title,
            subtitle:
                '${pregnancy.status} · due ${_formatDate(pregnancy.expectedFarrowingDate)}',
            animalId: sow?.id,
            data: _pregnancyData(pregnancy, title),
          );
        })
        .toList();
    final healthItems = (healthRecords.valueOrNull ?? const <HealthRecord>[]).map((
      record,
    ) {
      final animal = _animalFor(animals, record.pigId, record.pigId);
      return _HerdReportEntry(
        title: animal?.tag ?? record.pigId,
        subtitle:
            '${record.type} · ${record.status} · ${_formatDate(record.visitDate)}',
        animalId: animal?.id,
        data: {
          'pig': animal?.tag ?? record.pigId,
          'type': record.type,
          'status': record.status,
          'visit_date': _formatDate(record.visitDate),
          'diagnosis': record.diagnosis ?? '',
          'medication': record.medication ?? '',
          'veterinarian': record.veterinarian ?? '',
          'notes': record.notes ?? '',
        },
      );
    }).toList();
    final feedItems = <_HerdReportEntry>[
      for (final stock in feed.valueOrNull?.stock ?? const <FeedStock>[])
        _HerdReportEntry(
          title: stock.name,
          subtitle: 'Stock · ${stock.quantity} ${stock.unit}',
          data: {
            'feed': stock.name,
            'record_type': 'stock',
            'quantity': stock.quantity,
            'unit': stock.unit,
            'unit_cost': stock.unitCost ?? '',
            'location': stock.location ?? '',
          },
        ),
      for (final usage in feed.valueOrNull?.usage ?? const <FeedUsage>[])
        _HerdReportEntry(
          title: usage.feedName ?? 'Feed usage',
          subtitle:
              'Used ${usage.quantity} ${usage.unit} · ${_formatDate(usage.usedAt)}',
          data: {
            'feed': usage.feedName ?? 'Feed usage',
            'record_type': 'usage',
            'quantity': usage.quantity,
            'unit': usage.unit,
            'used_at': _formatDate(usage.usedAt),
            'notes': usage.notes ?? '',
          },
        ),
    ];
    final entries = switch (_selectedCategory) {
      _HerdReportCategory.pregnant => pregnantItems,
      _HerdReportCategory.health => healthItems,
      _HerdReportCategory.feed => feedItems,
      null => const <_HerdReportEntry>[],
    };
    final filteredEntries = entries
        .where((entry) => entry.searchText.contains(_searchQuery))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: _selectedCategory == null
                ? 'Search herd reports'
                : 'Search ${_categoryLabel(_selectedCategory!).toLowerCase()} reports',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
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
        if (_selectedCategory == null) ...[
          Text(
            'Herd report categories',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 3 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppDimensions.spacingMedium,
                mainAxisSpacing: AppDimensions.spacingMedium,
                mainAxisExtent: 176,
                children: [
                  _HerdCategoryCard(
                    title: 'Pregnant',
                    subtitle: 'Pregnancy and farrowing records',
                    count: pregnantItems.length,
                    icon: Icons.favorite_outline,
                    color: AppColors.pigPink,
                    isLoading: pregnancies.isLoading,
                    onTap: () => setState(
                      () => _selectedCategory = _HerdReportCategory.pregnant,
                    ),
                  ),
                  _HerdCategoryCard(
                    title: 'Health',
                    subtitle: 'Treatments, checks, and vaccinations',
                    count: healthItems.length,
                    icon: Icons.health_and_safety_outlined,
                    color: AppColors.info,
                    isLoading: healthRecords.isLoading,
                    onTap: () => setState(
                      () => _selectedCategory = _HerdReportCategory.health,
                    ),
                  ),
                  _HerdCategoryCard(
                    title: 'Feed',
                    subtitle: 'Feed stock and usage records',
                    count: feedItems.length,
                    icon: Icons.grass_outlined,
                    color: AppColors.leaf,
                    isLoading: feed.isLoading,
                    onTap: () => setState(
                      () => _selectedCategory = _HerdReportCategory.feed,
                    ),
                  ),
                ],
              );
            },
          ),
          if (pregnancies.hasError || healthRecords.hasError || feed.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spacingMedium),
              child: Text(
                'Some report categories could not load. Open a category to retry or refresh the page.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ] else ...[
          Row(
            children: [
              IconButton(
                tooltip: 'Report categories',
                onPressed: () => setState(() => _selectedCategory = null),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '${_categoryLabel(_selectedCategory!)} reports',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('${filteredEntries.length}'),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          if (_categoryLoading(
            _selectedCategory!,
            pregnancies,
            healthRecords,
            feed,
          ))
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_categoryError(
            _selectedCategory!,
            pregnancies,
            healthRecords,
            feed,
          ))
            _ReportErrorCard(
              category: _categoryLabel(_selectedCategory!),
              onRetry: () => _retryCategory(_selectedCategory!, ref),
            )
          else if (filteredEntries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                child: Text(
                  _searchQuery.isEmpty
                      ? 'No ${_categoryLabel(_selectedCategory!).toLowerCase()} records found.'
                      : 'No reports match “${_searchController.text}”.',
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 740
                    ? 3
                    : constraints.maxWidth >= 480
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredEntries.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 174,
                    crossAxisSpacing: AppDimensions.spacingMedium,
                    mainAxisSpacing: AppDimensions.spacingMedium,
                  ),
                  itemBuilder: (context, index) => _HerdReportCard(
                    entry: filteredEntries[index],
                    category: _categoryLabel(_selectedCategory!),
                    onExport: (format) => _exportHerdReport(
                      context,
                      ref,
                      farmId,
                      filteredEntries[index],
                      _selectedCategory!,
                      format,
                    ),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  Future<void> _exportHerdReport(
    BuildContext context,
    WidgetRef ref,
    String farmId,
    _HerdReportEntry entry,
    _HerdReportCategory category,
    String format,
  ) async {
    try {
      var data = <String, dynamic>{
        'report_category': _categoryLabel(category),
        ...entry.data,
        'records': [entry.data],
      };
      final session = ref.read(authProvider).valueOrNull;
      final permissions = session == null
          ? const <AppPermission>{}
          : ref
                    .read(farmAccessProvider)
                    .valueOrNull
                    ?.permissionsFor(session.user.id) ??
                const <AppPermission>{};
      final canViewFullReport =
          session?.user.role == UserRole.farmOwner ||
          session?.user.role == UserRole.superAdmin ||
          permissions.contains(AppPermission.viewReports);
      if (entry.animalId != null && canViewFullReport) {
        final dateRange = ref.read(selectedDateRangeProvider);
        final report = await ref
            .read(reportsApiProvider)
            .getAnimalReport(farmId, entry.animalId!, dateRange: dateRange);
        data = {
          ...report.toExportJson(),
          'report_category': _categoryLabel(category),
          ...entry.data,
          'records': _reportRows(report, category, entry.data),
        };
      }
      final path = await ReportExportService().exportReport(
        reportName: '${_categoryLabel(category)}_${entry.title}',
        format: format,
        data: data,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report exported: $path')));
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

  void _retryCategory(_HerdReportCategory category, WidgetRef ref) {
    switch (category) {
      case _HerdReportCategory.pregnant:
        ref.invalidate(pregnancyProvider);
      case _HerdReportCategory.health:
        ref.invalidate(healthRecordsProvider);
      case _HerdReportCategory.feed:
        ref.invalidate(feedProvider);
    }
  }
}

class _HerdCategoryCard extends StatelessWidget {
  const _HerdCategoryCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final bool isLoading;
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
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 5),
            Text(isLoading ? 'Loading…' : '$count reports'),
          ],
        ),
      ),
    ),
  );
}

class _HerdReportCard extends StatelessWidget {
  const _HerdReportCard({
    required this.entry,
    required this.category,
    required this.onExport,
  });

  final _HerdReportEntry entry;
  final String category;
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
          Text(
            entry.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap download to choose PDF, Excel, or Word.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _ReportErrorCard extends StatelessWidget {
  const _ReportErrorCard({required this.category, required this.onRetry});

  final String category;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text('Could not load $category reports.'),
      trailing: IconButton(
        tooltip: 'Retry',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
      ),
    ),
  );
}

class _FinanceAnalyticsTab extends ConsumerWidget {
  const _FinanceAnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final access = ref.watch(farmAccessProvider).valueOrNull;
    final role = session?.user.role;
    final permissions = session == null
        ? const <AppPermission>{}
        : access?.permissionsFor(session.user.id) ?? const <AppPermission>{};
    final canView =
        role == UserRole.farmOwner ||
        role == UserRole.superAdmin ||
        permissions.contains(AppPermission.viewReports);
    if (!canView) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You do not have permission to view farm analytics.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final metrics = ref.watch(reportMetricsProvider);
    return metrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load analytics: $error'),
            TextButton(
              onPressed: () => ref.invalidate(reportMetricsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Text(
            'Analytics overview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppDimensions.spacingMedium,
            mainAxisSpacing: AppDimensions.spacingMedium,
            childAspectRatio: 1.35,
            children: [
              _AnalyticsMetricCard(
                title: 'Revenue',
                value: data.totalRevenue.toStringAsFixed(2),
                icon: Icons.trending_up,
                color: AppColors.success,
              ),
              _AnalyticsMetricCard(
                title: 'Expenses',
                value: data.totalExpenses.toStringAsFixed(2),
                icon: Icons.trending_down,
                color: AppColors.warning,
              ),
              _AnalyticsMetricCard(
                title: 'Net profit',
                value: data.netProfit.toStringAsFixed(2),
                icon: Icons.account_balance,
                color: AppColors.primaryGreen,
              ),
              _AnalyticsMetricCard(
                title: 'Mortality',
                value: '${data.mortalityRate.toStringAsFixed(1)}%',
                icon: Icons.health_and_safety_outlined,
                color: AppColors.danger,
              ),
              _AnalyticsMetricCard(
                title: 'Average growth',
                value: '${data.averageGrowth.toStringAsFixed(1)} kg',
                icon: Icons.monitor_weight_outlined,
                color: AppColors.info,
              ),
              _AnalyticsMetricCard(
                title: 'Feed consumed',
                value: '${data.feedConsumption.toStringAsFixed(1)} kg',
                icon: Icons.grass_outlined,
                color: AppColors.leaf,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsMetricCard extends StatelessWidget {
  const _AnalyticsMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

Animal? _animalFor(List<Animal> animals, String id, String? tag) {
  for (final animal in animals) {
    if (animal.id == id || animal.tag == tag) return animal;
  }
  return null;
}

Map<String, dynamic> _pregnancyData(Pregnancy pregnancy, String sowTag) => {
  'pig': sowTag,
  'status': pregnancy.status,
  'mating_date': _formatDate(pregnancy.matingDate),
  'expected_farrowing_date': _formatDate(pregnancy.expectedFarrowingDate),
  'actual_farrowing_date': pregnancy.actualFarrowingDate == null
      ? ''
      : _formatDate(pregnancy.actualFarrowingDate!),
  'expected_litter_size': pregnancy.expectedLitterSize ?? '',
  'born_alive': pregnancy.bornAlive ?? '',
  'stillborn': pregnancy.stillborn ?? '',
  'notes': pregnancy.notes ?? '',
};

List<Map<String, dynamic>> _reportRows(
  AnimalReport report,
  _HerdReportCategory category,
  Map<String, dynamic> selectedRecord,
) {
  switch (category) {
    case _HerdReportCategory.pregnant:
      return report.pregnancies.isEmpty
          ? [selectedRecord]
          : [
              for (final pregnancy in report.pregnancies)
                _pregnancyData(pregnancy, report.animal.tag),
            ];
    case _HerdReportCategory.health:
      return report.healthRecords.isEmpty
          ? [selectedRecord]
          : [
              for (final record in report.healthRecords)
                {
                  'pig': report.animal.tag,
                  'type': record.type,
                  'status': record.status,
                  'visit_date': _formatDate(record.visitDate),
                  'diagnosis': record.diagnosis ?? '',
                  'medication': record.medication ?? '',
                  'veterinarian': record.veterinarian ?? '',
                  'notes': record.notes ?? '',
                },
            ];
    case _HerdReportCategory.feed:
      return [selectedRecord];
  }
}

bool _categoryLoading(
  _HerdReportCategory category,
  AsyncValue<List<Pregnancy>> pregnancies,
  AsyncValue<List<HealthRecord>> health,
  AsyncValue<FeedSnapshot> feed,
) => switch (category) {
  _HerdReportCategory.pregnant => pregnancies.isLoading,
  _HerdReportCategory.health => health.isLoading,
  _HerdReportCategory.feed => feed.isLoading,
};

bool _categoryError(
  _HerdReportCategory category,
  AsyncValue<List<Pregnancy>> pregnancies,
  AsyncValue<List<HealthRecord>> health,
  AsyncValue<FeedSnapshot> feed,
) => switch (category) {
  _HerdReportCategory.pregnant => pregnancies.hasError,
  _HerdReportCategory.health => health.hasError,
  _HerdReportCategory.feed => feed.hasError,
};

String _categoryLabel(_HerdReportCategory category) => switch (category) {
  _HerdReportCategory.pregnant => 'Pregnant',
  _HerdReportCategory.health => 'Health',
  _HerdReportCategory.feed => 'Feed',
};

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _TransactionDialog extends StatefulWidget {
  const _TransactionDialog({required this.type, required this.onSave});

  final String type;
  final Future<void> Function({
    required String category,
    required String description,
    required double amount,
    required String currency,
    required DateTime occurredAt,
  })
  onSave;

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController(text: 'KES');
  late DateTime _occurredAt;
  bool _saving = false;

  List<String> get _categories => widget.type == 'income'
      ? const ['Livestock sales', 'Animal products', 'Other income']
      : const [
          'Feed',
          'Veterinary',
          'Labor',
          'Transport',
          'Equipment',
          'Other',
        ];

  @override
  void initState() {
    super.initState();
    _occurredAt = DateTime.now();
    _categoryController.text = _categories.first;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.type == 'income' ? 'Record income' : 'Record expense'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _categoryController.text,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) _categoryController.text = value;
              },
            ),
            TextFormField(
              controller: _descriptionController,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                return amount == null || amount <= 0 ? 'Enter an amount' : null;
              },
            ),
            TextFormField(
              controller: _currencyController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              decoration: const InputDecoration(
                labelText: 'Currency code',
                hintText: 'KES',
              ),
              validator: (value) =>
                  RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a 3-letter code',
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transaction date'),
              subtitle: Text(FinancePage._date(_occurredAt)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _occurredAt,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null && mounted) {
                  setState(() => _occurredAt = date);
                }
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        category: _categoryController.text,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        currency: _currencyController.text.trim().toUpperCase(),
        occurredAt: _occurredAt,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save transaction: $error')),
      );
    }
  }
}
