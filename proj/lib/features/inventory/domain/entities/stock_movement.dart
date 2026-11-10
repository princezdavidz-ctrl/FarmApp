/// Represents a stock movement transaction (in, out, damaged, returned, transfer)
class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.movementType, // 'in', 'out', 'damaged', 'returned', 'transfer'
    required this.quantity,
    required this.unit,
    required this.reference, // Invoice number, reference ID, etc.
    required this.notes,
    required this.fromLocation,
    required this.toLocation,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String itemId;
  final String itemName;
  final String movementType;
  final double quantity;
  final String unit;
  final String? reference;
  final String? notes;
  final String? fromLocation;
  final String? toLocation;
  final String createdBy;
  final DateTime createdAt;

  /// Get movement type label
  String get movementLabel {
    switch (movementType) {
      case 'in':
        return 'Stock In';
      case 'out':
        return 'Stock Out';
      case 'damaged':
        return 'Damaged';
      case 'returned':
        return 'Returned';
      case 'transfer':
        return 'Transfer';
      default:
        return movementType;
    }
  }

  /// Get movement type icon
  String get movementIcon {
    switch (movementType) {
      case 'in':
        return 'arrow_downward';
      case 'out':
        return 'arrow_upward';
      case 'damaged':
        return 'error_outline';
      case 'returned':
        return 'undo';
      case 'transfer':
        return 'swap_horiz';
      default:
        return 'info';
    }
  }

  StockMovement copyWith({
    String? id,
    String? itemId,
    String? itemName,
    String? movementType,
    double? quantity,
    String? unit,
    String? reference,
    String? notes,
    String? fromLocation,
    String? toLocation,
    String? createdBy,
    DateTime? createdAt,
  }) => StockMovement(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    itemName: itemName ?? this.itemName,
    movementType: movementType ?? this.movementType,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    reference: reference ?? this.reference,
    notes: notes ?? this.notes,
    fromLocation: fromLocation ?? this.fromLocation,
    toLocation: toLocation ?? this.toLocation,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'itemName': itemName,
    'movementType': movementType,
    'quantity': quantity,
    'unit': unit,
    'reference': reference,
    'notes': notes,
    'fromLocation': fromLocation,
    'toLocation': toLocation,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
    id: json['id'] as String,
    itemId: json['itemId'] as String,
    itemName: json['itemName'] as String,
    movementType: json['movementType'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'] as String,
    reference: json['reference'] as String?,
    notes: json['notes'] as String?,
    fromLocation: json['fromLocation'] as String?,
    toLocation: json['toLocation'] as String?,
    createdBy: json['createdBy'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  factory StockMovement.defaults() => StockMovement(
    id: '',
    itemId: '',
    itemName: '',
    movementType: 'in',
    quantity: 0,
    unit: 'kg',
    reference: null,
    notes: null,
    fromLocation: null,
    toLocation: null,
    createdBy: '',
    createdAt: DateTime.now(),
  );
}
