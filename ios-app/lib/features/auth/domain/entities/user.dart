import '../../../../security/authorization/roles.dart';

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
}
