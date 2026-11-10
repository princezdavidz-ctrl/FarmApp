abstract final class ApiConfig {
  // Override per environment with --dart-define=API_BASE_URL=...
  static const productionBaseUrl = 'https://api.example.invalid/api/v1';

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    return configured.isNotEmpty ? configured : productionBaseUrl;
  }

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 15);
}
