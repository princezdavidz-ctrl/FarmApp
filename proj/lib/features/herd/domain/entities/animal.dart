class Animal {
  const Animal({
    required this.id,
    required this.tag,
    required this.type,
    required this.sex,
    required this.status,
    this.name,
    this.birthDate,
    this.weightKg,
    this.isPregnant = false,
    this.lastDewormedAt,
    this.lastVaccinatedAt,
    this.notes,
    this.imageUrl,
  });

  final String id;
  final String tag;
  final String type;
  final String sex;
  final String status;
  final String? name;
  final DateTime? birthDate;
  final double? weightKg;
  final bool isPregnant;
  final DateTime? lastDewormedAt;
  final DateTime? lastVaccinatedAt;
  final String? notes;
  final String? imageUrl;

  factory Animal.fromJson(Map<String, dynamic> json) => Animal(
    id: '${json['id']}',
    tag: '${json['tag'] ?? ''}',
    type: '${json['type'] ?? ''}',
    sex: '${json['sex'] ?? ''}',
    status: '${json['status'] ?? 'active'}',
    name: json['name'] as String?,
    birthDate: json['birth_date'] == null
        ? null
        : DateTime.tryParse('${json['birth_date']}'),
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    isPregnant: json['is_pregnant'] as bool? ?? false,
    lastDewormedAt: json['last_dewormed_at'] == null
        ? null
        : DateTime.tryParse('${json['last_dewormed_at']}'),
    lastVaccinatedAt: json['last_vaccinated_at'] == null
        ? null
        : DateTime.tryParse('${json['last_vaccinated_at']}'),
    notes: json['notes'] as String?,
    imageUrl: json['image_url'] as String?,
  );
}
