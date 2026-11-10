enum UserRole { superAdmin, farmOwner, farmManager, farmWorker, accountant, salesMarketing, viewer }

extension UserRoleX on UserRole {
  String get value => toString().split('.').last;

  String get label => switch (this) {
    UserRole.superAdmin => 'Super admin',
    UserRole.farmOwner => 'Farm owner',
    UserRole.farmManager => 'Farm manager',
    UserRole.farmWorker => 'Farm worker',
    UserRole.accountant => 'Accountant',
    UserRole.salesMarketing => 'Sales & marketing',
    UserRole.viewer => 'Viewer',
  };
}

UserRole parseUserRole(Object? value) {
  if (value is UserRole) return value;
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return UserRole.viewer;

  return UserRole.values.firstWhere(
    (role) => role.value == raw || role.label.toLowerCase() == raw.toLowerCase(),
    orElse: () => UserRole.viewer,
  );
}
