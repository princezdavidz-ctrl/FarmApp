import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../security/authorization/permissions.dart';
import '../../../../security/authorization/roles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/data/notifications_api.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../../shared/components/bottom_navigation.dart';
import '../../../settings/presentation/providers/farm_access_provider.dart';
import '../providers/farm_overview_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  Timer? _notificationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _notificationRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) {
      ref.invalidate(notificationsProvider);
    });
  }

  @override
  void dispose() {
    _notificationRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _clearNotifications(List<FarmNotification> notifications) async {
    final unread = notifications.where((notification) => !notification.isRead);
    if (unread.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No unread notifications.')));
      return;
    }

    try {
      for (final notification in unread) {
        await ref
            .read(notificationsProvider.notifier)
            .markAsRead(notification.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared ${unread.length} notifications.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear notifications: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authProvider).valueOrNull;
    final role = session?.user.role;
    final access = ref.watch(farmAccessProvider);
    final permissions =
        access.valueOrNull?.permissionsFor(session?.user.id ?? '') ??
        (access.isLoading ? RolePermissions.all[role] ?? const {} : const {});
    bool allows(AppPermission permission) =>
        role == UserRole.farmOwner ||
        role == UserRole.superAdmin ||
        permissions.contains(permission);
    final canViewOverview =
        allows(AppPermission.manageHerd) ||
        allows(AppPermission.manageFeed) ||
        allows(AppPermission.viewTasks) ||
        allows(AppPermission.viewSales);
    final farmId = session?.selectedFarm?.id;
    final overview = farmId == null || !canViewOverview
        ? const AsyncValue<Map<String, dynamic>>.data({})
        : ref.watch(farmOverviewProvider(farmId));
    final firstName = session?.user.name.split(' ').first ?? 'there';
    final farmName = session?.selectedFarm?.name ?? 'Farm App';
    final registeredHerdCount = session?.selectedFarm?.registeredHerdCount ?? 0;
    final liveHerdCount = overview.valueOrNull?['herd_count'] as num?;
    final herdCount = liveHerdCount == null
        ? registeredHerdCount
        : liveHerdCount.toInt() > registeredHerdCount
        ? liveHerdCount.toInt()
        : registeredHerdCount;
    final healthOverview = allows(AppPermission.manageHerd)
        ? ref.watch(healthOverviewProvider)
        : const AsyncValue<Map<String, dynamic>>.data({});
    final pregnantCount = session?.selectedFarm?.pregnantPigCount ?? 0;
    final vaccinatedCount = healthOverview.valueOrNull?['vaccinated'] ?? 0;
    final notifications =
        ref.watch(notificationsProvider).valueOrNull ??
        const <FarmNotification>[];
    FarmNotification? crmMessage;
    for (final notification in notifications) {
      if (notification.type == 'crm_message') {
        crmMessage = notification;
        break;
      }
    }
    final statCards = <Widget>[
      if (allows(AppPermission.manageHerd))
        _StatCard(
          icon: Icons.pets_outlined,
          label: l10n.herdSize,
          value: '$herdCount',
          color: AppColors.primaryGreen,
        ),
      if (allows(AppPermission.manageFeed))
        _StatCard(
          icon: Icons.grass_outlined,
          label: l10n.feedStock,
          value: overview.valueOrNull?['feed_stock']?.toString() ?? '—',
          color: AppColors.warning,
        ),
      if (allows(AppPermission.viewTasks))
        _StatCard(
          icon: Icons.checklist_outlined,
          label: l10n.tasksDue,
          value: overview.valueOrNull?['tasks_due']?.toString() ?? '—',
          color: AppColors.danger,
        ),
      if (allows(AppPermission.viewSales))
        _StatCard(
          icon: Icons.point_of_sale_outlined,
          label: l10n.salesThisWeek,
          value: overview.valueOrNull?['sales_this_week']?.toString() ?? '—',
          color: AppColors.deepGreen,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.openMenu,
          icon: const Icon(Icons.menu),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(farmName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.openNotifications,
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go(AppRoutes.notifications),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/home_farm_background.png'),
                fit: BoxFit.cover,
                opacity: 0.07,
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: () async {
              if (farmId == null) return;
              ref.invalidate(farmOverviewProvider(farmId));
              ref.invalidate(notificationsProvider);
              await ref.read(farmOverviewProvider(farmId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              children: [
                if (overview.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (overview.hasError)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        AppDimensions.spacingMedium,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: AppDimensions.spacingMedium),
                          Expanded(child: Text(l10n.overviewLoadFailed)),
                          TextButton(
                            onPressed: farmId == null
                                ? null
                                : () => ref.invalidate(
                                    farmOverviewProvider(farmId),
                                  ),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryGreen, AppColors.deepGreen],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepGreen.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -45,
                        bottom: -75,
                        child: Opacity(
                          opacity: 0.12,
                          child: const Icon(
                            Icons.agriculture,
                            size: 220,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(
                          AppDimensions.spacingLarge,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inverseText.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.inverseText.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: Text(
                                l10n.farmOverview,
                                style: const TextStyle(
                                  color: AppColors.inverseText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${l10n.goodDay}, $firstName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: AppColors.inverseText,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              crmMessage?.body ?? l10n.farmRunningSmoothly,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.inverseMutedText,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 17,
                                  color: AppColors.leaf,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    farmName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.inverseText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (herdCount > 0)
                                  Text(
                                    '$herdCount ${l10n.herdSize.toLowerCase()}',
                                    style: const TextStyle(
                                      color: AppColors.inverseMutedText,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (notifications.any((item) => !item.isRead)) ...[
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _NotificationBanner(
                    notification: notifications.firstWhere(
                      (item) => !item.isRead,
                    ),
                    onOpen: () => context.go(AppRoutes.notifications),
                  ),
                ],
                const SizedBox(height: AppDimensions.spacingLarge),
                if (allows(AppPermission.manageHerd)) ...[
                  _HerdStatusCard(
                    pregnant: pregnantCount,
                    vaccinated: vaccinatedCount,
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                ],
                if (statCards.isNotEmpty)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppDimensions.spacingMedium,
                    crossAxisSpacing: AppDimensions.spacingMedium,
                    childAspectRatio: 1.08,
                    children: statCards,
                  ),
                if (allows(AppPermission.manageHerd) &&
                    registeredHerdCount > 0) ...[
                  const SizedBox(height: AppDimensions.spacingMedium),
                  _RegisteredHerdBanner(
                    motherPigs: session?.selectedFarm?.motherPigCount ?? 0,
                    piglets: session?.selectedFarm?.registeredPigletCount ?? 0,
                    pregnantPigs: session?.selectedFarm?.pregnantPigCount ?? 0,
                  ),
                ],
                const SizedBox(height: AppDimensions.spacingLarge),
                _SectionHeader(
                  title: l10n.quickActions,
                  actionLabel: 'Clear',
                  onAction: () => _clearNotifications(notifications),
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppDimensions.spacingMedium,
                  crossAxisSpacing: AppDimensions.spacingMedium,
                  childAspectRatio: 0.95,
                  children: [
                    if (allows(AppPermission.manageHerd))
                      _QuickAction(
                        icon: Icons.pets_outlined,
                        label: l10n.herd,
                        color: AppColors.pigPink,
                        onTap: () => context.go(AppRoutes.herd),
                      ),
                    if (allows(AppPermission.manageFeed))
                      _QuickAction(
                        icon: Icons.grass_outlined,
                        label: l10n.feed,
                        color: AppColors.leaf,
                        onTap: () => context.go(AppRoutes.feed),
                      ),
                    if (allows(AppPermission.viewTasks))
                      _QuickAction(
                        icon: Icons.check_circle_outline,
                        label: l10n.tasks,
                        color: AppColors.warmGold,
                        onTap: () => context.go(AppRoutes.tasks),
                      ),
                    if (allows(AppPermission.manageFinance))
                      _QuickAction(
                        icon: Icons.account_balance_wallet_outlined,
                        label: l10n.finance,
                        color: AppColors.warmGold,
                        onTap: () => context.go(AppRoutes.finance),
                      ),
                    if (allows(AppPermission.manageSales))
                      _QuickAction(
                        icon: Icons.groups_outlined,
                        label: l10n.customers,
                        color: AppColors.info,
                        onTap: () => context.go(AppRoutes.crm),
                      ),
                    _QuickAction(
                      icon: Icons.support_agent_outlined,
                      label: l10n.customerSupport,
                      color: AppColors.violet,
                      onTap: () => context.go(AppRoutes.support),
                    ),
                    if (allows(AppPermission.manageMembers))
                      _QuickAction(
                        icon: Icons.group_outlined,
                        label: l10n.teamAndPolicies,
                        color: AppColors.aqua,
                        onTap: () => context.go(AppRoutes.farmManagement),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisteredHerdBanner extends StatelessWidget {
  const _RegisteredHerdBanner({
    required this.motherPigs,
    required this.piglets,
    required this.pregnantPigs,
  });

  final int motherPigs;
  final int piglets;
  final int pregnantPigs;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (motherPigs > 0) '$motherPigs mother pigs',
      if (piglets > 0) '$piglets piglets',
      if (pregnantPigs > 0) '$pregnantPigs pregnant',
    ];
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radius),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.pigPink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, color: AppColors.inverseText),
          ),
          const SizedBox(width: AppDimensions.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your registered herd',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  details.join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.08), AppColors.surface],
          ),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const Spacer(),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _HerdStatusCard extends StatelessWidget {
  const _HerdStatusCard({required this.pregnant, required this.vaccinated});

  final int pregnant;
  final int vaccinated;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _HerdStatusMetric(
        label: AppLocalizations.of(context).pregnant,
        value: '$pregnant',
        color: AppColors.pigPink,
      ),
      _HerdStatusMetric(
        label: AppLocalizations.of(context).vaccinated,
        value: '$vaccinated',
        color: AppColors.info,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pregnancy & vaccination',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            Row(
              children: metrics
                  .map(
                    (metric) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: metric.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              metric.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HerdStatusMetric {
  const _HerdStatusMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radius),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacingSmall,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radius),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.inverseText, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (actionLabel != null && onAction != null) ...[
        const Spacer(),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(actionLabel!),
        ),
      ],
    ],
  );
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({required this.notification, required this.onOpen});

  final FarmNotification notification;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = switch (notification.severity) {
      'warning' => AppColors.warning,
      'danger' => AppColors.danger,
      'success' => AppColors.success,
      _ => AppColors.info,
    };
    return Card(
      color: color.withValues(alpha: 0.12),
      child: ListTile(
        leading: Icon(Icons.notifications_active_outlined, color: color),
        title: Text(notification.title),
        subtitle: Text(
          notification.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}
