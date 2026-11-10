import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:proj/features/settings/domain/entities/backup_settings.dart';
import 'package:proj/features/settings/domain/entities/device_settings.dart';
import 'package:proj/features/settings/domain/entities/payment_settings.dart';
import 'package:proj/features/settings/domain/entities/security_settings.dart';
import 'package:proj/features/settings/domain/entities/user_preferences.dart';

/// Local storage for user settings, preferences, and configurations.
class SettingsLocalDataSource {
  SettingsLocalDataSource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _preferencesKey = 'user_preferences';
  static const _securityKey = 'security_settings';
  static const _backupKey = 'backup_settings';
  static const _paymentKey = 'payment_settings';
  static const _devicesKey = 'device_settings';

  // User Preferences
  Future<UserPreferences> readPreferences() async {
    try {
      final json = await _storage.read(key: _preferencesKey);
      if (json == null) return UserPreferences.defaults();
      return UserPreferences.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return UserPreferences.defaults();
    }
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    await _storage.write(
      key: _preferencesKey,
      value: jsonEncode(preferences.toJson()),
    );
  }

  // Security Settings
  Future<SecuritySettings> readSecuritySettings() async {
    try {
      final json = await _storage.read(key: _securityKey);
      if (json == null) return SecuritySettings.defaults();
      return SecuritySettings.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      return SecuritySettings.defaults();
    }
  }

  Future<void> saveSecuritySettings(SecuritySettings settings) async {
    await _storage.write(
      key: _securityKey,
      value: jsonEncode(settings.toJson()),
    );
  }

  // Backup Settings
  Future<BackupSettings> readBackupSettings() async {
    try {
      final json = await _storage.read(key: _backupKey);
      if (json == null) return BackupSettings.defaults();
      return BackupSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return BackupSettings.defaults();
    }
  }

  Future<void> saveBackupSettings(BackupSettings settings) async {
    await _storage.write(key: _backupKey, value: jsonEncode(settings.toJson()));
  }

  // Payment Settings
  Future<PaymentSettings> readPaymentSettings() async {
    try {
      final json = await _storage.read(key: _paymentKey);
      if (json == null) return PaymentSettings.defaults();
      return PaymentSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return PaymentSettings.defaults();
    }
  }

  Future<void> savePaymentSettings(PaymentSettings settings) async {
    await _storage.write(
      key: _paymentKey,
      value: jsonEncode(settings.toJson()),
    );
  }

  // Device Settings
  Future<DeviceSettings> readDeviceSettings() async {
    try {
      final json = await _storage.read(key: _devicesKey);
      if (json == null) return DeviceSettings.defaults();
      final data = jsonDecode(json) as Map<String, dynamic>;
      return DeviceSettings(
        devices: (data['devices'] as List<dynamic>? ?? [])
            .map((e) => ConnectedDevice.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return DeviceSettings.defaults();
    }
  }

  Future<void> saveDeviceSettings(DeviceSettings settings) async {
    await _storage.write(
      key: _devicesKey,
      value: jsonEncode({
        'devices': settings.devices.map((d) => d.toJson()).toList(),
      }),
    );
  }
}
