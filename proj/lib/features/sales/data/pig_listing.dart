class PigInquiry {
  const PigInquiry({
    required this.id,
    required this.buyerName,
    required this.phone,
    required this.quantity,
    required this.status,
    this.email,
    this.message,
  });

  final String id;
  final String buyerName;
  final String phone;
  final String? email;
  final int quantity;
  final String? message;
  final String status;

  factory PigInquiry.fromJson(Map<String, dynamic> json) => PigInquiry(
    id: '${json['id']}',
    buyerName: '${json['buyer_name'] ?? ''}',
    phone: '${json['phone'] ?? ''}',
    email: json['email'] as String?,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    message: json['message'] as String?,
    status: '${json['status'] ?? 'pending'}',
  );
}

class PigListing {
  const PigListing({
    required this.id,
    required this.title,
    required this.breed,
    required this.quantity,
    required this.pricePerPig,
    required this.currency,
    required this.status,
    this.animalId,
    this.imageUrl,
    this.ageWeeks,
    this.weightKg,
    this.location,
    this.description,
    this.inquiries = const [],
  });

  final String id;
  final String title;
  final String breed;
  final int quantity;
  final double pricePerPig;
  final String currency;
  final String status;
  final String? animalId;
  final String? imageUrl;
  final int? ageWeeks;
  final double? weightKg;
  final String? location;
  final String? description;
  final List<PigInquiry> inquiries;

  String get shareText {
    final details = <String>[
      'Farm App marketplace',
      title,
      'Breed: $breed',
      'Available: $quantity',
      'Price: $currency ${pricePerPig.toStringAsFixed(0)} per pig',
      'Listing ID: $id',
      if (animalId?.isNotEmpty == true) 'Pig ID: $animalId',
      if (ageWeeks != null) 'Age: $ageWeeks weeks',
      if (weightKg != null) 'Weight: ${weightKg!.toStringAsFixed(1)} kg',
      if (location?.trim().isNotEmpty == true) 'Location: ${location!.trim()}',
      if (description?.trim().isNotEmpty == true) description!.trim(),
    ];
    return details.join('\n');
  }

  factory PigListing.fromJson(Map<String, dynamic> json) => PigListing(
    id: '${json['id']}',
    title: '${json['title'] ?? ''}',
    breed: '${json['breed'] ?? ''}',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    pricePerPig: double.tryParse('${json['price_per_pig'] ?? 0}') ?? 0,
    currency: '${json['currency'] ?? 'KES'}',
    status: '${json['status'] ?? 'available'}',
    animalId: json['animal_id']?.toString(),
    imageUrl: json['image_url'] as String?,
    ageWeeks: (json['age_weeks'] as num?)?.toInt(),
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    location: json['location'] as String? ?? json['farm_location'] as String?,
    description: json['description'] as String?,
    inquiries: (json['inquiries'] as List<dynamic>? ?? const [])
        .map((item) => PigInquiry.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
