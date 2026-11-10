import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:proj/features/auth/presentation/providers/auth_providers.dart';
import 'package:proj/features/settings/data/settings_api.dart';
import 'package:proj/security/authentication/biometric_auth.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../feed/data/feed_reminder_service.dart';
import '../../../feed/data/feed_schedule_local_data_source.dart';
import '../../data/settings_local_data_source.dart';
import '../../domain/entities/backup_settings.dart';
import '../../domain/entities/device_settings.dart';
import '../../domain/entities/payment_settings.dart';
import '../../domain/entities/security_settings.dart';
import '../../domain/entities/user_preferences.dart';

// Local data source provider
final settingsLocalDataSourceProvider = Provider(
  (_) => SettingsLocalDataSource(),
);

// User Preferences Provider
class UserPreferencesNotifier extends AsyncNotifier<UserPreferences> {
  @override
  Future<UserPreferences> build() async {
    final local = ref.watch(settingsLocalDataSourceProvider);
    return local.readPreferences();
  }

  Future<void> updateLanguage(String language) async {
    if (language != 'en' && language != 'sw') {
      throw ArgumentError.value(language, 'language', 'Unsupported language');
    }
    final current = await future;
    final updated = current.copyWith(language: language);
    await ref.watch(settingsLocalDataSourceProvider).savePreferences(updated);
    state = AsyncData(updated);
  }

  Future<void> updateTheme(bool isDarkMode) async {
    final current = await future;
    final updated = current.copyWith(isDarkMode: isDarkMode);
    await ref.watch(settingsLocalDataSourceProvider).savePreferences(updated);
    ref.invalidateSelf();
  }

  Future<void> updateWeightUnit(String weightUnit) async {
    final current = await future;
    final updated = current.copyWith(weightUnit: weightUnit);
    await ref.watch(settingsLocalDataSourceProvider).savePreferences(updated);
    ref.invalidateSelf();
  }

  Future<void> updateDateFormat(String dateFormat) async {
    final current = await future;
    final updated = current.copyWith(dateFormat: dateFormat);
    await ref.watch(settingsLocalDataSourceProvider).savePreferences(updated);
    ref.invalidateSelf();
  }

  Future<void> updateCurrency(String currency) async {
    final current = await future;
    final updated = current.copyWith(currency: currency);
    await ref.watch(settingsLocalDataSourceProvider).savePreferences(updated);
    ref.invalidateSelf();
  }

  Future<void> updateNotificationToggle(
    String notificationType,
    bool enabled,
  ) async {
    final current = await future;
    final notifications = {...current.notifications};
    notifications[notificationType] = enabled;
    final updated = current.copyWith(notifications: notifications);
    await ref.watch(settingsLocalDataSourceProvider).savePreferences(updated);
    state = AsyncData(updated);
    if (notificationType == 'feeding') await _syncFeedReminders(updated);
  }

  Future<void> updateNotificationChannel(String channel, bool enabled) async {
    const supportedChannels = {'push', 'sms', 'email'};
    if (!supportedChannels.contains(channel)) {
      throw ArgumentError.value(channel, 'channel', 'Unsupported channel');
    }
    final current = await future;
    final channels = {...current.notificationChannels, channel: enabled};
    final updated = current.copyWith(notificationChannels: channels);
    await ref.watch(settingsLocalDataSourceProvider).savePreferences(updated);
    state = AsyncData(updated);
  }

  Future<void> updateNotificationSound(String sound) async {
    if (!FeedReminderService.supportedSounds.contains(sound)) {
      throw ArgumentError.value(
        sound,
        'sound',
        'Unsupported notification sound',
      );
    }
    final current = await future;
    final updated = current.copyWith(notificationSound: sound);
    await ref.watch(settingsLocalDataSourceProvider).savePreferences(updated);
    state = AsyncData(updated);
    await _syncFeedReminders(updated);
  }

