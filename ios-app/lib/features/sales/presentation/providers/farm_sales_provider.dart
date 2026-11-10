import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/farm_buyer.dart';
import '../../data/farm_sale.dart';
import '../../data/farm_sales_api.dart';

final farmSalesApiProvider = Provider<FarmSalesApi>(
  (ref) => FarmSalesApi(ref.watch(dioProvider)),
);

final farmSalesProvider =
    AsyncNotifierProvider<FarmSalesNotifier, FarmSalesState>(
      FarmSalesNotifier.new,
    );

class FarmSalesState {
  const FarmSalesState({this.buyers = const [], this.sales = const []});
  final List<FarmBuyer> buyers;
  final List<FarmSale> sales;
}

class FarmSalesNotifier extends AsyncNotifier<FarmSalesState> {
  @override
  Future<FarmSalesState> build() async {
    final farmId = ref.watch(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return const FarmSalesState();
    final api = ref.watch(farmSalesApiProvider);
    final results = await Future.wait([
      api.fetchBuyers(farmId),
      api.fetchSales(farmId),
    ]);
    return FarmSalesState(
      buyers: results[0] as List<FarmBuyer>,
      sales: results[1] as List<FarmSale>,
    );
  }

  Future<void> createBuyer({
    required String name,
    String? email,
    String? phone,
    String? company,
    String? address,
    String? notes,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('Select a farm first.');
    await ref.read(farmSalesApiProvider).createBuyer(farmId, {
      'name': name,
      'email': email,
      'phone': phone,
      'company': company,
      'address': address,
      'notes': notes,
      'status': 'qualified',
    });
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateBuyer(String buyerId, Map<String, dynamic> data) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('Select a farm first.');
    await ref.read(farmSalesApiProvider).updateBuyer(farmId, buyerId, data);
    ref.invalidateSelf();
    await future;
  }

  Future<void> createSale({
    required String buyerId,
    required String reference,
    required FarmSaleItem item,
    required String currency,
    required DateTime orderedAt,
    DateTime? expectedAt,
    String? notes,
  }) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('Select a farm first.');
    await ref.read(farmSalesApiProvider).createSale(farmId, {
      'customer_id': int.parse(buyerId),
      'reference': reference,
      'items': [item.toJson()],
      'total_amount': item.total,
      'currency': currency,
      'ordered_at': orderedAt.toIso8601String().split('T').first,
      if (expectedAt != null)
        'expected_at': expectedAt.toIso8601String().split('T').first,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateSaleStatus(String saleId, String status) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) throw StateError('Select a farm first.');
    await ref.read(farmSalesApiProvider).updateSale(farmId, saleId, {
      'status': status,
    });
    ref.invalidateSelf();
    await future;
  }
}
