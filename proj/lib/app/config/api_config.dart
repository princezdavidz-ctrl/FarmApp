import 'environment.dart';

abstract final class ApiConfig {
  static const developmentBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const stagingBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: developmentBaseUrl,
  );
  static const productionBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: developmentBaseUrl,
  );

  static String baseUrl([Environment environment = Environment.development]) {
    switch (environment) {
      case Environment.development:
        return developmentBaseUrl;
      case Environment.staging:
        return stagingBaseUrl;
      case Environment.production:
        return productionBaseUrl;
    }
  }
}
