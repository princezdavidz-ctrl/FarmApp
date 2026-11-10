import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DriverApi {
  static String get _baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
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

  DriverApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      );

  final Dio _dio;

  void setAccessToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Map<String, dynamic>> apply(Map<String, dynamic> data) =>
      _request(() => _dio.post('/animal-driver-applications', data: data));

  Future<Map<String, dynamic>> applicationStatus(String reference) =>
      _request(() => _dio.get('/animal-driver-applications/$reference'));

  Future<Map<String, dynamic>> login(String identifier, String password) =>
      _request(
        () => _dio.post(
          '/auth/login',
          data: {
            'identifier': identifier,
            'password': password,
            'remember_me': true,
          },
        ),
      );

  Future<Map<String, dynamic>> verifyOtp(String challengeId, String code) =>
      _request(
        () => _dio.post(
          '/auth/verify-otp',
          data: {'challenge_id': challengeId, 'code': code},
        ),
      );

  Future<Map<String, dynamic>> refresh(String refreshToken) => _request(
    () => _dio.post('/auth/refresh', data: {'refresh_token': refreshToken}),
  );

  Future<Map<String, dynamic>> profile() =>
      _request(() => _dio.get('/animal-drivers/me'));

  Future<List<Map<String, dynamic>>> plans() async {
    final response = await _request(
      () => _dio.get('/animal-driver-subscription-plans'),
    );
    return _asList(response['data']);
  }

  Future<Map<String, dynamic>> requestPayment(String plan, String phone) =>
      _request(
        () => _dio.post(
          '/animal-drivers/subscription/payment',
          data: {
            'plan': plan,
            if (phone.trim().isNotEmpty) 'phone': phone.trim(),
          },
        ),
      );

  Future<Map<String, dynamic>> payment(String id) =>
      _request(() => _dio.get('/animal-drivers/payments/$id'));

  Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    required bool available,
  }) => _request(
    () => _dio.post(
      '/animal-drivers/location',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'available': available,
      },
    ),
  );

  Future<Map<String, dynamic>> transportRequests() =>
      _request(() => _dio.get('/animal-drivers/requests'));

  Future<Map<String, dynamic>> acceptTransportRequest(String id) =>
      _request(() => _dio.post('/animal-drivers/requests/$id/accept'));

  Future<Map<String, dynamic>> updateTransportRequestStatus(
    String id,
    String status,
  ) => _request(
    () => _dio.post('/transport-requests/$id/status', data: {'status': status}),
  );

  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException catch (error) {
      throw _messageFor(error);
    }
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _messageFor(error);
    }
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry('$key', value));
    }).toList();
  }

  static String _messageFor(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      final errors = data['errors'];
      if (errors is Map) {
        for (final messages in errors.values) {
          if (messages is List && messages.isNotEmpty) {
            return messages.first.toString();
          }
        }
      }
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => 'The server took too long to respond.',
      DioExceptionType.connectionError =>
        'Could not reach the service. Check your internet connection.',
      _ => 'Request failed (${error.response?.statusCode ?? 'network error'}).',
    };
  }
}
