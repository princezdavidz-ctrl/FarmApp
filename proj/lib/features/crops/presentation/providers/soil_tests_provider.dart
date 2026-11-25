import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/soil_tests_api.dart';

final soilTestsApiProvider = Provider<SoilTestsApi>(
  (ref) => SoilTestsApi(ref.watch(dioProvider)),
);

final soilTestsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ({String farmId, String plotId})>(
  (ref, args) => ref.watch(soilTestsApiProvider).fetch(args.farmId, args.plotId),
);
