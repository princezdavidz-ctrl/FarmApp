import 'api_config.dart';
import 'environment.dart';

class AppConfig {
	const AppConfig({this.environment = Environment.development});

	final Environment environment;

	String get apiBaseUrl => ApiConfig.baseUrl(environment);
	bool get isProduction => environment == Environment.production;
	bool get isDevelopment => environment == Environment.development;
	bool get isStaging => environment == Environment.staging;
}
