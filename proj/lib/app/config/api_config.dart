import 'environment.dart';

abstract final class ApiConfig {
  static const developmentBaseUrl = String.fromEnvironment(
    'DEV_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  static const stagingBaseUrl = String.fromEnvironment('STAGING_API_BASE_URL');
  static const productionBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String baseUrl([Environment environment = Environment.development]) {
    switch (environment) {
      case Environment.development:
        return developmentBaseUrl;
      case Environment.staging:
        if (stagingBaseUrl.isEmpty) {
          throw StateError('Set STAGING_API_BASE_URL for staging builds.');
        }
        return stagingBaseUrl;
      case Environment.production:
        if (productionBaseUrl.isEmpty) {
          throw StateError('Set API_BASE_URL for production builds.');
        }
        return productionBaseUrl;
    }
  }
}
