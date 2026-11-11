import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/crop_cycles_api.dart';

final cropCyclesApiProvider = Provider<CropCyclesApi>(
  (ref) => CropCyclesApi(ref.watch(dioProvider)),
);

final cropCyclesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, farmId) => ref.watch(cropCyclesApiProvider).fetch(farmId),
);
