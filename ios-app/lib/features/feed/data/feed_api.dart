import 'package:dio/dio.dart';

import '../../../core/errors/error_handler.dart';

class FeedStock {
  const FeedStock({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.unitCost,
    this.location,
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final double? unitCost;
  final String? location;

  factory FeedStock.fromJson(Map<String, dynamic> json) => FeedStock(
    id: '${json['id']}',
    name: '${json['name'] ?? ''}',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unit: '${json['unit'] ?? 'bags'}',
    unitCost: (json['unit_cost'] as num?)?.toDouble(),
    location: json['location'] as String?,
  );
}

class FeedUsage {
  const FeedUsage({
    required this.id,
    required this.quantity,
    required this.unit,
    required this.usedAt,
    this.feedName,
    this.notes,
  });

  final String id;
  final double quantity;
  final String unit;
  final DateTime usedAt;
  final String? feedName;
  final String? notes;

  factory FeedUsage.fromJson(Map<String, dynamic> json) => FeedUsage(
    id: '${json['id']}',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unit: '${json['unit'] ?? 'bags'}',
    usedAt: DateTime.tryParse('${json['used_at']}') ?? DateTime.now(),
    feedName: json['feed_name'] as String?,
    notes: json['notes'] as String?,
  );
}

class FeedSnapshot {
  const FeedSnapshot({
    required this.stock,
    required this.usage,
    this.monthlyFeedCost = 0,
    this.hasMonthlyFeedCost = false,
  });
  final List<FeedStock> stock;
  final List<FeedUsage> usage;
  final double monthlyFeedCost;
  final bool hasMonthlyFeedCost;
  double get totalQuantity =>
      stock.fold(0, (total, item) => total + item.quantity);
}

class FeedApi {
  FeedApi(this._dio);
  final Dio _dio;

  Future<FeedSnapshot> fetch(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/feed',
      );
      final body = response.data ?? {};
      return FeedSnapshot(
        stock: _list(body['stock']).map(FeedStock.fromJson).toList(),
        usage: _list(body['usage']).map(FeedUsage.fromJson).toList(),
        monthlyFeedCost: (body['monthly_feed_cost'] as num?)?.toDouble() ?? 0,
        hasMonthlyFeedCost: body['has_monthly_feed_cost'] == true,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<FeedStock> addStock({
    required String farmId,
    required String name,
    required double quantity,
    required String unit,
    double? unitCost,
    String? location,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/feed/stock',
        data: {
          'name': name,
          'quantity': quantity,
          'unit': unit,
          if (unitCost != null) 'unit_cost': unitCost,
          if (location != null && location.trim().isNotEmpty)
            'location': location.trim(),
        },
      );
      return FeedStock.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<FeedUsage> recordUsage({
    required String farmId,
    String? stockId,
    required double quantity,
    required String unit,
    required DateTime usedAt,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/feed/usage',
        data: {
          if (stockId != null) 'feed_stock_id': int.tryParse(stockId),
          'quantity': quantity,
          'unit': unit,
          'used_at': usedAt.toIso8601String(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      return FeedUsage.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  static List<Map<String, dynamic>> _list(Object? value) =>
      (value as List<dynamic>? ?? [])
          .map(
            (item) => item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item as Map),
          )
          .toList();
}
