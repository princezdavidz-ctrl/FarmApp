import 'package:dio/dio.dart';
import '../domain/entities/health_record.dart';
import '../../../../core/errors/error_handler.dart';

class HealthApi {
  HealthApi(this._dio);

  final Dio _dio;

  Future<List<HealthRecord>> fetchHealthRecords(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/health-records',
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      return data
          .map((item) => HealthRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<List<HealthRecord>> fetchVaccinationSchedule(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/health-records',
        queryParameters: {'type': 'vaccination', 'status': 'due'},
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      return data
          .map((item) => HealthRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<List<HealthRecord>> fetchTreatmentRecords(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/health-records',
        queryParameters: {'type': 'treatment'},
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      return data
          .map((item) => HealthRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<List<HealthRecord>> fetchHealthAlerts(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/health-alerts',
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      return data
          .map((item) => HealthRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Map<String, dynamic>> fetchHealthAnalytics(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/health-analytics',
      );
      return response.data ?? {};
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<HealthRecord> addHealthRecord(
    String farmId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/health-records',
        data: data,
      );
      final recordData = response.data?['data'] as Map<String, dynamic>? ?? {};
      return HealthRecord.fromJson(recordData);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<HealthRecord> updateHealthRecord(
    String farmId,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/health-records/$recordId',
        data: data,
      );
      final recordData = response.data?['data'] as Map<String, dynamic>? ?? {};
      return HealthRecord.fromJson(recordData);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> deleteHealthRecord(String farmId, String recordId) async {
    try {
      await _dio.delete('/farms/$farmId/health-records/$recordId');
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
