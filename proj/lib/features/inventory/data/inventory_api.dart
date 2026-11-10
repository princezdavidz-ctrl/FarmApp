import 'package:dio/dio.dart';
import 'package:proj/core/errors/error_handler.dart';
import 'package:proj/features/inventory/domain/entities/inventory_item.dart';
import 'package:proj/features/inventory/domain/entities/stock_movement.dart';

/// API client for inventory operations
class InventoryApi {
  InventoryApi(this._dio);

  final Dio _dio;

  /// Fetch all inventory items for a farm with pagination and summary
  Future<Map<String, dynamic>> fetchItems(String farmId, {int page = 1}) async {
    try {
      final response = await _dio.get(
        '/farms/$farmId/inventory/items',
        queryParameters: {'page': page, 'per_page': 50},
      );
      final data = response.data as Map<String, dynamic>;

      return {
        'items': (data['items'] as List<dynamic>)
            .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        'pagination': data['pagination'],
        'summary': data['summary'],
      };
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  /// Fetch a single inventory item with its movements
  Future<Map<String, dynamic>> fetchItem(String farmId, String itemId) async {
    try {
      final response = await _dio.get('/farms/$farmId/inventory/items/$itemId');
      final data = response.data as Map<String, dynamic>;

      return {
        'item': InventoryItem.fromJson(data['data'] as Map<String, dynamic>),
        'movements': (data['movements'] as List<dynamic>)
            .map((m) => StockMovement.fromJson(m as Map<String, dynamic>))
            .toList(),
      };
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  /// Create a new inventory item
  Future<InventoryItem> createItem(
    String farmId, {
    required String name,
    required String category,
    required String sku,
    required double quantity,
    required String unit,
    required double minimumLevel,
    required double costPrice,
    String? supplier,
    DateTime? expiryDate,
    String? storageLocation,
    String? barcode,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'category': category,
        'sku': sku,
        'quantity': quantity,
        'unit': unit,
        'minimum_level': minimumLevel,
        'cost_price': costPrice,
        ...supplier == null ? const {} : {'supplier': supplier},
        ...expiryDate == null
            ? const {}
            : {'expiry_date': expiryDate.toIso8601String().split('T')[0]},
        ...storageLocation == null ? const {} : {'storage_location': storageLocation},
        ...barcode == null ? const {} : {'barcode': barcode},
        ...notes == null ? const {} : {'notes': notes},
      };

      final response = await _dio.post(
        '/farms/$farmId/inventory/items',
        data: data,
      );
      return InventoryItem.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  /// Update an inventory item
  Future<InventoryItem> updateItem(
    String farmId,
    String itemId, {
    String? name,
    String? category,
    String? sku,
    double? quantity,
    String? unit,
    double? minimumLevel,
    double? costPrice,
    String? supplier,
    DateTime? expiryDate,
    String? storageLocation,
    String? barcode,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{
        ...name == null ? const {} : {'name': name},
        ...category == null ? const {} : {'category': category},
        ...sku == null ? const {} : {'sku': sku},
        ...quantity == null ? const {} : {'quantity': quantity},
        ...unit == null ? const {} : {'unit': unit},
        ...minimumLevel == null ? const {} : {'minimum_level': minimumLevel},
        ...costPrice == null ? const {} : {'cost_price': costPrice},
        ...supplier == null ? const {} : {'supplier': supplier},
        ...expiryDate == null
            ? const {}
            : {'expiry_date': expiryDate.toIso8601String().split('T')[0]},
        ...storageLocation == null
            ? const {}
            : {'storage_location': storageLocation},
        ...barcode == null ? const {} : {'barcode': barcode},
        ...notes == null ? const {} : {'notes': notes},
      };

      final response = await _dio.patch(
        '/farms/$farmId/inventory/items/$itemId',
        data: data,
      );
      return InventoryItem.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  /// Delete an inventory item
  Future<void> deleteItem(String farmId, String itemId) async {
    try {
      await _dio.delete('/farms/$farmId/inventory/items/$itemId');
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  /// Record a stock movement (in, out, adjustment, expired)
  Future<StockMovement> recordMovement(
    String farmId,
    String itemId, {
    required String type,
    required double quantity,
    String? reference,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type,
        'quantity': quantity,
        ...reference == null ? const {} : {'reference': reference},
        ...notes == null ? const {} : {'notes': notes},
      };

      final response = await _dio.post(
        '/farms/$farmId/inventory/items/$itemId/movements',
        data: data,
      );
      return StockMovement.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  /// Fetch movements for an item with pagination
  Future<Map<String, dynamic>> fetchMovements(
    String farmId,
    String itemId, {
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/farms/$farmId/inventory/items/$itemId/movements',
        queryParameters: {'page': page, 'per_page': 50},
      );
      final data = response.data as Map<String, dynamic>;

      return {
        'movements': (data['data'] as List<dynamic>)
            .map((m) => StockMovement.fromJson(m as Map<String, dynamic>))
            .toList(),
        'pagination': data['pagination'],
      };
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  /// Fetch inventory alerts (low stock, expiring, expired)
  Future<Map<String, dynamic>> fetchAlerts(String farmId) async {
    try {
      final response = await _dio.get('/farms/$farmId/inventory/alerts');
      final data = response.data as Map<String, dynamic>;

      return {
        'lowStock': (data['lowStock'] as List<dynamic>)
            .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        'expiring': (data['expiring'] as List<dynamic>)
            .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        'expired': (data['expired'] as List<dynamic>)
            .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      };
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }

  /// Fetch items by category
  Future<Map<String, dynamic>> fetchByCategory(
    String farmId,
    String category,
  ) async {
    try {
      final response = await _dio.get(
        '/farms/$farmId/inventory/by-category',
        queryParameters: {'category': category},
      );
      final data = response.data as Map<String, dynamic>;

      return {
        'category': data['category'],
        'items': (data['items'] as List<dynamic>)
            .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        'count': data['count'],
      };
    } on DioException catch (e) {
      throw ErrorHandler.from(e);
    }
  }
}
