class FarmBuyer {
  const FarmBuyer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.company,
    this.address,
    this.status = 'new',
    this.notes,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? company;
  final String? address;
  final String status;
  final String? notes;

  factory FarmBuyer.fromJson(Map<String, dynamic> json) => FarmBuyer(
    id: '${json['id']}',
    name: '${json['name'] ?? ''}',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    company: json['company'] as String?,
    address: json['address'] as String?,
    status: '${json['status'] ?? 'new'}',
    notes: json['notes'] as String?,
  );
}
