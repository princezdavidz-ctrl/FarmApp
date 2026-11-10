class Farm {
  const Farm({
    required this.id,
    required this.name,
    this.location,
    this.latitude,
    this.longitude,
    this.inviteCode,
    this.motherPigCount = 0,
    this.registeredPigletCount = 0,
    this.pregnantPigCount = 0,
    this.subscriptionPlan,
    this.farmingType = 'mixed',
    this.productionTypes = const [],
  });

  final String id;
  final String name;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? inviteCode;
  final int motherPigCount;
  final int registeredPigletCount;
  final int pregnantPigCount;
  final String? subscriptionPlan;
  final String farmingType;
  final List<String> productionTypes;

  int get registeredHerdCount => motherPigCount + registeredPigletCount;
}
