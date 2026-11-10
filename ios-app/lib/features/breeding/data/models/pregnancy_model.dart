import '../../domain/entities/pregnancy.dart';

class PregnancyModel extends Pregnancy {
  const PregnancyModel({
    required super.id,
    required super.sowId,
    required super.matingDate,
    required super.expectedFarrowingDate,
    required super.status,
    super.sowTag,
    super.boarId,
    super.boarTag,
    super.semenUsed,
    super.confirmationDate,
    super.actualFarrowingDate,
    super.expectedLitterSize,
    super.bornAlive,
    super.stillborn,
    super.mummified,
    super.weaned,
    super.notes,
    super.daysUntilFarrowing,
  });

  factory PregnancyModel.fromJson(Map<String, dynamic> json) {
    DateTime requiredDate(String key) =>
        DateTime.tryParse('${json[key]}') ?? DateTime(1970);
    DateTime? optionalDate(String key) =>
        json[key] == null ? null : DateTime.tryParse('${json[key]}');
    final sow = json['sow'] as Map<String, dynamic>?;
    final boar = json['boar'] as Map<String, dynamic>?;

    return PregnancyModel(
      id: '${json['id']}',
      sowId: '${json['sow_id']}',
      sowTag: sow?['tag'] as String?,
      boarId: json['boar_id'] as String?,
      boarTag: boar?['tag'] as String?,
      semenUsed: json['semen_used'] as String?,
      matingDate: requiredDate('mating_date'),
      confirmationDate: optionalDate('confirmation_date'),
      expectedFarrowingDate: requiredDate('expected_farrowing_date'),
      actualFarrowingDate: optionalDate('actual_farrowing_date'),
      status: '${json['status'] ?? 'suspected'}',
      expectedLitterSize: json['expected_litter_size'] as int?,
      bornAlive: json['born_alive'] as int?,
      stillborn: json['stillborn'] as int?,
      mummified: json['mummified'] as int?,
      weaned: json['weaned'] as int?,
      notes: json['notes'] as String?,
      daysUntilFarrowing: json['days_until_farrowing'] as int?,
    );
  }
}
