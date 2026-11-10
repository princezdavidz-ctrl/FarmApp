import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinAuth {
  PinAuth({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static const _pinKey = 'auth.pin';
  final FlutterSecureStorage _storage;

  Future<bool> get hasPin async => (await _storage.read(key: _pinKey)) != null;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', 'PIN must contain four digits.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = sha256.convert([...salt, ...utf8.encode(pin)]);
    await _storage.write(key: _pinKey, value: '${base64UrlEncode(salt)}:$hash');
  }

  Future<bool> verify(String pin) async {
    final saved = await _storage.read(key: _pinKey);
    if (saved == null) return false;
    final parts = saved.split(':');
    if (parts.length != 2) return false;
    final salt = base64Url.decode(base64Url.normalize(parts.first));
    return sha256.convert([...salt, ...utf8.encode(pin)]).toString() ==
        parts.last;
  }

  Future<void> clear() => _storage.delete(key: _pinKey);
}
