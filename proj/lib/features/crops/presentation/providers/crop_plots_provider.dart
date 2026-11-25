import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/crop_plots_api.dart';

final cropPlotsApiProvider = Provider<CropPlotsApi>(
  (ref) => CropPlotsApi(ref.watch(dioProvider)),
);

final cropPlotsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, farmId) => ref.watch(cropPlotsApiProvider).fetch(farmId),
);
