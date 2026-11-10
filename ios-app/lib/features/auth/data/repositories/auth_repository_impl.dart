import '../../../../security/authorization/roles.dart';
import '../../domain/entities/farm.dart';
import '../../domain/entities/login_challenge.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasource/auth_local_datasource.dart';
import '../datasource/auth_remote_datasource.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this.remote, required this.local});

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  @override
  Future<LoginChallenge> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    final challenge = await remote.login(
      LoginRequest(
        identifier: email,
        password: password,
        rememberMe: rememberMe,
      ),
    );
    return LoginChallenge(
      id: challenge.challengeId,
      destination: challenge.destination,
    );
  }

  @override
  Future<LoginChallenge> resendLoginOtp(String challengeId) async {
    final response = await remote.resendLoginOtp(challengeId);
    return LoginChallenge(
      id: response.challengeId,
      destination: response.destination,
    );
  }

  @override
  Future<Session> verifyLoginOtp(String challengeId, String code) async {
    final session = await _withPreferredFarm(
      (await remote.verifyLoginOtp(challengeId, code)).toEntity(),
    );
    await local.saveSession(session);
    return session;
  }

  @override
  Future<Session> loginWithGoogle(String idToken) async {
    final session = await _withPreferredFarm(
      (await remote.loginWithGoogle(idToken)).toEntity(),
    );
    await local.saveSession(session);
    return session;
  }

  @override
  Future<Session> loginWithApple(String idToken) async {
    final session = await _withPreferredFarm(
      (await remote.loginWithApple(idToken)).toEntity(),
    );
    await local.saveSession(session);
    return session;
  }

  @override
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
  }) async {
    final response = await remote.register(
      RegisterRequest(
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
      ),
    );
    final session = await _withPreferredFarm(
      response.toEntity(),
      preferredFarmName: farmName,
    );
    await local.saveSession(session);
    return session;
  }

  @override
  Future<void> logout() async {
    final session = await local.readSession();
    try {
      if (session != null) await remote.logout(session.accessToken);
    } finally {
      await local.clear();
    }
  }

  @override
  Future<Session?> refreshSession() async {
    final session = await local.readSession();
    if (session == null) return null;
    final response = await remote.refresh(session.refreshToken);
    final refreshed = await _withPreferredFarm(
      response.toEntity(),
      preferredFarmId: session.selectedFarm?.id,
    );
    await local.saveSession(refreshed);
    return refreshed;
  }

  @override
  Future<Session> selectFarm(Farm farm) async {
    final session = await local.readSession();
    if (session == null) throw StateError('No authenticated session.');
    final selected = Session(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: session.user,
      farms: session.farms,
      selectedFarm: farm,
    );
    await local.saveSelectedFarm(farm);
    await local.saveSession(selected);
    return selected;
  }

  @override
  Future<void> forgotPassword(String email) => remote.forgotPassword(email);

  Future<Session> _withPreferredFarm(
    Session session, {
    String? preferredFarmId,
    String? preferredFarmName,
  }) async {
    final previous = await local.readSession();
    final preferredId =
        preferredFarmId ??
        (preferredFarmName == null ? previous?.selectedFarm?.id : null);
    Farm? selectedFarm;

    for (final farm in session.farms) {
      if (preferredId != null && farm.id == preferredId) {
        selectedFarm = farm;
        break;
      }
    }
    if (selectedFarm == null && preferredFarmName != null) {
      for (final farm in session.farms) {
        if (farm.name.trim().toLowerCase() ==
            preferredFarmName.trim().toLowerCase()) {
          selectedFarm = farm;
          break;
        }
      }
    }
    selectedFarm ??= session.farms.length == 1 ? session.farms.single : null;

    return Session(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: session.user,
      farms: session.farms,
      selectedFarm: selectedFarm,
    );
  }
}