  Future<void> _syncFeedReminders(UserPreferences preferences) async {
    final session = ref.read(authProvider).valueOrNull;
    final farm = session?.selectedFarm;
    final user = session?.user;
    if (farm == null || user == null) return;
    final entries = await FeedScheduleLocalDataSource().read(
      userId: user.id,
      farmId: farm.id,
    );
    await FeedReminderService().sync(
      entries,
      sound: preferences.notificationSound,
      enabled: preferences.notifications['feeding'] ?? true,
    );
  }
}

final userPreferencesProvider =
    AsyncNotifierProvider<UserPreferencesNotifier, UserPreferences>(
      UserPreferencesNotifier.new,
    );

final farmNameChangeRequestsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, farmId) {
      return SettingsApi(ref.watch(dioProvider)).farmNameChangeRequests(farmId);
    });

// Security Settings Provider
class SecuritySettingsNotifier extends AsyncNotifier<SecuritySettings> {
  @override
  Future<SecuritySettings> build() async {
    final local = ref.watch(settingsLocalDataSourceProvider);
    return local.readSecuritySettings();
  }

  Future<void> updateTwoFactorAuth(bool enabled) async {
    final current = await future;
    final updated = current.copyWith(hasTwoFactorAuth: enabled);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .saveSecuritySettings(updated);
    ref.invalidateSelf();
  }

  Future<void> updateBiometric(bool enabled) async {
    if (enabled && !await BiometricAuth().supportsFingerprint()) {
      throw StateError(
        'Fingerprint authentication is not available on this device.',
      );
    }
    final current = await future;
    final updated = current.copyWith(hasBiometricEnabled: enabled);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .saveSecuritySettings(updated);
    ref.invalidateSelf();
  }
}

final securitySettingsProvider =
    AsyncNotifierProvider<SecuritySettingsNotifier, SecuritySettings>(
      SecuritySettingsNotifier.new,
    );

// Backup Settings Provider
class BackupSettingsNotifier extends AsyncNotifier<BackupSettings> {
  @override
  Future<BackupSettings> build() async {
    final local = ref.watch(settingsLocalDataSourceProvider);
    return local.readBackupSettings();
  }

