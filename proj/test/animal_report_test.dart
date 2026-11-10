import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/reports/domain/entities/animal_report.dart';

void main() {
  group('AnimalReport', () {
    final reportJson = <String, dynamic>{
      'animal': {
        'id': '17',
        'tag': 'SOW-17',
        'type': 'sow',
        'sex': 'female',
        'status': 'active',
        'birth_date': '2025-01-10',
        'notes': 'Breeding stock',
      },
      'period': {
        'startDate': '2026-09-01T00:00:00+00:00',
        'endDate': '2026-09-30T23:59:59+00:00',
      },
      'healthRecords': [
        {
          'id': 'health-1',
          'farm_id': '4',
          'animal_id': '17',
          'pig_id': '17',
          'type': 'vaccination',
          'status': 'completed',
          'visit_date': '2026-09-10T10:00:00+00:00',
          'symptoms': [],
          'attachment_urls': [],
          'created_at': '2026-09-10T10:00:00+00:00',
          'updated_at': '2026-09-10T10:00:00+00:00',
        },
      ],
      'growthRecords': [
        {
          'id': 'growth-1',
          'farm_id': '4',
          'animal_id': '17',
          'current_weight': 42.5,
          'previous_weight': 39.0,
          'weight_gain': 3.5,
          'measurement_date': '2026-09-20T10:00:00+00:00',
          'created_at': '2026-09-20T10:00:00+00:00',
          'updated_at': '2026-09-20T10:00:00+00:00',
        },
      ],
      'pregnancies': [
        {
          'id': 'pregnancy-1',
          'farm_id': '4',
          'sow_id': '17',
          'sow': {'id': '17', 'tag': 'SOW-17'},
          'boar_id': null,
          'boar': null,
          'mating_date': '2026-09-05',
          'expected_farrowing_date': '2026-12-28',
          'status': 'confirmed',
          'days_until_farrowing': 89,
        },
      ],
    };

    test('parses animal profile and associated records', () {
      final report = AnimalReport.fromJson(reportJson);

      expect(report.animal.id, '17');
      expect(report.animal.tag, 'SOW-17');
      expect(report.latestGrowthRecord?.currentWeight, 42.5);
      expect(report.healthRecords.single.type, 'vaccination');
      expect(report.pregnancies.single.status, 'confirmed');
      expect(report.startDate, DateTime.parse('2026-09-01T00:00:00+00:00'));
    });

    test('exports selected pig identity and actual report histories', () {
      final report = AnimalReport.fromJson(reportJson);
      final payload = report.toExportJson();

      expect((payload['animal'] as Map)['tag'], 'SOW-17');
      expect(payload['latest_weight_kg'], 42.5);
      expect((payload['health_records'] as List).length, 1);
      expect((payload['growth_records'] as List).length, 1);
      expect((payload['pregnancies'] as List).length, 1);
      expect(payload.containsKey('totalRevenue'), isFalse);
    });

    test('supports reports with no recorded histories', () {
      final report = AnimalReport.fromJson({
        ...reportJson,
        'healthRecords': <dynamic>[],
        'growthRecords': <dynamic>[],
        'pregnancies': <dynamic>[],
      });

      expect(report.latestGrowthRecord, isNull);
      expect(report.healthRecords, isEmpty);
      expect(report.growthRecords, isEmpty);
      expect(report.pregnancies, isEmpty);
    });
  });
}