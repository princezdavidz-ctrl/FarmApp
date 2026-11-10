/// Represents financial and operational metrics for a specific time period
class ReportMetrics {
  const ReportMetrics({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.mortalityRate,
    required this.averageGrowth,
    required this.feedConsumption,
    required this.salesCount,
    required this.vaccinationCompletion,
    required this.startDate,
    required this.endDate,
  });

  final double totalRevenue;
  final double totalExpenses;
  final double mortalityRate; // Percentage
  final double averageGrowth; // Average weight gain in kg
  final double feedConsumption; // Total feed in kg
  final int salesCount;
  final double vaccinationCompletion; // Percentage
  final DateTime startDate;
  final DateTime endDate;

  /// Net profit = revenue - expenses
  double get netProfit => totalRevenue - totalExpenses;

  /// Profit margin = (profit / revenue) * 100
  double get profitMargin =>
      totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;

  ReportMetrics copyWith({
    double? totalRevenue,
    double? totalExpenses,
    double? mortalityRate,
    double? averageGrowth,
    double? feedConsumption,
    int? salesCount,
    double? vaccinationCompletion,
    DateTime? startDate,
    DateTime? endDate,
  }) => ReportMetrics(
    totalRevenue: totalRevenue ?? this.totalRevenue,
    totalExpenses: totalExpenses ?? this.totalExpenses,
    mortalityRate: mortalityRate ?? this.mortalityRate,
    averageGrowth: averageGrowth ?? this.averageGrowth,
    feedConsumption: feedConsumption ?? this.feedConsumption,
    salesCount: salesCount ?? this.salesCount,
    vaccinationCompletion: vaccinationCompletion ?? this.vaccinationCompletion,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );

  Map<String, dynamic> toJson() => {
    'totalRevenue': totalRevenue,
    'totalExpenses': totalExpenses,
    'mortalityRate': mortalityRate,
    'averageGrowth': averageGrowth,
    'feedConsumption': feedConsumption,
    'salesCount': salesCount,
    'vaccinationCompletion': vaccinationCompletion,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
  };

  factory ReportMetrics.fromJson(Map<String, dynamic> json) => ReportMetrics(
    totalRevenue: (json['totalRevenue'] as num).toDouble(),
    totalExpenses: (json['totalExpenses'] as num).toDouble(),
    mortalityRate: (json['mortalityRate'] as num).toDouble(),
    averageGrowth: (json['averageGrowth'] as num).toDouble(),
    feedConsumption: (json['feedConsumption'] as num).toDouble(),
    salesCount: json['salesCount'] as int,
    vaccinationCompletion: (json['vaccinationCompletion'] as num).toDouble(),
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
  );

  factory ReportMetrics.defaults() => ReportMetrics(
    totalRevenue: 0,
    totalExpenses: 0,
    mortalityRate: 0,
    averageGrowth: 0,
    feedConsumption: 0,
    salesCount: 0,
    vaccinationCompletion: 0,
    startDate: DateTime.now(),
    endDate: DateTime.now(),
  );
}

/// Represents a chart data point for analytics
class ChartDataPoint {
  const ChartDataPoint({required this.label, required this.value, this.color});

  final String label;
  final double value;
  final int? color;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'color': color,
  };

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) => ChartDataPoint(
    label: json['label'] as String,
    value: (json['value'] as num).toDouble(),
    color: json['color'] as int?,
  );
}

/// Report type enum
enum ReportType { financial, herd, health, feed, breeding, inventory }

extension ReportTypeExtension on ReportType {
  String get displayName {
    switch (this) {
      case ReportType.financial:
        return 'Financial Report';
      case ReportType.herd:
        return 'Herd Report';
      case ReportType.health:
        return 'Health Report';
      case ReportType.feed:
        return 'Feed Report';
      case ReportType.breeding:
        return 'Breeding Report';
      case ReportType.inventory:
        return 'Inventory Report';
    }
  }

  String get icon {
    switch (this) {
      case ReportType.financial:
        return 'attach_money';
      case ReportType.herd:
        return 'pets';
      case ReportType.health:
        return 'health_and_safety';
      case ReportType.feed:
        return 'fastfood';
      case ReportType.breeding:
        return 'favorite';
      case ReportType.inventory:
        return 'inventory_2';
    }
  }
}
