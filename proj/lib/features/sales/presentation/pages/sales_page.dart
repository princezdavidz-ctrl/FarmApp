import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../features/auth/domain/entities/session.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/reports/presentation/providers/reports_providers.dart';
import '../../../../features/settings/presentation/providers/farm_access_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../security/authorization/permissions.dart';
import '../../../../security/authorization/roles.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../data/farm_buyer.dart';
import '../../data/farm_sale.dart';
import 'post_pig_herd_tab.dart';
import 'pig_marketplace_tabs.dart';
import 'farm_transport_requests_tab.dart';
import '../providers/farm_sales_provider.dart';
import '../providers/pig_marketplace_provider.dart';

class SalesPage extends ConsumerWidget {
  const SalesPage({super.key});

  bool _canManageSales(Session? session, FarmAccessState? access) {
    if (session?.user.role == UserRole.farmOwner) return true;
    if (session == null || access == null) return false;
    return access
        .permissionsFor(session.user.id)
        .contains(AppPermission.manageSales);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authProvider).valueOrNull;
    final access = ref.watch(farmAccessProvider).valueOrNull;
    final canManage = _canManageSales(session, access);
    final salesState = ref.watch(farmSalesProvider);
    final metrics = ref.watch(reportMetricsProvider);
    final range = ref.watch(selectedDateRangeProvider);
    final hasFarm = session?.selectedFarm != null;
    final farm = session?.selectedFarm;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.sales),
          leading: IconButton(
            tooltip: l10n.openMenu,
            icon: const Icon(Icons.menu),
            onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            IconButton(
              tooltip: l10n.buyerSearch,
              onPressed: () => context.go(AppRoutes.buyers),
              icon: const Icon(Icons.people_outline),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TabBar(
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.mutedText,
                labelStyle: TextStyle(fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'For buyers'),
                  Tab(text: 'Post pig'),
                  Tab(text: 'My sales'),
                  Tab(text: 'Transport'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            const ForBuyersTab(),
            PostPigHerdTab(canManage: canManage),
            Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: canManage && hasFarm
                  ? FloatingActionButton.extended(
                      onPressed: () => _showSaleDialog(
                        context,
                        ref,
                        salesState.valueOrNull?.buyers ?? const [],
                      ),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: Text(l10n.addFarmSale),
                    )
                  : null,
              body: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    ref.refresh(farmSalesProvider.future),
                    ref.refresh(reportMetricsProvider.future),
                    ref.refresh(pigMarketplaceProvider.future),
                  ]);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
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
                              l10n.farmSales,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: AppColors.inverseText),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.salesIntro,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.inverseMutedText),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              session?.selectedFarm?.name ?? l10n.selectFarm,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.inverseMutedText),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    if (!hasFarm)
                      _MessageCard(
                        icon: Icons.agriculture_outlined,
                        message: l10n.selectFarm,
                      )
                    else ...[
                      metrics.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (data) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.pets_outlined),
                            ),
                            title: Text(l10n.salesAnimalsMarkedSold),
                            subtitle: Text(
                              '${_periodLabel(range)} · ${data.salesCount}',
                            ),
                            trailing: Text(
                              '${data.salesCount}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.farmSales,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => context.go(AppRoutes.buyers),
                            icon: const Icon(Icons.people_outline),
                            label: Text(l10n.buyers),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingSmall),
                      salesState.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => _MessageCard(
                          icon: Icons.error_outline,
                          message: '${l10n.salesLoadError}\n$error',
                          action: TextButton(
                            onPressed: () => ref.invalidate(farmSalesProvider),
                            child: Text(l10n.retry),
                          ),
                        ),
                        data: (data) => data.sales.isEmpty
                            ? _MessageCard(
                                icon: Icons.receipt_long_outlined,
                                message: l10n.noSalesYet,
                                action: TextButton(
                                  onPressed: () => context.go(AppRoutes.buyers),
                                  child: Text(l10n.addBuyer),
                                ),
                              )
                            : Column(
                                children: [
                                  for (final sale in data.sales)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppDimensions.spacingMedium,
                                      ),
                                      child: _SaleCard(
                                        sale: sale,
                                        canManage: canManage,
                                        onStatusChanged: (status) =>
                                            _updateStatus(
                                              context,
                                              ref,
                                              sale.id,
                                              status,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                    if (hasFarm)
                      MyMarketplaceSalesSection(canManage: canManage),
                  ],
                ),
              ),
            ),
            FarmTransportRequestsTab(
              dio: ref.watch(dioProvider),
              farmId: farm?.id,
              canRequest: canManage,
              farmLocation: farm?.location,
              latitude: farm?.latitude,
              longitude: farm?.longitude,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String saleId,
    String status,
  ) async {
    try {
      await ref
          .read(farmSalesProvider.notifier)
          .updateSaleStatus(saleId, status);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showSaleDialog(
    BuildContext context,
    WidgetRef ref,
    List<FarmBuyer> buyerRows,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (buyerRows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noBuyers)));
      context.go(AppRoutes.buyers);
      return;
    }
    final formKey = GlobalKey<FormState>();
    final itemController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final notesController = TextEditingController();
    final referenceController = TextEditingController(
      text: 'FA-${DateTime.now().millisecondsSinceEpoch}',
    );
    String buyerId = buyerRows.first.id;
    String currency = 'KES';
    DateTime orderedAt = DateTime.now();
    DateTime? expectedAt;
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.addFarmSale),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: buyerId,
                      decoration: InputDecoration(labelText: l10n.saleBuyer),
                      items: [
                        for (final buyer in buyerRows)
                          DropdownMenuItem(
                            value: buyer.id,
                            child: Text(buyer.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => buyerId = value ?? buyerId),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: itemController,
                      decoration: InputDecoration(labelText: l10n.saleItem),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.saleItemRequired
                          : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.saleQuantity,
                            ),
                            validator: (value) =>
                                _positiveNumberError(context, value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.saleUnitPrice,
                            ),
                            validator: (value) =>
                                _positiveNumberError(context, value),
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: referenceController,
                      decoration: InputDecoration(
                        labelText: l10n.saleReference,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.saleReferenceRequired
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: InputDecoration(labelText: l10n.saleCurrency),
                      items: const [
                        DropdownMenuItem(value: 'KES', child: Text('KES')),
                        DropdownMenuItem(value: 'UGX', child: Text('UGX')),
                        DropdownMenuItem(value: 'TZS', child: Text('TZS')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => currency = value ?? currency),
                    ),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(labelText: l10n.saleNotes),
                      maxLines: 2,
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 3650),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                          initialDate: orderedAt,
                        );
                        if (date != null) {
                          setDialogState(() => orderedAt = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        '${l10n.saleOrderDate}: ${MaterialLocalizations.of(context).formatMediumDate(orderedAt)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 3650),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                          initialDate: expectedAt ?? DateTime.now(),
                        );
                        if (date != null) {
                          setDialogState(() => expectedAt = date);
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        expectedAt == null
                            ? l10n.saleExpectedDate
                            : '${l10n.saleExpectedDate}: ${MaterialLocalizations.of(context).formatMediumDate(expectedAt!)}',
                      ),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final item = FarmSaleItem(
                          name: itemController.text.trim(),
                          quantity: double.parse(
                            quantityController.text.trim(),
                          ),
                          unitPrice: double.parse(priceController.text.trim()),
                        );
                        await ref
                            .read(farmSalesProvider.notifier)
                            .createSale(
                              buyerId: buyerId,
                              reference: referenceController.text.trim(),
                              item: item,
                              currency: currency,
                              orderedAt: orderedAt,
                              expectedAt: expectedAt,
                              notes: notesController.text.trim(),
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (exception) {
                        setDialogState(() {
                          saving = false;
                          error = '$exception';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.saveTask),
            ),
          ],
        ),
      ),
    );
    itemController.dispose();
    quantityController.dispose();
    priceController.dispose();
    notesController.dispose();
    referenceController.dispose();
  }

  String? _positiveNumberError(BuildContext context, String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return AppLocalizations.of(context).positiveAmountRequired;
    }
    return null;
  }

  static String _periodLabel(String range) => switch (range) {
    'today' => 'Today',
    'week' => 'This week',
    'year' => 'This year',
    _ => 'This month',
  };
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.canManage,
    required this.onStatusChanged,
  });
  final FarmSale sale;
  final bool canManage;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusLabels = {
      'pending': l10n.orderStatusPending,
      'ongoing': l10n.orderStatusOngoing,
      'completed': l10n.orderStatusCompleted,
      'cancelled': l10n.orderStatusCancelled,
      'suspended': l10n.orderStatusPending,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sale.reference,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: l10n.status,
                    onSelected: onStatusChanged,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pending',
                        child: Text(l10n.orderStatusPending),
                      ),
                      PopupMenuItem(
                        value: 'ongoing',
                        child: Text(l10n.orderStatusOngoing),
                      ),
                      PopupMenuItem(
                        value: 'completed',
                        child: Text(l10n.orderStatusCompleted),
                      ),
                      PopupMenuItem(
                        value: 'cancelled',
                        child: Text(l10n.orderStatusCancelled),
                      ),
                    ],
                    child: Chip(
                      label: Text(statusLabels[sale.status] ?? sale.status),
                    ),
                  )
                else
                  Chip(label: Text(statusLabels[sale.status] ?? sale.status)),
              ],
            ),
            Text(
              sale.customerName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            for (final item in sale.items)
              Text(
                '${item.name} · ${item.quantity} × ${sale.currency} ${item.unitPrice.toStringAsFixed(2)}',
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(sale.orderedAt.toLocal()),
                ),
                Text(
                  '${sale.currency} ${sale.totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryGreen),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
}
