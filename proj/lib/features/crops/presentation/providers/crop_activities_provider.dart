import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/crop_activities_api.dart';

final cropActivitiesApiProvider = Provider<CropActivitiesApi>(
  (ref) => CropActivitiesApi(ref.watch(dioProvider)),
);

final cropActivitiesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, farmId) => ref.watch(cropActivitiesApiProvider).fetch(farmId),
);
