import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists whether the user has ever finished the onboarding flow, so it isn't repeated after logout/restart.
class OnboardingStorage {
  OnboardingStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _completedKey = 'onboarding.completed';

  final FlutterSecureStorage _storage;

  Future<bool> get completed async =>
      (await _storage.read(key: _completedKey)) == 'true';

  Future<void> markCompleted() =>
      _storage.write(key: _completedKey, value: 'true');
}
