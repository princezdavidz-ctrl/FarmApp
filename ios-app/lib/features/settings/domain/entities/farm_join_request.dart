import '../../../../security/authorization/roles.dart';

class FarmJoinRequest {
  const FarmJoinRequest({
    required this.id,
    required this.farmId,
    required this.farmName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.requestedRole,
    required this.status,
    this.message,
    this.createdAt,
  });

  final String id;
  final String farmId;
  final String? farmName;
  final String userId;
  final String? userName;
  final String? userEmail;
  final UserRole requestedRole;
  final String status;
  final String? message;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
}
