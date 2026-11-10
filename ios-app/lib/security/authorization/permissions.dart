import 'roles.dart';

enum AppPermission {
  viewDashboard,
  manageHerd,
  manageBreeding,
  manageFeed,
  manageFinance,
  viewSales,
  manageSales,
  viewTasks,
  manageTasks,
  viewReports,
  manageSettings,
  manageMembers,
  managePolicies,
  linkFarmManager,
}

abstract final class RolePermissions {
  static final Map<UserRole, Set<AppPermission>> all = {
    UserRole.superAdmin: AppPermission.values.toSet(),
    UserRole.farmOwner: AppPermission.values.toSet(),
    UserRole.farmManager: {
      AppPermission.viewDashboard,
      AppPermission.manageHerd,
      AppPermission.manageBreeding,
      AppPermission.manageFeed,
      AppPermission.viewSales,
      AppPermission.manageSales,
      AppPermission.viewTasks,
      AppPermission.manageTasks,
      AppPermission.viewReports,
    },
    UserRole.farmWorker: {
      AppPermission.viewDashboard,
      AppPermission.manageHerd,
      AppPermission.manageFeed,
      AppPermission.viewTasks,
    },
    UserRole.accountant: {
      AppPermission.viewDashboard,
      AppPermission.manageFinance,
      AppPermission.viewSales,
      AppPermission.viewReports,
    },
    UserRole.salesMarketing: {
      AppPermission.viewDashboard,
      AppPermission.viewSales,
      AppPermission.manageSales,
      AppPermission.viewReports,
    },
    UserRole.viewer: {AppPermission.viewDashboard, AppPermission.viewReports},
  };

  static bool can(UserRole role, AppPermission permission) =>
      all[role]?.contains(permission) ?? false;
}
