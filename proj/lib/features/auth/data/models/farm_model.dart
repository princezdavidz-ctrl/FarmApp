import '../../domain/entities/farm.dart';

class FarmModel extends Farm {
  const FarmModel({
    required super.id,
    required super.name,
    super.location,
    super.latitude,
    super.longitude,
    super.inviteCode,
    super.motherPigCount,
    super.registeredPigletCount,
    super.pregnantPigCount,
    super.subscriptionPlan,
    super.farmingType,
    super.productionTypes,
  });

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    final pigletGroups = json['piglet_groups'] as List<dynamic>? ?? const [];
    var registeredPigletCount = 0;
    for (final group in pigletGroups) {
      if (group is! Map) continue;
      final count = group['count'];
      if (count is num) registeredPigletCount += count.toInt();
    }
    return FarmModel(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      inviteCode: json['invite_code'] as String?,
      motherPigCount: (json['mother_pig_count'] as num?)?.toInt() ?? 0,
      registeredPigletCount: registeredPigletCount,
      pregnantPigCount: (json['pregnant_pig_count'] as num?)?.toInt() ?? 0,
      subscriptionPlan: json['subscription_plan'] as String?,
      farmingType: json['farming_type'] as String? ?? 'mixed',
      productionTypes: (json['production_types'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'invite_code': inviteCode,
    'mother_pig_count': motherPigCount,
    'piglet_groups': [
      if (registeredPigletCount > 0) {'count': registeredPigletCount},
    ],
    'pregnant_pig_count': pregnantPigCount,
    'subscription_plan': subscriptionPlan,
    'farming_type': farmingType,
    'production_types': productionTypes,
  };
}
