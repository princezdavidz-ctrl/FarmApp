import 'package:dio/dio.dart';
import '../../../../core/errors/error_handler.dart';
import '../domain/entities/growth_record.dart';

class GrowthApi {
  final Dio _dio;

  GrowthApi(this._dio);

  Future<List<GrowthRecord>> fetchGrowthRecords(String farmId) async {
    try {
      final response = await _dio.get('/farms/$farmId/growth-records');
      final data = response.data as Map<String, dynamic>;
      final records =
          (data['data'] as List?)
              ?.map((e) => GrowthRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return records;
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  Future<List<GrowthRecord>> fetchRecentMeasurements(String farmId) async {
    try {
      final response = await _dio.get('/farms/$farmId/growth-records?limit=50');
      final data = response.data as Map<String, dynamic>;
      final records =
          (data['data'] as List?)
              ?.map((e) => GrowthRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return records;
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  Future<Map<String, dynamic>> fetchGrowthOverview(String farmId) async {
    try {
      final response = await _dio.get('/farms/$farmId/growth-overview');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  Future<Map<String, dynamic>> fetchGrowthAnalytics(
    String farmId, {
    String period = '30days', // 7days, 30days, 90days, 1year
  }) async {
    try {
      final response = await _dio.get(
        '/farms/$farmId/growth-analytics?period=$period',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  Future<GrowthRecord> addGrowthRecord(
    String farmId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/farms/$farmId/growth-records',
        data: data,
      );
      final recordData = response.data as Map<String, dynamic>;
      return GrowthRecord.fromJson(recordData['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  Future<GrowthRecord> updateGrowthRecord(
    String farmId,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(
        '/farms/$farmId/growth-records/$recordId',
        data: data,
      );
      final recordData = response.data as Map<String, dynamic>;
      return GrowthRecord.fromJson(recordData['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  Future<void> deleteGrowthRecord(String farmId, String recordId) async {
    try {
      await _dio.delete('/farms/$farmId/growth-records/$recordId');
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }
}
