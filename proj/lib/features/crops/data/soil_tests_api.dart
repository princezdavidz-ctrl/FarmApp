import 'package:dio/dio.dart';

import '../../../core/errors/error_handler.dart';

class SoilTestsApi {
  SoilTestsApi(this._dio);
  final Dio _dio;

  String _path(String farmId, String plotId) =>
      '/farms/$farmId/crop-plots/$plotId/soil-tests';

  Future<List<Map<String, dynamic>>> fetch(String farmId, String plotId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_path(farmId, plotId));
      final rows = response.data?['data'];
      if (rows is! List) return const [];
      return rows.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> create(String farmId, String plotId, Map<String, dynamic> data) async {
    try {
      await _dio.post(_path(farmId, plotId), data: data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> update(String farmId, String plotId, String id, Map<String, dynamic> data) async {
    try {
      await _dio.patch('${_path(farmId, plotId)}/$id', data: data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> delete(String farmId, String plotId, String id) async {
    try {
      await _dio.delete('${_path(farmId, plotId)}/$id');
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
