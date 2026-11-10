import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/auth/presentation/providers/auth_providers.dart';
import 'package:proj/features/inventory/data/inventory_api.dart';
import 'package:proj/features/inventory/data/inventory_local_data_source.dart';
import 'package:proj/features/inventory/domain/entities/inventory_alert.dart';
import 'package:proj/features/inventory/domain/entities/inventory_item.dart';
import 'package:proj/features/inventory/domain/entities/stock_movement.dart';
import 'package:proj/features/inventory/domain/entities/supplier.dart';

final inventoryLocalDataSourceProvider = Provider<InventoryLocalDataSource>(
  (ref) => InventoryLocalDataSource(),
);

final inventoryApiProvider = Provider<InventoryApi>(
  (ref) => InventoryApi(ref.watch(dioProvider)),
);

final inventoryItemsProvider = FutureProvider.autoDispose<
    ({List<InventoryItem> items, Map<String, dynamic> summary})>((ref) async {
  final api = ref.watch(inventoryApiProvider);
  final auth = ref.watch(authProvider).valueOrNull;

  final farmId = auth?.selectedFarm?.id;
  if (farmId == null || farmId.isEmpty) {
    throw Exception('No farm selected');
  }

  final result = await api.fetchItems(farmId);
  return (
    items: (result['items'] as List<dynamic>)
        .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    summary: (result['summary'] as Map<String, dynamic>?) ?? <String, dynamic>{},
  );
});

final inventoryItemDetailsProvider = FutureProvider.autoDispose
    .family<({InventoryItem item, List<StockMovement> movements}), String>(
      (ref, itemId) async {
        final api = ref.watch(inventoryApiProvider);
        final auth = ref.watch(authProvider).valueOrNull;
        final farmId = auth?.selectedFarm?.id;

        if (farmId == null || farmId.isEmpty) {
          throw Exception('No farm selected');
        }

        final result = await api.fetchItem(farmId, itemId);
        return (
          item: InventoryItem.fromJson(
            (result['item'] as Map<String, dynamic>?) ?? <String, dynamic>{},
          ),
          movements: (result['movements'] as List<dynamic>? ?? const [])
              .map(
                (movement) =>
                    StockMovement.fromJson(movement as Map<String, dynamic>),
              )
              .toList(),
        );
      },
    );

final inventoryAlertsProvider =
    AsyncNotifierProvider<InventoryAlertsNotifier, List<InventoryAlert>>(
      InventoryAlertsNotifier.new,
    );

class InventoryAlertsNotifier extends AsyncNotifier<List<InventoryAlert>> {
  @override
  Future<List<InventoryAlert>> build() async {
    final local = ref.watch(inventoryLocalDataSourceProvider);
    final alerts = await local.readAlerts();
    return alerts.where((alert) => !alert.isResolved).toList();
  }

  Future<void> generateAlerts() async {
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final local = ref.watch(inventoryLocalDataSourceProvider);

    final items = itemsAsync.when(
      data: (value) => value.items,
      loading: () => <InventoryItem>[],
      error: (error, stackTrace) => <InventoryItem>[],
    );

    final alerts = <InventoryAlert>[];
    for (final item in items) {
      if (item.isLowStock) {
        alerts.add(
          InventoryAlert(
            id: 'low_${item.id}',
            itemId: item.id,
            itemName: item.name,
            alertType: 'low_stock',
            severity: 'warning',
            message:
                '${item.name} stock is below minimum level (${item.quantity} ${item.unit})',
            isResolved: false,
            createdAt: DateTime.now(),
            resolvedAt: null,
          ),
        );
      }

      if (item.isExpiringSoon) {
        alerts.add(
          InventoryAlert(
            id: 'expiring_${item.id}',
            itemId: item.id,
            itemName: item.name,
            alertType: 'expiring',
            severity: 'critical',
            message:
                '${item.name} is expiring on ${item.expiryDate?.toString().split(' ')[0]}',
            isResolved: false,
            createdAt: DateTime.now(),
            resolvedAt: null,
          ),
        );
      }

      if (item.isExpired) {
        alerts.add(
          InventoryAlert(
            id: 'expired_${item.id}',
            itemId: item.id,
            itemName: item.name,
            alertType: 'expired',
            severity: 'critical',
            message: '${item.name} has expired',
            isResolved: false,
            createdAt: DateTime.now(),
            resolvedAt: null,
          ),
        );
      }
    }

    for (final alert in alerts) {
      await local.saveAlert(alert);
    }
    ref.invalidateSelf();
  }

