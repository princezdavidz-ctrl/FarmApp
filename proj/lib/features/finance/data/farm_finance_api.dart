import 'package:dio/dio.dart';

import 'package:proj/core/errors/error_handler.dart';

class FarmFinanceTotals {
  const FarmFinanceTotals({
    required this.currency,
    required this.income,
    required this.expenses,
    required this.profit,
  });

  final String currency;
  final double income;
  final double expenses;
  final double profit;

  factory FarmFinanceTotals.fromJson(Map<String, dynamic> json) =>
      FarmFinanceTotals(
        currency: '${json['currency'] ?? 'KES'}',
        income: (json['income'] as num?)?.toDouble() ?? 0,
        expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
        profit: (json['profit'] as num?)?.toDouble() ?? 0,
      );
}

class FarmFinanceTransaction {
  const FarmFinanceTransaction({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.currency,
    required this.occurredAt,
  });

  final String id;
  final String type;
  final String category;
  final String description;
  final double amount;
  final String currency;
  final DateTime occurredAt;

  factory FarmFinanceTransaction.fromJson(Map<String, dynamic> json) =>
      FarmFinanceTransaction(
        id: '${json['id']}',
        type: '${json['type']}',
        category: '${json['category'] ?? ''}',
        description: '${json['description'] ?? ''}',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: '${json['currency'] ?? 'KES'}',
        occurredAt:
            DateTime.tryParse('${json['occurred_at'] ?? ''}') ?? DateTime.now(),
      );
}

class FarmFinanceState {
  const FarmFinanceState({
    this.totals = const [],
    this.transactions = const [],
  });

  final List<FarmFinanceTotals> totals;
  final List<FarmFinanceTransaction> transactions;

  factory FarmFinanceState.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    return FarmFinanceState(
      totals: (summary['totals'] as List<dynamic>? ?? const [])
          .map((row) => FarmFinanceTotals.fromJson(row as Map<String, dynamic>))
          .toList(),
      transactions: (json['data'] as List<dynamic>? ?? const [])
          .map(
            (row) =>
                FarmFinanceTransaction.fromJson(row as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class FarmFinanceApi {
  FarmFinanceApi(this._dio);

  final Dio _dio;

  Future<FarmFinanceState> fetch(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/finance',
      );
      return FarmFinanceState.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> create(
    String farmId, {
    required String type,
    required String category,
    required String description,
    required double amount,
    required String currency,
    required DateTime occurredAt,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/finance',
        data: {
          'type': type,
          'category': category,
          'description': description,
          'amount': amount,
          'currency': currency,
          'occurred_at': occurredAt.toIso8601String().split('T').first,
        },
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
