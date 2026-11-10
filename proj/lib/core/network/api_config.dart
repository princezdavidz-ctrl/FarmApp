abstract final class ApiConfig {
  // Override per environment with --dart-define=API_BASE_URL=...
  static const productionBaseUrl = String.fromEnvironment(\n    'API_BASE_URL',\n    defaultValue: 'http://10.0.2.2:8000/api/v1',\n  );

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    return configured.isNotEmpty ? configured : productionBaseUrl;
  }

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 15);
}
