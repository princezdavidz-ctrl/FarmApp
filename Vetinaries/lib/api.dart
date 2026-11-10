import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class VetApi {
  VetApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      );

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

  final Dio _dio;
  void setAccessToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Map<String, dynamic>> apply(Map<String, dynamic> data) =>
      _post('/veterinary-applications', data);

  Future<Map<String, dynamic>> applicationStatus(String reference) =>
      _get('/veterinary-applications/$reference');

  Future<Map<String, dynamic>> login(String identifier, String password) =>
      _post('/auth/login', {
        'identifier': identifier,
        'password': password,
        'remember_me': true,
      });

  Future<Map<String, dynamic>> verifyLoginOtp(
    String challengeId,
    String code,
  ) => _post('/auth/verify-otp', {'challenge_id': challengeId, 'code': code});

  Future<Map<String, dynamic>> refresh(String refreshToken) =>
      _post('/auth/refresh', {'refresh_token': refreshToken});

  Future<Map<String, dynamic>> veterinarianProfile() =>
      _get('/veterinarians/me');

  Future<List<Map<String, dynamic>>> subscriptionPlans() async {
    final response = await _get('/veterinary-subscription-plans');
    return _mapList(response['data']);
  }

  Future<Map<String, dynamic>> requestPayment({
    required String plan,
    String? phone,
  }) => _post('/veterinarians/subscription/payment', {
    'plan': plan,
    if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
  });

  Future<Map<String, dynamic>> payment(String id) =>
      _get('/veterinarians/payments/$id');

  Future<Map<String, dynamic>> transportRequests() =>
      _get('/veterinarians/requests');

  Future<Map<String, dynamic>> acceptTransportRequest(String id) =>
      _post('/veterinarians/requests/$id/accept', const {});

  Future<Map<String, dynamic>> updateTransportRequestStatus(
    String id,
    String status,
  ) => _post('/veterinary-requests/$id/status', {'status': status});

  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException catch (error) {
      throw _messageFor(error);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _messageFor(error);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _messageFor(error);
    }
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
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
