import 'package:dio/dio.dart';

class SupplierApi {
  SupplierApi()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      );

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.invalid/api/v1',
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
      _post('/animal-supplier-applications', data);

  Future<Map<String, dynamic>> applicationStatus(String reference) =>
      _get('/animal-supplier-applications/$reference');

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

  Future<Map<String, dynamic>> supplierProfile() =>
      _get('/animal-suppliers/me');

  Future<List<Map<String, dynamic>>> subscriptionPlans() async {
    final response = await _get('/animal-supplier-subscription-plans');
    return _mapList(response['data']);
  }

  Future<Map<String, dynamic>> requestPayment({
    required String plan,
    String? phone,
  }) => _post('/animal-suppliers/subscription/payment', {
    'plan': plan,
    if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
  });

  Future<Map<String, dynamic>> payment(String id) =>
      _get('/animal-suppliers/payments/$id');

  Future<List<Map<String, dynamic>>> products() async {
    final response = await _get('/animal-suppliers/products');
    return _mapList(response['data']);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) =>
      _post('/animal-suppliers/products', data);

  Future<Map<String, dynamic>> updateProduct(
    String id,
    Map<String, dynamic> data,
  ) => _patch('/animal-suppliers/products/$id', data);

  Future<List<Map<String, dynamic>>> transportRequests() async {
    final response = await _get('/animal-suppliers/transport-requests');
    return _mapList(response['data']);
  }

  Future<Map<String, dynamic>> createTransportRequest(
    Map<String, dynamic> data,
  ) => _post('/animal-suppliers/transport-requests', data);

  Future<Map<String, dynamic>> updateTransportRequestStatus(
    String id,
    String status,
  ) => _post('/transport-requests/$id/status', {'status': status});

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

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(path, data: data);
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
