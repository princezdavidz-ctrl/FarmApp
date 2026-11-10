/// Represents a supplier of inventory items
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.contact,
    required this.email,
    required this.products,
    required this.lastDeliveryDate,
    required this.outstandingOrders,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String contact; // Phone number
  final String email;
  final List<String> products; // Products supplied
  final DateTime? lastDeliveryDate;
  final int outstandingOrders; // Number of pending purchase orders
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier copyWith({
    String? id,
    String? name,
    String? contact,
    String? email,
    List<String>? products,
    DateTime? lastDeliveryDate,
    int? outstandingOrders,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Supplier(
    id: id ?? this.id,
    name: name ?? this.name,
    contact: contact ?? this.contact,
    email: email ?? this.email,
    products: products ?? this.products,
    lastDeliveryDate: lastDeliveryDate ?? this.lastDeliveryDate,
    outstandingOrders: outstandingOrders ?? this.outstandingOrders,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contact': contact,
    'email': email,
    'products': products,
    'lastDeliveryDate': lastDeliveryDate?.toIso8601String(),
    'outstandingOrders': outstandingOrders,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'] as String,
    name: json['name'] as String,
    contact: json['contact'] as String,
    email: json['email'] as String,
    products: List<String>.from(json['products'] as List<dynamic>),
    lastDeliveryDate: json['lastDeliveryDate'] != null
        ? DateTime.parse(json['lastDeliveryDate'] as String)
        : null,
    outstandingOrders: json['outstandingOrders'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  factory Supplier.defaults() => Supplier(
    id: '',
    name: '',
    contact: '',
    email: '',
    products: [],
    lastDeliveryDate: null,
    outstandingOrders: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
