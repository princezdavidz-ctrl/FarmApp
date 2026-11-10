import 'package:proj/features/breeding/data/models/pregnancy_model.dart';
import 'package:proj/features/breeding/domain/entities/pregnancy.dart';
import 'package:proj/features/growth/domain/entities/growth_record.dart';
import 'package:proj/features/health/domain/entities/health_record.dart';
import 'package:proj/features/herd/domain/entities/animal.dart';

class AnimalReport {
  const AnimalReport({
    required this.animal,
    required this.healthRecords,
    required this.growthRecords,
    required this.pregnancies,
    required this.startDate,
    required this.endDate,
  });

  final Animal animal;
  final List<HealthRecord> healthRecords;
  final List<GrowthRecord> growthRecords;
  final List<Pregnancy> pregnancies;
  final DateTime startDate;
  final DateTime endDate;

  GrowthRecord? get latestGrowthRecord =>
      growthRecords.isEmpty ? null : growthRecords.first;

  factory AnimalReport.fromJson(Map<String, dynamic> json) {
    final animalJson = json['animal'] as Map<String, dynamic>;
    final period = json['period'] as Map<String, dynamic>;

    return AnimalReport(
      animal: Animal.fromJson(animalJson),
      healthRecords: _parseList(json['healthRecords'], HealthRecord.fromJson),
      growthRecords: _parseList(json['growthRecords'], GrowthRecord.fromJson),
      pregnancies: _parseList(json['pregnancies'], PregnancyModel.fromJson),
      startDate: DateTime.parse(period['startDate'] as String),
      endDate: DateTime.parse(period['endDate'] as String),
    );
  }

  Map<String, dynamic> toExportJson() => {
    'animal': {
      'id': animal.id,
      'tag': animal.tag,
      'type': animal.type,
      'sex': animal.sex,
      'status': animal.status,
      'birth_date': animal.birthDate?.toIso8601String(),
      'notes': animal.notes,
    },
    'period': {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    },
    'latest_weight_kg': latestGrowthRecord?.currentWeight,
    'growth_records': growthRecords.map((record) => record.toJson()).toList(),
    'health_records': healthRecords.map((record) => record.toJson()).toList(),
    'pregnancies': pregnancies
        .map(
          (pregnancy) => {
            'mating_date': pregnancy.matingDate.toIso8601String(),
            'expected_farrowing_date': pregnancy.expectedFarrowingDate
                .toIso8601String(),
            'actual_farrowing_date': pregnancy.actualFarrowingDate
                ?.toIso8601String(),
            'status': pregnancy.status,
            'expected_litter_size': pregnancy.expectedLitterSize,
            'born_alive': pregnancy.bornAlive,
            'stillborn': pregnancy.stillborn,
            'weaned': pregnancy.weaned,
            'notes': pregnancy.notes,
          },
        )
        .toList(),
  };

  static List<T> _parseList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) fromJson,
  ) => (value as List<dynamic>? ?? [])
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
}