class FarmSaleItem {
  const FarmSaleItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final double quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;

  factory FarmSaleItem.fromJson(Map<String, dynamic> json) => FarmSaleItem(
    name: '${json['name'] ?? ''}',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    unitPrice: double.tryParse('${json['unit_price'] ?? 0}') ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit_price': unitPrice,
  };
}

class FarmSale {
  const FarmSale({
    required this.id,
    required this.reference,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currency,
    required this.orderedAt,
    this.expectedAt,
    this.items = const [],
    this.notes,
  });

  final String id;
  final String reference;
  final String customerId;
  final String customerName;
  final String status;
  final double totalAmount;
  final String currency;
  final DateTime orderedAt;
  final DateTime? expectedAt;
  final List<FarmSaleItem> items;
  final String? notes;

  factory FarmSale.fromJson(Map<String, dynamic> json) => FarmSale(
    id: '${json['id']}',
    reference: '${json['reference'] ?? ''}',
    customerId: '${json['customer_id']}',
    customerName: '${json['customer_name'] ?? ''}',
    status: '${json['status'] ?? 'pending'}',
    totalAmount: double.tryParse('${json['total_amount'] ?? 0}') ?? 0,
    currency: '${json['currency'] ?? 'KES'}',
    orderedAt:
        DateTime.tryParse('${json['ordered_at'] ?? ''}') ?? DateTime.now(),
    expectedAt: json['expected_at'] == null
        ? null
        : DateTime.tryParse('${json['expected_at']}'),
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((item) => FarmSaleItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    notes: json['notes'] as String?,
  );
}
