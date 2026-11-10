import 'environment.dart';

abstract final class ApiConfig {
  static const developmentBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const stagingBaseUrl = String.fromEnvironment(\n    'API_BASE_URL',\n    defaultValue: developmentBaseUrl,\n  );
  static const productionBaseUrl = String.fromEnvironment(\n    'API_BASE_URL',\n    defaultValue: developmentBaseUrl,\n  );

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
