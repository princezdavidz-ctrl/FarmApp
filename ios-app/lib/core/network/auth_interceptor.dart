import 'package:dio/dio.dart';

import '../../security/authentication/auth_service.dart';
import 'api_config.dart';

/// Attaches the bearer access token to requests and transparently refreshes it once on a 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._authService,
    required this.onSessionExpired,
    required this.baseUrl,
  }) : _refreshDio = Dio(
         BaseOptions(
           connectTimeout: ApiConfig.connectTimeout,
           receiveTimeout: ApiConfig.receiveTimeout,
         ),
       );

  final AuthService _authService;
  final Dio _refreshDio;
  final Future<void> Function() onSessionExpired;
  final String Function() baseUrl;
  Future<String?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _authService.readAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (!isUnauthorized || alreadyRetried) return handler.next(err);

    final newAccessToken = await _refreshAccessToken();
    if (newAccessToken == null) {
      await onSessionExpired();
      return handler.next(err);
    }

    final retryOptions = err.requestOptions;
    retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
    retryOptions.extra['retried'] = true;
    try {
      handler.resolve(await _refreshDio.fetch<dynamic>(retryOptions));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  // Coalesces concurrent 401s (e.g. several in-flight requests) into a single refresh call.
  Future<String?> _refreshAccessToken() =>
      _refreshing ??= _performRefresh().whenComplete(() => _refreshing = null);

  Future<String?> _performRefresh() async {
    final refreshToken = await _authService.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      _refreshDio.options.baseUrl = baseUrl();
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final body = response.data!;
      final accessToken = body['access_token'] as String;
      final newRefreshToken = body['refresh_token'] as String;
      await _authService.saveTokenPair(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
      return accessToken;
    } on DioException {
      await _authService.clearSession();
      return null;
    }
  }
}
