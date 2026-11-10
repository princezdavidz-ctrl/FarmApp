import '../../../../security/authorization/permissions.dart';
import '../../../../security/authorization/roles.dart';

class FarmMember {
  const FarmMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.identityNumber,
    this.permissions = const {},
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String identityNumber;
  final Set<AppPermission> permissions;

  FarmMember copyWith({Set<AppPermission>? permissions}) => FarmMember(
        id: id,
        name: name,
        email: email,
        role: role,
        identityNumber: identityNumber,
        permissions: permissions ?? this.permissions,
      );
}