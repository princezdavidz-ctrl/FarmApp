import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/growth_api.dart';
import '../../domain/entities/growth_record.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final growthApiProvider = Provider<GrowthApi>(
  (ref) => GrowthApi(ref.watch(dioProvider)),
);

class GrowthRecordsNotifier extends AsyncNotifier<List<GrowthRecord>> {
  @override
  Future<List<GrowthRecord>> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return [];

    final api = ref.watch(growthApiProvider);
    final records = await api.fetchGrowthRecords(farmId);
    return records;
  }

  Future<void> addRecord(Map<String, dynamic> data) async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return;

    final api = ref.watch(growthApiProvider);
    await api.addGrowthRecord(farmId, data);
    ref.invalidateSelf();
  }

  Future<void> updateRecord(String recordId, Map<String, dynamic> data) async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return;

    final api = ref.watch(growthApiProvider);
    await api.updateGrowthRecord(farmId, recordId, data);
    ref.invalidateSelf();
  }

  Future<void> deleteRecord(String recordId) async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return;

    final api = ref.watch(growthApiProvider);
    await api.deleteGrowthRecord(farmId, recordId);
    ref.invalidateSelf();
  }
}

final growthRecordsProvider =
    AsyncNotifierProvider<GrowthRecordsNotifier, List<GrowthRecord>>(
      GrowthRecordsNotifier.new,
    );

final growthOverviewProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
  if (farmId == null) return {};

  final api = ref.watch(growthApiProvider);
  return await api.fetchGrowthOverview(farmId);
});

final growthAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
      final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
      if (farmId == null) return {};

      final api = ref.watch(growthApiProvider);
      return await api.fetchGrowthAnalytics(farmId, period: period);
    });

final growthPeriodFilterProvider = StateProvider<String>(
  (ref) => '30days',
); // 7days, 30days, 90days, 1year

final growthSearchProvider = StateProvider<String>((ref) => '');

final filteredGrowthRecordsProvider = FutureProvider<List<GrowthRecord>>((
  ref,
) async {
  final records = await ref.watch(growthRecordsProvider.future);
  final searchQuery = ref.watch(growthSearchProvider).toLowerCase();

  if (searchQuery.isEmpty) return records;

  return records.where((record) {
    return record.animalId.toLowerCase().contains(searchQuery) ||
        (record.recordedBy?.toLowerCase().contains(searchQuery) ?? false);
  }).toList();
});
