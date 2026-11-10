import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract final class ErrorHandler {
  static ApiException from(DioException error) {
    final data = error.response?.data;
    final statusCode = error.response?.statusCode;

    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return ApiException('${firstError.first}', statusCode: statusCode);
        }
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return ApiException(message, statusCode: statusCode);
      }
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(
        'The connection timed out. Check your network and try again.',
      ),
      DioExceptionType.connectionError => const ApiException(
        'Unable to reach the server. Check your connection.',
      ),
      _ => ApiException(
        error.message ?? 'Something went wrong. Please try again.',
        statusCode: statusCode,
      ),
    };
  }
}
