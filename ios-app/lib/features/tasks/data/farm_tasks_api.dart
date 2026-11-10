import 'package:dio/dio.dart';

import '../../../../core/errors/error_handler.dart';
import 'farm_task.dart';

class FarmTasksApi {
  FarmTasksApi(this._dio);

  final Dio _dio;

  Future<List<FarmTask>> fetch(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/tasks',
      );
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows
          .map((row) => FarmTask.fromJson(row as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> create(
    String farmId, {
    required String title,
    required String priority,
    required String category,
    String? notes,
    String? assignedTo,
    DateTime? dueAt,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/tasks',
        data: {
          'title': title,
          'priority': priority,
          'category': category,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (assignedTo != null) 'assigned_to': int.tryParse(assignedTo),
          if (dueAt != null) 'due_at': dueAt.toIso8601String(),
        },
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> update(
    String farmId,
    String taskId,
    Map<String, dynamic> values,
  ) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/tasks/$taskId',
        data: values,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> delete(String farmId, String taskId) async {
    try {
      await _dio.delete<void>('/farms/$farmId/tasks/$taskId');
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
