import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:proj/features/reports/domain/entities/report_metrics.dart';

/// Local storage for report data and metrics
class ReportsLocalDataSource {
  ReportsLocalDataSource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _metricsKey = 'report_metrics';
  static const _lastUpdateKey = 'report_last_update';

  Future<ReportMetrics> readMetrics(String dateRange) async {
    try {
      final key = '${_metricsKey}_$dateRange';
      final json = await _storage.read(key: key);
      if (json == null) return ReportMetrics.defaults();
      return ReportMetrics.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return ReportMetrics.defaults();
    }
  }

  Future<void> saveMetrics(String dateRange, ReportMetrics metrics) async {
    try {
      final key = '${_metricsKey}_$dateRange';
      final json = jsonEncode(metrics.toJson());
      await _storage.write(key: key, value: json);
      await _storage.write(
        key: _lastUpdateKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Handle error silently
    }
  }

  Future<DateTime?> readLastUpdate() async {
    try {
      final value = await _storage.read(key: _lastUpdateKey);
      if (value == null) return null;
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAllMetrics() async {
    try {
      await _storage.delete(key: _metricsKey);
      await _storage.delete(key: _lastUpdateKey);
    } catch (_) {
      // Handle error silently
    }
  }
}
