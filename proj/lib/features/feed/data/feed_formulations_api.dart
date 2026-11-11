import 'package:dio/dio.dart';

import '../../../core/errors/error_handler.dart';

class FeedFormulationsApi {
  FeedFormulationsApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetch(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/feed/formulations',
      );
      final rows = response.data?['data'];
      if (rows is! List) return const [];
      return rows.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> create(String farmId, Map<String, dynamic> data) async {
    try {
      await _dio.post('/farms/$farmId/feed/formulations', data: data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> delete(String farmId, String id) async {
    try {
      await _dio.delete('/farms/$farmId/feed/formulations/$id');
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
