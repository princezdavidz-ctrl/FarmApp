/// Represents an inventory item (feed, medicine, vaccine, equipment, etc.)
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.sku,
    required this.quantity,
    required this.unit, // 'kg', 'bottles', 'pieces', 'liters', etc.
    required this.minimumLevel,
    required this.supplier,
    required this.costPrice,
    required this.expiryDate,
    required this.storageLocation,
    required this.barcode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String sku;
  final double quantity;
  final String unit;
  final double minimumLevel;
  final String supplier;
  final double costPrice;
  final DateTime? expiryDate;
  final String storageLocation;
  final String? barcode;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns true if stock is below minimum level
  bool get isLowStock => quantity < minimumLevel;

  /// Returns true if item has expired
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Returns true if item is expiring within 30 days
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry > 0 && daysUntilExpiry <= 30;
  }

  /// Inventory value in KES
  double get totalValue => quantity * costPrice;

  /// Stock status: 'Low Stock', 'Expiring Soon', 'Expired', 'Good'
  String get stockStatus {
    if (isExpired) return 'Expired';
    if (isExpiringSoon) return 'Expiring Soon';
    if (isLowStock) return 'Low Stock';
    return 'Good';
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    String? sku,
    double? quantity,
    String? unit,
    double? minimumLevel,
    String? supplier,
    double? costPrice,
    DateTime? expiryDate,
    String? storageLocation,
    String? barcode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InventoryItem(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    sku: sku ?? this.sku,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    minimumLevel: minimumLevel ?? this.minimumLevel,
    supplier: supplier ?? this.supplier,
    costPrice: costPrice ?? this.costPrice,
    expiryDate: expiryDate ?? this.expiryDate,
    storageLocation: storageLocation ?? this.storageLocation,
    barcode: barcode ?? this.barcode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'sku': sku,
    'quantity': quantity,
    'unit': unit,
    'minimumLevel': minimumLevel,
    'supplier': supplier,
    'costPrice': costPrice,
    'expiryDate': expiryDate?.toIso8601String(),
    'storageLocation': storageLocation,
    'barcode': barcode,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    sku: json['sku'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'] as String,
    minimumLevel: (json['minimumLevel'] as num).toDouble(),
    supplier: json['supplier'] as String,
    costPrice: (json['costPrice'] as num).toDouble(),
    expiryDate: json['expiryDate'] != null
        ? DateTime.parse(json['expiryDate'] as String)
        : null,
    storageLocation: json['storageLocation'] as String,
    barcode: json['barcode'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  factory InventoryItem.defaults() => InventoryItem(
    id: '',
    name: '',
    category: 'Feed',
    sku: '',
    quantity: 0,
    unit: 'kg',
    minimumLevel: 0,
    supplier: '',
    costPrice: 0,
    expiryDate: null,
    storageLocation: '',
    barcode: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
