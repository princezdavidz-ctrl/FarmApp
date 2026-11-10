import '../../../../security/authorization/roles.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class Register {
  const Register(this.repository);
  final AuthRepository repository;

  Future<Session> call({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    String? farmName,
    String? inviteCode,
    int motherPigCount = 0,
    List<Map<String, dynamic>> pigletGroups = const [],
    int? pregnantPigCount,
    String farmingType = 'mixed',
    List<String> productionTypes = const [],
  }) => repository.register(
    name: name,
    email: email,
    phone: phone,
    password: password,
    role: role,
    farmName: farmName,
    inviteCode: inviteCode,
    motherPigCount: motherPigCount,
    pigletGroups: pigletGroups,
    pregnantPigCount: pregnantPigCount,
    farmingType: farmingType,
    productionTypes: productionTypes,
  );
}
