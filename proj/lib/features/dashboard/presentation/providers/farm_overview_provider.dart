import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/farm_overview_api.dart';

final farmOverviewApiProvider = Provider<FarmOverviewApi>(
  (ref) => FarmOverviewApi(ref.watch(dioProvider)),
);

final farmOverviewProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
      (ref, farmId) => ref.watch(farmOverviewApiProvider).fetch(farmId),
    );
