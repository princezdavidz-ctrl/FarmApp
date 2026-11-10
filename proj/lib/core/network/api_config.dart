import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  // Set this for every deployed build with --dart-define=API_BASE_URL=https://<host>/api/v1.
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL is required for release builds. Pass '
        '--dart-define=API_BASE_URL=https://<your-api-host>/api/v1.',
      );
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://localhost:8000/api/v1';
  }

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 15);
}
