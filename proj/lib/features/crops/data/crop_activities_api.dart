import 'package:dio/dio.dart';
import '../../../core/errors/error_handler.dart';

class CropActivitiesApi {
  CropActivitiesApi(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetch(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/farms/$farmId/crop-activities');
      final rows = response.data?['data'];
      if (rows is! List) return const [];
      return rows.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> create(String farmId, Map<String, dynamic> data) async {
    try {
      await _dio.post('/farms/$farmId/crop-activities', data: data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> update(String farmId, String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('/farms/$farmId/crop-activities/$id', data: data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> delete(String farmId, String id) async {
    try {
      await _dio.delete('/farms/$farmId/crop-activities/$id');
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
