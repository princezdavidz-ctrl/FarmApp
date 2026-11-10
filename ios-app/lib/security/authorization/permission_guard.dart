import 'permissions.dart';
import 'roles.dart';

class PermissionGuard {
	const PermissionGuard(this.role);
	final UserRole role;
	bool can(AppPermission permission) => RolePermissions.can(role, permission);
	void require(AppPermission permission) {
		if (!can(permission)) throw StateError('Permission denied: ${permission.name}');
	}
}
