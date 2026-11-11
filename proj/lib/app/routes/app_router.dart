import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../features/herd/presentation/pages/herd_page.dart';
import '../../features/crops/presentation/pages/crop_cycles_page.dart';
import '../../features/crops/presentation/pages/crop_activities_page.dart';
import '../../features/health/presentation/pages/health_page.dart';
import '../../features/health/presentation/pages/vaccination_page.dart';
import '../../features/health/presentation/pages/medication_page.dart';
import '../../features/health/presentation/pages/deworming_page.dart';
import '../../features/health/presentation/pages/mortality_page.dart';
import '../../features/breeding/presentation/pages/breeding_page.dart';
import '../../features/feed/presentation/pages/feed_page.dart';
import '../../features/feed/presentation/pages/formulation_page.dart';
import '../../features/feed/presentation/providers/feed_provider.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/growth/presentation/pages/growth_page.dart';
import '../../features/finance/presentation/pages/finance_page.dart';
import '../../features/sales/presentation/pages/sales_page.dart';
import '../../features/sales/presentation/pages/buyers_page.dart';
import '../../features/tasks/presentation/pages/tasks_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/about/presentation/pages/about_page.dart';
import '../../features/settings/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/settings_details_page.dart';
import '../../features/settings/presentation/pages/billing_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/support/presentation/pages/support_page.dart';
import '../../features/crm/presentation/pages/crm_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/farm_selection_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/pin_lock_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/session_expired_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/create_account_page.dart';
import '../../features/onboarding/presentation/pages/country_page.dart';
import '../../features/onboarding/presentation/pages/account_type_page.dart';
import '../../features/onboarding/presentation/pages/herd_setup_page.dart';
import '../../features/onboarding/presentation/pages/subscription_page.dart';
import '../../features/onboarding/presentation/pages/payment_method_page.dart';
import '../../features/onboarding/presentation/pages/language_page.dart';
import '../../features/onboarding/presentation/pages/permissions_page.dart';
import '../../features/subscription/presentation/pages/payment_status_page.dart';
import '../../features/settings/presentation/pages/farm_management_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../shared/components/bottom_navigation.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/farm_app_mark.dart';
import '../../app/theme/app_colors.dart';
import 'app_routes.dart';
import 'route_guard.dart';
import 'permission_route.dart';
import '../../features/settings/presentation/providers/farm_access_provider.dart';
import '../../security/authorization/permissions.dart';
import '../../security/authorization/roles.dart';

