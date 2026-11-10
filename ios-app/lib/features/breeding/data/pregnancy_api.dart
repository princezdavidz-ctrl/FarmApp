import 'package:dio/dio.dart';

import '../../../core/errors/error_handler.dart';
import '../domain/entities/pregnancy.dart';
import 'models/pregnancy_model.dart';

class PregnancyApi {
  PregnancyApi(this._dio);
  final Dio _dio;

  Future<List<Pregnancy>> fetchPregnancies(
    String farmId, {
    String? status,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/pregnancies',
        queryParameters: status == null ? null : {'status': status},
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      return data
          .map((item) => PregnancyModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Pregnancy> createPregnancy({
    required String farmId,
    required String sowId,
    required DateTime matingDate,
    String? boarId,
    String? semenUsed,
    DateTime? confirmationDate,
    DateTime? expectedFarrowingDate,
    String status = 'suspected',
    int? expectedLitterSize,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{
        'sow_id': int.tryParse(sowId) ?? sowId,
        'mating_date': _date(matingDate),
        'status': status,
      };
      if (semenUsed != null && semenUsed.trim().isNotEmpty) {
        data['semen_used'] = semenUsed.trim();
      }
      if (boarId != null) data['boar_id'] = int.tryParse(boarId) ?? boarId;
      if (confirmationDate != null) {
        data['confirmation_date'] = _date(confirmationDate);
      }
      if (expectedFarrowingDate != null) {
        data['expected_farrowing_date'] = _date(expectedFarrowingDate);
      }
      if (expectedLitterSize != null) {
        data['expected_litter_size'] = expectedLitterSize;
      }
      if (notes != null && notes.trim().isNotEmpty) {
        data['notes'] = notes.trim();
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/pregnancies',
        data: data,
      );
      return PregnancyModel.fromJson(
        response.data?['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Pregnancy> updatePregnancy({
    required String farmId,
    required String pregnancyId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/pregnancies/$pregnancyId',
        data: data,
      );
      return PregnancyModel.fromJson(
        response.data?['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  static String _date(DateTime value) =>
      value.toIso8601String().split('T').first;
}
