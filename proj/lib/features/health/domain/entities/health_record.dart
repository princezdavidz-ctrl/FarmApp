class HealthRecord {
  final String id;
  final String farmId;
  final String pigId;
  final String type; // 'vaccination', 'treatment', 'deworming', 'mortality'
  final String status; // 'healthy', 'recovering', 'critical', 'deceased'
  final List<String> symptoms;
  final String? diagnosis;
  final String? medication;
  final String? dosage;
  final String? veterinarian;
  final DateTime visitDate;
  final DateTime? nextCheckupDate;
  final String? notes;
  final List<String> attachmentUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  HealthRecord({
    required this.id,
    required this.farmId,
    required this.pigId,
    required this.type,
    required this.status,
    required this.symptoms,
    this.diagnosis,
    this.medication,
    this.dosage,
    this.veterinarian,
    required this.visitDate,
    this.nextCheckupDate,
    this.notes,
    required this.attachmentUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id']?.toString() ?? '',
      farmId: json['farm_id']?.toString() ?? '',
      pigId: json['pig_id']?.toString() ?? '',
      type: json['type'] as String? ?? 'treatment',
      status: json['status'] as String? ?? 'healthy',
      symptoms: List<String>.from((json['symptoms'] as List<dynamic>?) ?? []),
      diagnosis: json['diagnosis'] as String?,
      medication: json['medication'] as String?,
      dosage: json['dosage'] as String?,
      veterinarian: json['veterinarian'] as String?,
      visitDate:
          DateTime.tryParse(json['visit_date']?.toString() ?? '') ??
          DateTime.now(),
      nextCheckupDate: DateTime.tryParse(
        json['next_checkup_date']?.toString() ?? '',
      ),
      notes: json['notes'] as String?,
      attachmentUrls: List<String>.from(
        (json['attachment_urls'] as List<dynamic>?) ?? [],
      ),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'farm_id': farmId,
    'pig_id': pigId,
    'type': type,
    'status': status,
    'symptoms': symptoms,
    'diagnosis': diagnosis,
    'medication': medication,
    'dosage': dosage,
    'veterinarian': veterinarian,
    'visit_date': visitDate.toIso8601String(),
    'next_checkup_date': nextCheckupDate?.toIso8601String(),
    'notes': notes,
    'attachment_urls': attachmentUrls,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
