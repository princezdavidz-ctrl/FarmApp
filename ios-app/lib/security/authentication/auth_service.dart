import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  AuthService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const accessTokenKey = 'auth.access_token';
  static const refreshTokenKey = 'auth.refresh_token';
  static const userProfileKey = 'auth.user_profile';
  static const farmsKey = 'auth.farms';
  static const selectedFarmKey = 'auth.selected_farm';
  static const rememberMeKey = 'auth.remember_me';
  static const biometricPreferenceKey = 'auth.biometric_enabled';
  static const sessionTimestampKey = 'auth.session_timestamp';

  final FlutterSecureStorage _storage;

  Future<void> saveTokenPair({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: accessTokenKey, value: accessToken);
    await _storage.write(key: refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: refreshTokenKey);

  Future<void> clearSession() async {
    for (final key in const [
      accessTokenKey,
      refreshTokenKey,
      userProfileKey,
      farmsKey,
      selectedFarmKey,
      rememberMeKey,
      sessionTimestampKey,
    ]) {
      await _storage.delete(key: key);
    }
  }

  Future<void> setRememberMe(bool value) =>
      _storage.write(key: rememberMeKey, value: '$value');
  Future<bool> get rememberMe async =>
      (await _storage.read(key: rememberMeKey)) == 'true';

  Future<void> setSessionTimestamp(DateTime timestamp) => _storage.write(
    key: sessionTimestampKey,
    value: timestamp.toIso8601String(),
  );

  Future<DateTime?> readSessionTimestamp() async {
    final value = await _storage.read(key: sessionTimestampKey);
    return value == null ? null : DateTime.tryParse(value);
  }
}
