import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/farm_finance_api.dart';

final farmFinanceApiProvider = Provider<FarmFinanceApi>(
  (ref) => FarmFinanceApi(ref.watch(dioProvider)),
);

final farmFinanceProvider =
    AsyncNotifierProvider<FarmFinanceNotifier, FarmFinanceState>(
      FarmFinanceNotifier.new,
    );

class FarmFinanceNotifier extends AsyncNotifier<FarmFinanceState> {
  @override
  Future<FarmFinanceState> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return const FarmFinanceState();
    return ref.watch(farmFinanceApiProvider).fetch(farmId);
  }

  Future<void> record({
    required String type,
    required String category,
    required String description,
    required double amount,
    required String currency,
    required DateTime occurredAt,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) {
      throw StateError('Select a farm before recording a transaction.');
    }

    final api = ref.read(farmFinanceApiProvider);
    await api.create(
      farmId,
      type: type,
      category: category,
      description: description,
      amount: amount,
      currency: currency,
      occurredAt: occurredAt,
    );
    state = AsyncData(await api.fetch(farmId));
  }
}
