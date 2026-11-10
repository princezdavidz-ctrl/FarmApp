class GrowthRecord {
  final String id;
  final String farmId;
  final String animalId;
  final double currentWeight;
  final double? previousWeight;
  final double? weightGain;
  final double? dailyGain;
  final int? ageInDays;
  final DateTime measurementDate;
  final String? recordedBy;
  final String? notes;
  final String? photoUrl;
  final double? targetWeight;
  final DateTime createdAt;
  final DateTime updatedAt;

  GrowthRecord({
    required this.id,
    required this.farmId,
    required this.animalId,
    required this.currentWeight,
    this.previousWeight,
    this.weightGain,
    this.dailyGain,
    this.ageInDays,
    required this.measurementDate,
    this.recordedBy,
    this.notes,
    this.photoUrl,
    this.targetWeight,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GrowthRecord.fromJson(Map<String, dynamic> json) {
    return GrowthRecord(
      id: (json['id'] ?? '').toString(),
      farmId: (json['farm_id'] ?? '').toString(),
      animalId: (json['animal_id'] ?? json['pig_id'] ?? '').toString(),
      currentWeight: _parseDouble(json['current_weight']) ?? 0,
      previousWeight: _parseDouble(json['previous_weight']),
      weightGain: _parseDouble(json['weight_gain']),
      dailyGain: _parseDouble(json['daily_gain']),
      ageInDays: _parseInt(json['age_in_days']),
      measurementDate:
          _parseDateTime(json['measurement_date']) ?? DateTime.now(),
      recordedBy: json['recorded_by'] as String?,
      notes: json['notes'] as String?,
      photoUrl: json['photo_url'] as String?,
      targetWeight: _parseDouble(json['target_weight']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'farm_id': farmId,
    'animal_id': animalId,
    'pig_id': animalId,
    'current_weight': currentWeight,
    'previous_weight': previousWeight,
    'weight_gain': weightGain,
    'daily_gain': dailyGain,
    'age_in_days': ageInDays,
    'measurement_date': measurementDate.toIso8601String(),
    'recorded_by': recordedBy,
    'notes': notes,
    'photo_url': photoUrl,
    'target_weight': targetWeight,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
