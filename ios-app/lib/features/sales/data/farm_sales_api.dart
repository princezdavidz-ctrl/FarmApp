import 'package:dio/dio.dart';

import '../../../../core/errors/error_handler.dart';
import 'farm_buyer.dart';
import 'farm_sale.dart';

class FarmSalesApi {
  FarmSalesApi(this._dio);
  final Dio _dio;

  Future<List<FarmBuyer>> fetchBuyers(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/buyers',
      );
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows
          .map((row) => FarmBuyer.fromJson(row as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<List<FarmSale>> fetchSales(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/sales',
      );
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows
          .map((row) => FarmSale.fromJson(row as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> createBuyer(String farmId, Map<String, dynamic> data) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/buyers',
        data: data,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> updateBuyer(
    String farmId,
    String buyerId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/buyers/$buyerId',
        data: data,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> createSale(String farmId, Map<String, dynamic> data) async {
    try {
      await _dio.post<Map<String, dynamic>>('/farms/$farmId/sales', data: data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> updateSale(
    String farmId,
    String saleId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/sales/$saleId',
        data: data,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