  Future<void> resolveAlert(String alertId) async {
    final local = ref.watch(inventoryLocalDataSourceProvider);
    await local.resolveAlert(alertId);
    ref.invalidateSelf();
  }
}

final inventoryCategoryProvider = FutureProvider.autoDispose
    .family<({List<InventoryItem> items, int count}), String>((ref, category) async {
      final api = ref.watch(inventoryApiProvider);
      final auth = ref.watch(authProvider).valueOrNull;
      final farmId = auth?.selectedFarm?.id;

      if (farmId == null || farmId.isEmpty) {
        throw Exception('No farm selected');
      }

      final result = await api.fetchByCategory(farmId, category);
      return (
        items: (result['items'] as List<dynamic>)
            .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        count: (result['count'] as int?) ?? 0,
      );
    });

class CreateInventoryItemNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<InventoryItem> createItem({
    required String name,
    required String category,
    required String sku,
    required double quantity,
    required String unit,
    required double minimumLevel,
    required double costPrice,
    String? supplier,
    DateTime? expiryDate,
    String? storageLocation,
    String? barcode,
    String? notes,
  }) async {
    state = const AsyncValue.loading();

    final api = ref.watch(inventoryApiProvider);
    final auth = ref.watch(authProvider).valueOrNull;
    final farmId = auth?.selectedFarm?.id;

    if (farmId == null || farmId.isEmpty) {
      throw Exception('No farm selected');
    }

    final item = await api.createItem(
      farmId,
      name: name,
      category: category,
      sku: sku,
      quantity: quantity,
      unit: unit,
      minimumLevel: minimumLevel,
      costPrice: costPrice,
      supplier: supplier,
      expiryDate: expiryDate,
      storageLocation: storageLocation,
      barcode: barcode,
      notes: notes,
    );

    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(inventoryAlertsProvider);
    return item;
  }
}

final createInventoryItemProvider =
    AsyncNotifierProvider<CreateInventoryItemNotifier, void>(
      CreateInventoryItemNotifier.new,
    );

class UpdateInventoryItemNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<InventoryItem> updateItem(
    String itemId, {
    String? name,
    String? category,
    String? sku,
    double? quantity,
    String? unit,
    double? minimumLevel,
    double? costPrice,
    String? supplier,
    DateTime? expiryDate,
    String? storageLocation,
    String? barcode,
    String? notes,
  }) async {
    state = const AsyncValue.loading();

    final api = ref.watch(inventoryApiProvider);
    final auth = ref.watch(authProvider).valueOrNull;
    final farmId = auth?.selectedFarm?.id;

    if (farmId == null || farmId.isEmpty) {
      throw Exception('No farm selected');
    }

    final item = await api.updateItem(
      farmId,
      itemId,
      name: name,
      category: category,
      sku: sku,
      quantity: quantity,
      unit: unit,
      minimumLevel: minimumLevel,
      costPrice: costPrice,
      supplier: supplier,
      expiryDate: expiryDate,
      storageLocation: storageLocation,
      barcode: barcode,
      notes: notes,
    );

    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(inventoryItemDetailsProvider(itemId));
    ref.invalidate(inventoryAlertsProvider);
    return item;
  }
}

final updateInventoryItemProvider =
    AsyncNotifierProvider<UpdateInventoryItemNotifier, void>(
      UpdateInventoryItemNotifier.new,
    );

class DeleteInventoryItemNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> deleteItem(String itemId) async {
    state = const AsyncValue.loading();

    final api = ref.watch(inventoryApiProvider);
    final auth = ref.watch(authProvider).valueOrNull;
    final farmId = auth?.selectedFarm?.id;

    if (farmId == null || farmId.isEmpty) {
      throw Exception('No farm selected');
    }

    await api.deleteItem(farmId, itemId);
    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(inventoryItemDetailsProvider(itemId));
    ref.invalidate(inventoryAlertsProvider);
  }
}

final deleteInventoryItemProvider =
    AsyncNotifierProvider<DeleteInventoryItemNotifier, void>(
      DeleteInventoryItemNotifier.new,
    );

class RecordMovementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<StockMovement> recordMovement(
    String itemId, {
    required String type,
    required double quantity,
    String? reference,
    String? notes,
  }) async {
    state = const AsyncValue.loading();

    final api = ref.watch(inventoryApiProvider);
    final auth = ref.watch(authProvider).valueOrNull;
    final farmId = auth?.selectedFarm?.id;

    if (farmId == null || farmId.isEmpty) {
      throw Exception('No farm selected');
    }

    final movement = await api.recordMovement(
      farmId,
      itemId,
      type: type,
      quantity: quantity,
      reference: reference,
      notes: notes,
    );

    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(inventoryItemDetailsProvider(itemId));
    ref.invalidate(inventoryAlertsProvider);
    return movement;
  }
}

final recordMovementProvider =
    AsyncNotifierProvider<RecordMovementNotifier, void>(
      RecordMovementNotifier.new,
    );

final selectedCategoryFilterProvider = StateProvider<String>((ref) => 'Feed');
final selectedStatusFilterProvider = StateProvider<String>((ref) => 'all');

class SuppliersNotifier extends AsyncNotifier<List<Supplier>> {
  @override
  Future<List<Supplier>> build() async {
    final local = ref.watch(inventoryLocalDataSourceProvider);
    return local.readSuppliers();
  }

  Future<void> createSupplier(Supplier supplier) async {
    final local = ref.watch(inventoryLocalDataSourceProvider);
    await local.saveSupplier(supplier);
    ref.invalidateSelf();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final local = ref.watch(inventoryLocalDataSourceProvider);
    await local.saveSupplier(supplier);
    ref.invalidateSelf();
  }
}

final suppliersProvider = AsyncNotifierProvider<SuppliersNotifier, List<Supplier>>(
  SuppliersNotifier.new,
);

class StockMovementsNotifier extends AsyncNotifier<List<StockMovement>> {
  @override
  Future<List<StockMovement>> build() async {
    final local = ref.watch(inventoryLocalDataSourceProvider);
    return local.readMovements();
  }

  Future<void> recordMovement(StockMovement movement) async {
    final local = ref.watch(inventoryLocalDataSourceProvider);
    await local.recordMovement(movement);

    final items = await ref.watch(inventoryItemsProvider.future);
    final itemIndex = items.items.indexWhere((item) => item.id == movement.itemId);
    if (itemIndex >= 0) {
      final item = items.items[itemIndex];
      double newQuantity = item.quantity;

      switch (movement.movementType) {
        case 'in':
          newQuantity += movement.quantity;
          break;
        case 'out':
        case 'damaged':
        case 'returned':
          newQuantity -= movement.quantity;
          break;
        case 'transfer':
          break;
      }

      await local.saveItem(item.copyWith(quantity: newQuantity));
      ref.invalidate(inventoryItemsProvider);
    }

    ref.invalidateSelf();
    await ref.read(inventoryAlertsProvider.notifier).generateAlerts();
  }
}

final stockMovementsProvider =
    AsyncNotifierProvider<StockMovementsNotifier, List<StockMovement>>(
      StockMovementsNotifier.new,
    );

final inventoryOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final items = await ref.watch(inventoryItemsProvider.future);
  final alerts = await ref.watch(inventoryAlertsProvider.future);

  return {
    'totalItems': items.items.length,
    'lowStockCount': items.items.where((item) => item.isLowStock).length,
    'expiringCount': items.items.where((item) => item.isExpiringSoon).length,
    'totalValue': items.items.fold<double>(
      0,
      (sum, item) => sum + item.totalValue,
    ),
    'activeAlerts': alerts.length,
  };
});

final filteredInventoryProvider = FutureProvider.family<List<InventoryItem>, String>(
  (ref, category) async {
    final items = await ref.watch(inventoryItemsProvider.future);
    if (category.isEmpty) return items.items;
    return items.items.where((item) => item.category == category).toList();
  },
);

final searchInventoryProvider = FutureProvider.family<List<InventoryItem>, String>(
  (ref, query) async {
    final items = await ref.watch(inventoryItemsProvider.future);
    if (query.isEmpty) return items.items;

    final lowerQuery = query.toLowerCase();
    return items.items
        .where(
          (item) =>
              item.name.toLowerCase().contains(lowerQuery) ||
              item.sku.toLowerCase().contains(lowerQuery) ||
              (item.barcode?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  },
);