  Future<void> updateCloudSync(bool enabled) async {
    final current = await future;
    final updated = current.copyWith(cloudSyncEnabled: enabled);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .saveBackupSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> updateAutoBackup(bool enabled) async {
    final current = await future;
    final updated = current.copyWith(automaticBackupEnabled: enabled);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .saveBackupSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> updateBackupFrequency(String frequency) async {
    final current = await future;
    final updated = current.copyWith(backupFrequency: frequency);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .saveBackupSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> updateOfflineMode(bool enabled) async {
    final current = await future;
    final updated = current.copyWith(offlineModeEnabled: enabled);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .saveBackupSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> recordBackup(DateTime date) async {
    final current = await future;
    final updated = current.copyWith(lastBackupDate: date);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .saveBackupSettings(updated);
    state = AsyncData(updated);
  }
}

final backupSettingsProvider =
    AsyncNotifierProvider<BackupSettingsNotifier, BackupSettings>(
      BackupSettingsNotifier.new,
    );

// Payment Settings Provider
class PaymentSettingsNotifier extends AsyncNotifier<PaymentSettings> {
  @override
  Future<PaymentSettings> build() async {
    final local = ref.watch(settingsLocalDataSourceProvider);
    return local.readPaymentSettings();
  }

  Future<void> updateMPesaNumber(String? number) async {
    final current = await future;
    final updated = current.copyWith(mPesaNumber: number);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .savePaymentSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> updateBankAccount(String? account) async {
    final current = await future;
    final updated = current.copyWith(bankAccount: account);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .savePaymentSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> updateBankName(String? name) async {
    final current = await future;
    final updated = current.copyWith(bankName: name);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .savePaymentSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> updateTaxRate(double rate) async {
    final current = await future;
    final updated = current.copyWith(taxRate: rate);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .savePaymentSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> updateVAT(double vat) async {
    final current = await future;
    final updated = current.copyWith(vat: vat);
    await ref
        .watch(settingsLocalDataSourceProvider)
        .savePaymentSettings(updated);
    ref.invalidateSelf();
  }

  Future<void> save(PaymentSettings updated) async {
    await ref
        .watch(settingsLocalDataSourceProvider)
        .savePaymentSettings(updated);
    state = AsyncData(updated);
  }
}

final paymentSettingsProvider =
    AsyncNotifierProvider<PaymentSettingsNotifier, PaymentSettings>(
      PaymentSettingsNotifier.new,
    );

class DeviceSettingsNotifier extends AsyncNotifier<DeviceSettings> {
  @override
  Future<DeviceSettings> build() =>
      ref.watch(settingsLocalDataSourceProvider).readDeviceSettings();

  Future<void> save(DeviceSettings updated) async {
    await ref
        .watch(settingsLocalDataSourceProvider)
        .saveDeviceSettings(updated);
    state = AsyncData(updated);
  }
}

final deviceSettingsProvider =
    AsyncNotifierProvider<DeviceSettingsNotifier, DeviceSettings>(
      DeviceSettingsNotifier.new,
    );

// Theme Provider (for theme switching at app level)
final appThemeProvider = StateProvider<bool>((ref) {
  return ref.watch(userPreferencesProvider).valueOrNull?.isDarkMode ?? false;
});

// The saved preference is authoritative after loading. During first-run
// onboarding, use its selected language until preferences have loaded.
final appLanguageProvider = Provider<String>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  final savedLanguage = preferences.valueOrNull?.language;
  if (savedLanguage == 'en' || savedLanguage == 'sw') return savedLanguage!;
  if (preferences.isLoading) {
    final onboardingLanguage = ref.watch(onboardingProvider).languageCode;
    if (onboardingLanguage == 'en' || onboardingLanguage == 'sw') {
      return onboardingLanguage;
    }
  }
  return 'en';
});

// Helper to get display text for settings options
class SettingsHelper {
  static String getLanguageName(String code) {
    return const {'en': 'English', 'sw': 'Kiswahili'}[code] ?? code;
  }

  static String getWeightUnitName(String unit) {
    return const {'kg': 'Kilograms (kg)', 'lb': 'Pounds (lb)'}[unit] ?? unit;
  }

  static String getCurrencyName(String code) {
    return const {
          'KES': 'Kenyan Shilling (KES)',
          'USD': 'US Dollar (USD)',
        }[code] ??
        code;
  }

  static String getDateFormatName(String format) {
    return const {
          'dd/MM/yyyy': 'DD/MM/YYYY',
          'MM/dd/yyyy': 'MM/DD/YYYY',
          'yyyy-MM-dd': 'YYYY-MM-DD',
        }[format] ??
        format;
  }

  static String getNotificationName(String type) {
    return const {
          'vaccinations': 'Vaccination Reminders',
          'feeding': 'Feeding Reminders',
          'breeding': 'Insemination Alerts',
          'lowStock': 'Low Stock Alerts',
          'sales': 'Sales Notifications',
          'payments': 'Payment Notifications',
        }[type] ??
        type;
  }

  static String getBackupFrequencyName(String frequency) {
    return const {
          'daily': 'Daily',
          'weekly': 'Weekly',
          'monthly': 'Monthly',
        }[frequency] ??
        frequency;
  }

  static String getDeviceTypeName(String type) {
    return const {
          'weighingScale': 'Weighing Scale',
          'gpsTracker': 'GPS Tracker',
          'camera': 'Camera',
        }[type] ??
        type;
  }

  static IconData getDeviceTypeIcon(String type) {
    return const {
          'weighingScale': Icons.scale,
          'gpsTracker': Icons.location_on,
          'camera': Icons.camera_alt,
        }[type] ??
        Icons.devices;
  }
}
