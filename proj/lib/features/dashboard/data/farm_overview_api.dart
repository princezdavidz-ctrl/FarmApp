import 'package:dio/dio.dart';

import '../../../core/errors/error_handler.dart';

class FarmOverviewApi {
  FarmOverviewApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> fetch(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/overview',
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
