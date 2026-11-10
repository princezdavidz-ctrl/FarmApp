import '../../../../security/authorization/roles.dart';
import '../entities/farm.dart';
import '../entities/login_challenge.dart';
import '../entities/session.dart';

abstract interface class AuthRepository {
  Future<LoginChallenge> login(
    String email,
    String password, {
    bool rememberMe = false,
  });
  Future<LoginChallenge> resendLoginOtp(String challengeId);
  Future<Session> verifyLoginOtp(String challengeId, String code);
  Future<Session> loginWithGoogle(String idToken);
  Future<Session> loginWithApple(String idToken);
  Future<Session> register({
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
  });
  Future<void> logout();
  Future<Session?> refreshSession();
  Future<Session> selectFarm(Farm farm);
  Future<void> forgotPassword(String email);
}
