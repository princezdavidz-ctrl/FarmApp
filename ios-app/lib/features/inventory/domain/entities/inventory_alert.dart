/// Represents an inventory alert (low stock, expiring, expired, etc.)
class InventoryAlert {
  const InventoryAlert({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.alertType, // 'low_stock', 'expiring', 'expired', 'reorder'
    required this.severity, // 'info', 'warning', 'critical'
    required this.message,
    required this.isResolved,
    required this.createdAt,
    required this.resolvedAt,
  });

  final String id;
  final String itemId;
  final String itemName;
  final String alertType;
  final String severity; // 'info', 'warning', 'critical'
  final String message;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  /// Get alert type label
  String get alertLabel {
    switch (alertType) {
      case 'low_stock':
        return 'Low Stock';
      case 'expiring':
        return 'Expiring Soon';
      case 'expired':
        return 'Expired';
      case 'reorder':
        return 'Reorder';
      default:
        return alertType;
    }
  }

  /// Get alert icon
  String get alertIcon {
    switch (alertType) {
      case 'low_stock':
        return 'warning';
      case 'expiring':
        return 'access_time';
      case 'expired':
        return 'error';
      case 'reorder':
        return 'shopping_cart';
      default:
        return 'info';
    }
  }

  InventoryAlert copyWith({
    String? id,
    String? itemId,
    String? itemName,
    String? alertType,
    String? severity,
    String? message,
    bool? isResolved,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) => InventoryAlert(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    itemName: itemName ?? this.itemName,
    alertType: alertType ?? this.alertType,
    severity: severity ?? this.severity,
    message: message ?? this.message,
    isResolved: isResolved ?? this.isResolved,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'itemName': itemName,
    'alertType': alertType,
    'severity': severity,
    'message': message,
    'isResolved': isResolved,
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory InventoryAlert.fromJson(Map<String, dynamic> json) => InventoryAlert(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    itemName: json['itemName'] as String,
    alertType: json['alertType'] as String,
    severity: json['severity'] as String,
    message: json['message'] as String,
    isResolved: json['isResolved'] as bool,
    createdAt: DateTime.parse(json['createdAt'] as String),
    resolvedAt: json['resolvedAt'] != null
        ? DateTime.parse(json['resolvedAt'] as String)
        : null,
  );

  factory InventoryAlert.defaults() => InventoryAlert(
    id: '',
    itemId: '',
    itemName: '',
    alertType: 'low_stock',
    severity: 'info',
    message: '',
    isResolved: false,
    createdAt: DateTime.now(),
    resolvedAt: null,
  );
}
