import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/health_api.dart';
import '../../domain/entities/health_record.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// API Provider
final healthApiProvider = Provider<HealthApi>(
  (ref) => HealthApi(ref.watch(dioProvider)),
);

// Health Records Notifier
class HealthRecordsNotifier extends AsyncNotifier<List<HealthRecord>> {
  @override
  Future<List<HealthRecord>> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return [];
    return ref.watch(healthApiProvider).fetchHealthRecords(farmId);
  }

  Future<void> addRecord(Map<String, dynamic> data) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref.read(healthApiProvider).addHealthRecord(farmId, data);
    ref.invalidateSelf();
  }

  Future<void> updateRecord(String recordId, Map<String, dynamic> data) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref
        .read(healthApiProvider)
        .updateHealthRecord(farmId, recordId, data);
    ref.invalidateSelf();
  }

  Future<void> deleteRecord(String recordId) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('No farm selected.');
    await ref.read(healthApiProvider).deleteHealthRecord(farmId, recordId);
    ref.invalidateSelf();
  }
}

final healthRecordsProvider =
    AsyncNotifierProvider<HealthRecordsNotifier, List<HealthRecord>>(
      HealthRecordsNotifier.new,
    );

// Vaccination Schedule Provider
final vaccinationScheduleProvider = FutureProvider<List<HealthRecord>>((
  ref,
) async {
  final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
  if (farmId == null) return [];
  return ref.watch(healthApiProvider).fetchVaccinationSchedule(farmId);
});

// Treatment Records Provider
final treatmentRecordsProvider = FutureProvider<List<HealthRecord>>((
  ref,
) async {
  final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
  if (farmId == null) return [];
  return ref.watch(healthApiProvider).fetchTreatmentRecords(farmId);
});

// Health Alerts Provider
final healthAlertsProvider = FutureProvider<List<HealthRecord>>((ref) async {
  final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
  if (farmId == null) return [];
  return ref.watch(healthApiProvider).fetchHealthAlerts(farmId);
});

// Health Analytics Provider
final healthAnalyticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
  if (farmId == null) return {};
  return ref.watch(healthApiProvider).fetchHealthAnalytics(farmId);
});

// Health Overview Stats
final healthOverviewProvider = FutureProvider<Map<String, int>>((ref) async {
  final records = await ref.watch(healthRecordsProvider.future);
  final vaccinatedPigIds = <String>{
    for (final record in records)
      if (record.type == 'vaccination') record.pigId,
  };

  return {
    'healthy': records.where((r) => r.status == 'healthy').length,
    'sick': records
        .where((r) => r.status == 'recovering' || r.status == 'critical')
        .length,
    'vaccinations_due': records
        .where((r) => r.type == 'vaccination' && r.status == 'due')
        .length,
    'under_treatment': records.where((r) => r.status == 'recovering').length,
    'vaccinated': vaccinatedPigIds.length,
  };
});

// Search filter state
final healthSearchProvider = StateProvider<String>((ref) => '');

// Type filter state
final healthTypeFilterProvider = StateProvider<String>((ref) => 'all');

// Status filter state
final healthStatusFilterProvider = StateProvider<String>((ref) => 'all');

// Filtered health records
final filteredHealthRecordsProvider = FutureProvider<List<HealthRecord>>((ref) {
  final recordsAsync = ref.watch(healthRecordsProvider);
  final search = ref.watch(healthSearchProvider);
  final typeFilter = ref.watch(healthTypeFilterProvider);
  final statusFilter = ref.watch(healthStatusFilterProvider);

  return recordsAsync.when(
    data: (records) {
      var filtered = records;

      if (typeFilter != 'all') {
        filtered = typeFilter == 'medication'
            ? filtered
                  .where((r) => (r.medication?.trim().isNotEmpty ?? false))
                  .toList()
            : filtered.where((r) => r.type == typeFilter).toList();
      }

      if (statusFilter != 'all') {
        filtered = filtered.where((r) => r.status == statusFilter).toList();
      }

      if (search.isNotEmpty) {
        final query = search.toLowerCase();
        filtered = filtered
            .where(
              (r) =>
                  r.pigId.toLowerCase().contains(query) ||
                  (r.diagnosis?.toLowerCase().contains(query) ?? false),
            )
            .toList();
      }

      return filtered;
    },
    loading: () => [],
    error: (error, stackTrace) => throw error,
  );
});