abstract final class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: RouteGuard.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.pinLock,
        builder: (context, state) => const PinLockPage(),
      ),
      GoRoute(
        path: AppRoutes.permissions,
        builder: (context, state) => const PermissionsPage(),
      ),
      GoRoute(
        path: AppRoutes.language,
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: AppRoutes.country,
        builder: (context, state) => const CountryPage(),
      ),
      GoRoute(
        path: AppRoutes.accountType,
        builder: (context, state) => const AccountTypePage(),
      ),
      GoRoute(
        path: AppRoutes.herdSetup,
        builder: (context, state) => const HerdSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.createAccount,
        builder: (context, state) => const CreateAccountPage(),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const SubscriptionPage(),
      ),
      GoRoute(
        path: AppRoutes.billing,
        builder: (context, state) => const BillingPage(),
      ),
      GoRoute(
        path: AppRoutes.paymentMethod,
        builder: (context, state) => PaymentMethodPage.fromExtra(state.extra),
      ),
      GoRoute(
        path: AppRoutes.paymentStatus,
        builder: (context, state) => PaymentStatusPage.fromExtra(state.extra),
      ),
      GoRoute(
        path: AppRoutes.farmSelection,
        builder: (context, state) => const FarmSelectionPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        builder: (context, state) {
          final challengeId = state.uri.queryParameters['challengeId'] ?? '';
          final destination = state.uri.queryParameters['destination'] ?? '';
          final rememberMe = state.uri.queryParameters['rememberMe'] == 'true';
          return OtpVerificationPage(
            challengeId: challengeId,
            destination: destination,
            rememberMe: rememberMe,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sessionExpired,
        builder: (context, state) =>
            SessionExpiredPage(onSignIn: () => context.go(AppRoutes.login)),
      ),
      ShellRoute(
        builder: (context, state, child) => NavigationShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.herd,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageHerd,
              child: HerdPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.crops,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageCrops,
              child: CropCyclesPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.cropActivities,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageCrops,
              child: CropActivitiesPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.health,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageHerd,
              child: HealthPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.vaccination,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageHerd,
              child: VaccinationPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.medication,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageHerd,
              child: MedicationPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.deworming,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageHerd,
              child: DewormingPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.mortality,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageHerd,
              child: MortalityPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.breeding,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageBreeding,
              child: BreedingPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.feed,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageFeed,
              child: FeedPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.feedFormulations,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageFeed,
              child: FormulationPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.viewTasks,
              child: TasksPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.finance,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageFinance,
              child: FinancePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.growth,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageHerd,
              child: GrowthPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.salesAndExpenses,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.viewSales,
              child: SalesPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.buyers,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.viewSales,
              child: BuyersPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.inventory,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageFeed,
              child: InventoryPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.viewReports,
              child: ReportsPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.workers,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageMembers,
              child: FarmManagementPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.crm,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageSales,
              child: CrmPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.settingsDetails,
            builder: (context, state) => SettingsDetailsPage(
              initialTab: state.uri.queryParameters['tab'] ?? 'profile',
            ),
          ),
          GoRoute(
            path: AppRoutes.farmManagement,
            builder: (context, state) => const PermissionRoute(
              permission: AppPermission.manageMembers,
              child: FarmManagementPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.support,
            builder: (context, state) => const SupportPage(),
          ),
          GoRoute(
            path: AppRoutes.about,
            builder: (context, state) => const AboutPage(),
          ),
        ],
      ),
    ],
  );
}

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> {
  Timer? _permissionRefreshTimer;

  @override
  void initState() {
    super.initState();
    _permissionRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ref.invalidate(farmAccessProvider),
    );
  }

  @override
  void dispose() {
    _permissionRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final session = ref.watch(authProvider).valueOrNull;
    final role = session?.user.role;
    final access = ref.watch(farmAccessProvider);
    final permissions =
        access.valueOrNull?.permissionsFor(session?.user.id ?? '') ??
        (access.isLoading ? RolePermissions.all[role] ?? const {} : const {});
    final canViewHerd =
        role == UserRole.farmOwner ||
        role == UserRole.superAdmin ||
        permissions.contains(AppPermission.manageHerd);
    final canViewFeed =
        role == UserRole.farmOwner ||
        role == UserRole.superAdmin ||
        permissions.contains(AppPermission.manageFeed);
    final bottomRoutes = [
      AppRoutes.home,
      if (canViewHerd) AppRoutes.herd,
      if (canViewFeed) AppRoutes.feed,
      AppRoutes.profile,
    ];
    final selectedIndex = bottomRoutes.indexOf(location);
    return Scaffold(
      key: navigationScaffoldKey,
      drawer: const _AppDrawer(),
      body: widget.child,
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        showHerd: canViewHerd,
        showFeed: canViewFeed,
        onSelected: (index) => context.go(bottomRoutes[index]),
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    final user = session?.user;
    final farmName = session?.selectedFarm?.name ?? 'Farm App';
    final role = user?.role;
    final access = ref.watch(farmAccessProvider);
    final permissions =
        access.valueOrNull?.permissionsFor(user?.id ?? '') ??
        (access.isLoading ? RolePermissions.all[role] ?? const {} : const {});
    final isOwnerOrAdmin =
        role == UserRole.farmOwner || role == UserRole.superAdmin;
    bool allows(AppPermission permission) =>
        isOwnerOrAdmin || permissions.contains(permission);
    final initials = (user?.name.isNotEmpty ?? false)
        ? user!.name.trim()[0].toUpperCase()
        : '?';
    return Drawer(
      width: 300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: const BoxDecoration(
                color: AppColors.deepGreen,
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(initials: initials, radius: 26),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const FarmAppMark(size: 30),
                      const SizedBox(width: 10),
                      Text(
                        'FarmApp',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.inverseText,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    farmName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inverseMutedText,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                children: [
                  _DrawerSectionLabel(l10n.farmManagement),
                  _ListTile(
                    icon: Icons.home_outlined,
                    title: l10n.dashboard,
                    route: AppRoutes.home,
                  ),
                  if (allows(AppPermission.manageCrops))
                    _ListTile(
                      icon: Icons.agriculture_outlined,
                      title: 'Crop farming',
                      route: AppRoutes.crops,
                    ),
                  if (allows(AppPermission.manageCrops))
                    _ListTile(
                      icon: Icons.event_note_outlined,
                      title: 'Field activities',
                      route: AppRoutes.cropActivities,
                    ),
                  if (allows(AppPermission.manageHerd)) ...[
                    _ListTile(
                      icon: Icons.pets_outlined,
                      title: l10n.herd,
                      route: AppRoutes.herd,
                    ),
                    _ListTile(
                      icon: Icons.health_and_safety_outlined,
                      title: l10n.health,
                      route: AppRoutes.health,
                    ),
                    _ListTile(
                      icon: Icons.vaccines_outlined,
                      title: 'Vaccinations',
                      route: AppRoutes.vaccination,
                    ),
                    _ListTile(
                      icon: Icons.medication_outlined,
                      title: 'Medication',
                      route: AppRoutes.medication,
                    ),
                    _ListTile(
                      icon: Icons.monitor_weight_outlined,
                      title: l10n.growth,
                      route: AppRoutes.growth,
                    ),
                  ],
                  if (allows(AppPermission.manageFeed)) ...[
                    _ListTile(
                      icon: Icons.restaurant_outlined,
                      title: l10n.feed,
                      route: AppRoutes.feed,
                    ),
                    _ListTile(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.inventory,
                      route: AppRoutes.inventory,
                    ),
                  ],
                  if (allows(AppPermission.manageBreeding))
                    _ListTile(
                      icon: Icons.favorite_outline,
                      title: l10n.breeding,
                      route: AppRoutes.breeding,
                    ),
                  if (allows(AppPermission.viewSales))
                    _ListTile(
                      icon: Icons.point_of_sale_outlined,
                      title: l10n.sales,
                      route: AppRoutes.salesAndExpenses,
                    ),
                  if (allows(AppPermission.manageFinance))
                    _ListTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Finance',
                      route: AppRoutes.finance,
                    ),
                  _DrawerSectionLabel(l10n.workspace),
                  if (allows(AppPermission.viewReports))
                    _ListTile(
                      icon: Icons.assessment_outlined,
                      title: l10n.reports,
                      route: AppRoutes.reports,
                    ),
                  _ListTile(
                    icon: Icons.notifications_outlined,
                    title: l10n.notifications,
                    route: AppRoutes.notifications,
                  ),
                  _ListTile(
                    icon: Icons.support_agent_outlined,
                    title: l10n.customerSupport,
                    route: AppRoutes.support,
                  ),
                  if (allows(AppPermission.manageMembers))
                    _ListTile(
                      icon: Icons.manage_accounts_outlined,
                      title: l10n.myTeam,
                      route: AppRoutes.farmManagement,
                    ),
                  _ListTile(
                    icon: Icons.settings_outlined,
                    title: l10n.settings,
                    route: AppRoutes.settings,
                  ),
                  _ListTile(
                    icon: Icons.info_outline,
                    title: l10n.about,
                    route: AppRoutes.about,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(),
                  ),
                  _LogoutTile(
                    title: l10n.logout,
                    onLogout: () async {
                      Object? logoutError;
                      final session = ref.read(authProvider).valueOrNull;
                      if (session != null) {
                        try {
                          await ref
                              .read(feedReminderServiceProvider)
                              .cancelFeedReminders();
                          await ref
                              .read(feedScheduleStorageProvider)
                              .clearUser(session.user.id);
                        } on Object {
                          // Signing out must continue even if local cleanup fails.
                        }
                      }
                      try {
                        await ref.read(logoutUseCaseProvider)();
                      } catch (error) {
                        logoutError = error;
                      } finally {
                        ref.read(authProvider.notifier).clearSession();
                        ref.invalidate(feedScheduleProvider);
                        ref.invalidate(sessionRestoreProvider);
                      }
                      if (!context.mounted) return;
                      if (logoutError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'You are signed out. The server could not confirm it.',
                            ),
                          ),
                        );
                      }
                      context.go(AppRoutes.login);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    final selected = GoRouterState.of(context).uri.path == route;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        minLeadingWidth: 28,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        selectedTileColor: AppColors.primaryGreen.withValues(alpha: 0.11),
        leading: Icon(
          icon,
          color: selected ? AppColors.deepGreen : AppColors.mutedText,
          size: 22,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: selected ? AppColors.deepGreen : AppColors.text,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          context.go(route);
        },
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.primaryGreen,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    ),
  );
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onLogout, required this.title});

  final Future<void> Function() onLogout;
  final String title;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    tileColor: AppColors.danger.withValues(alpha: 0.06),
    leading: const Icon(Icons.logout, color: AppColors.danger),
    title: Text(title),
    textColor: AppColors.danger,
    onTap: onLogout,
  );
}
