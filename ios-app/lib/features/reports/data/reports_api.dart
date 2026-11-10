import 'package:dio/dio.dart';
import 'package:proj/core/errors/error_handler.dart';
import 'package:proj/features/reports/domain/entities/animal_report.dart';
import 'package:proj/features/reports/domain/entities/report_metrics.dart';

/// API client for reports and analytics
class ReportsApi {
  ReportsApi(this._dio);

  final Dio _dio;

  // Get metrics for a date range
  Future<ReportMetrics> getMetrics(
    String farmId, {
    required String
    dateRange, // 'today', 'week', 'month', 'year', or ISO date range
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'dateRange': dateRange,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };
      final response = await _dio.get(
        '/farms/$farmId/reports/metrics',
        queryParameters: params,
      );
      return ReportMetrics.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  Future<AnimalReport> getAnimalReport(
    String farmId,
    String animalId, {
    required String dateRange,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'dateRange': dateRange,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/animals/$animalId/report',
        queryParameters: params,
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const FormatException('Missing animal report data.');
      }
      return AnimalReport.fromJson(data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
