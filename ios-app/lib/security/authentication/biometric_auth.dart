import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  BiometricAuth({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> isAvailable() async =>
      await _localAuth.canCheckBiometrics &&
      await _localAuth.isDeviceSupported();

  Future<bool> supportsFingerprint() async =>
      (await _localAuth.getAvailableBiometrics()).contains(
        BiometricType.fingerprint,
      );

  Future<bool> authenticate() => _localAuth.authenticate(
    localizedReason: 'Authenticate to access Farm App',
  );
}
