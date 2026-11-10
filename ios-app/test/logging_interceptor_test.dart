import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/core/network/logging_interceptor.dart';

void main() {
  test('refresh endpoint 422 is treated as expected session expiry noise', () {
    final exc = DioException(
      requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
        statusCode: 422,
      ),
    );

    expect(LoggingInterceptor.shouldLogError(exc), isFalse);
  });

  test('other API errors still log normally', () {
    final exc = DioException(
      requestOptions: RequestOptions(path: '/api/v1/users'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/users'),
        statusCode: 500,
      ),
    );

    expect(LoggingInterceptor.shouldLogError(exc), isTrue);
  });
}
