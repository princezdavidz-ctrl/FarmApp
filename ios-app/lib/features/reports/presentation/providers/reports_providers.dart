import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/features/auth/presentation/providers/auth_providers.dart';
import 'package:proj/features/reports/data/reports_api.dart';
import 'package:proj/features/reports/domain/entities/animal_report.dart';
import 'package:proj/features/reports/domain/entities/report_metrics.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';

// API provider
final reportsApiProvider = Provider(
  (ref) => ReportsApi(ref.watch(dioProvider)),
);

// Date range state
final selectedDateRangeProvider = StateProvider<String>((ref) => 'month');

// Report metrics provider
class ReportMetricsNotifier extends AsyncNotifier<ReportMetrics> {
  @override
  Future<ReportMetrics> build() async {
    final dateRange = ref.watch(selectedDateRangeProvider);
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return ReportMetrics.defaults();
    final api = ref.watch(reportsApiProvider);
    return api.getMetrics(farmId.toString(), dateRange: dateRange);
  }

  Future<void> fetchMetrics(String dateRange) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
      if (farmId == null) return ReportMetrics.defaults();
      final api = ref.read(reportsApiProvider);
      return api.getMetrics(farmId.toString(), dateRange: dateRange);
    });
  }
}

final reportMetricsProvider =
    AsyncNotifierProvider<ReportMetricsNotifier, ReportMetrics>(
      ReportMetricsNotifier.new,
    );

final animalReportProvider =
    FutureProvider.family<
      AnimalReport,
      ({String farmId, String animalId, String dateRange})
    >((ref, request) async {
      final api = ref.watch(reportsApiProvider);
      return api.getAnimalReport(
        request.farmId,
        request.animalId,
        dateRange: request.dateRange,
      );
    });
