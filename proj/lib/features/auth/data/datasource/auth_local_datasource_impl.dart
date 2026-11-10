import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../security/authentication/auth_service.dart';
import '../../domain/entities/farm.dart';
import '../../domain/entities/session.dart';
import '../models/farm_model.dart';
import '../models/user_model.dart';
import 'auth_local_datasource.dart';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveSession(Session session) async {
    await _storage.write(
      key: AuthService.accessTokenKey,
      value: session.accessToken,
    );
    await _storage.write(
      key: AuthService.refreshTokenKey,
      value: session.refreshToken,
    );
    await _storage.write(
      key: AuthService.userProfileKey,
      value: jsonEncode(
        UserModel(
          id: session.user.id,
          name: session.user.name,
          email: session.user.email,
          phone: session.user.phone,
          role: session.user.role,
        ).toJson(),
      ),
    );
    await _storage.write(
      key: AuthService.farmsKey,
      value: jsonEncode(
        session.farms
            .map(
              (farm) => FarmModel(
                id: farm.id,
                name: farm.name,
                location: farm.location,
                inviteCode: farm.inviteCode,
                motherPigCount: farm.motherPigCount,
                registeredPigletCount: farm.registeredPigletCount,
                pregnantPigCount: farm.pregnantPigCount,
              ).toJson(),
            )
            .toList(),
      ),
    );
    if (session.selectedFarm != null) {
      await saveSelectedFarm(session.selectedFarm!);
    } else {
      await _storage.delete(key: AuthService.selectedFarmKey);
    }
  }

  @override
  Future<Session?> readSession() async {
    final accessToken = await _storage.read(key: AuthService.accessTokenKey);
    final refreshToken = await _storage.read(key: AuthService.refreshTokenKey);
    final userJson = await _storage.read(key: AuthService.userProfileKey);
    if (accessToken == null || refreshToken == null || userJson == null) {
      return null;
    }
    try {
      final user = UserModel.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
      final farmsJson = await _storage.read(key: AuthService.farmsKey);
      final farms = farmsJson == null
          ? <FarmModel>[]
          : (jsonDecode(farmsJson) as List<dynamic>)
                .map((item) => FarmModel.fromJson(item as Map<String, dynamic>))
                .toList();
      final farmJson = await _storage.read(key: AuthService.selectedFarmKey);
      final farm = farmJson == null
          ? null
          : FarmModel.fromJson(jsonDecode(farmJson) as Map<String, dynamic>);
      return Session(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
        farms: farms,
        selectedFarm: farm,
      );
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  @override
  Future<void> saveSelectedFarm(Farm farm) => _storage.write(
    key: AuthService.selectedFarmKey,
    value: jsonEncode(
      FarmModel(
        id: farm.id,
        name: farm.name,
        location: farm.location,
        inviteCode: farm.inviteCode,
        motherPigCount: farm.motherPigCount,
        registeredPigletCount: farm.registeredPigletCount,
        pregnantPigCount: farm.pregnantPigCount,
      ).toJson(),
    ),
  );

  @override
  Future<void> clear() async {
    for (final key in const [
      AuthService.accessTokenKey,
      AuthService.refreshTokenKey,
      AuthService.userProfileKey,
      AuthService.farmsKey,
      AuthService.selectedFarmKey,
      AuthService.rememberMeKey,
      AuthService.sessionTimestampKey,
    ]) {
      await _storage.delete(key: key);
    }
  }
}
