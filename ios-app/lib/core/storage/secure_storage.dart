import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user-configurable API server address so the app can be pointed
/// at a different network (LAN IP, tunnel, or public domain) without a rebuild.
abstract final class ServerAddressStorage {
  static const _key = 'api_server_base_url';
  static const _storage = FlutterSecureStorage();

  static Future<String?> read() => _storage.read(key: _key);

  static Future<void> write(String? baseUrl) async {
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      await _storage.delete(key: _key);
      return;
    }
    await _storage.write(key: _key, value: baseUrl.trim());
  }
}
